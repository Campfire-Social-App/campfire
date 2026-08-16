import re
import uuid
from pathlib import Path

import aiofiles
from fastapi import APIRouter, HTTPException, Response, UploadFile, status
from fastapi.responses import FileResponse

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession
from app.models.attachment import Attachment
from app.schemas.attachment import AttachmentRead

router = APIRouter(prefix="/api/uploads", tags=["uploads"])

# Types the browser may render in place. Everything else is sent as a download,
# so an uploaded page can never execute on the API's own origin. SVG is absent
# on purpose: it is an image that can carry script.
INLINE_CONTENT_TYPES = {
    "image/png",
    "image/jpeg",
    "image/gif",
    "image/webp",
    "image/avif",
    "video/mp4",
    "video/webm",
    "video/quicktime",
    "audio/mpeg",
    "audio/ogg",
    "audio/wav",
    "audio/webm",
    "application/pdf",
}

DEFAULT_CONTENT_TYPE = "application/octet-stream"
_SAFE_SUFFIX = re.compile(r"^\.[A-Za-z0-9]{1,16}$")


def _stored_name(filename: str | None) -> str:
    """A random name on disk, keeping the original extension only when it is
    plainly harmless — the extension is what the OS trusts once downloaded."""
    suffix = Path(filename or "").suffix
    if not _SAFE_SUFFIX.match(suffix):
        suffix = ""
    return f"{uuid.uuid4().hex}{suffix.lower()}"


@router.post("", response_model=AttachmentRead, status_code=status.HTTP_201_CREATED)
async def upload_file(user: CurrentUser, db: DbSession, file: UploadFile) -> AttachmentRead:
    """Takes any kind of file — the guard is size, not type. What a file is
    allowed to *do* is decided when it is served back (see `download_file`)."""
    settings = get_settings()

    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)

    stored_filename = _stored_name(file.filename)
    destination = upload_dir / stored_filename

    size_bytes = 0
    async with aiofiles.open(destination, "wb") as out_file:
        while chunk := await file.read(1024 * 1024):
            size_bytes += len(chunk)
            if size_bytes > settings.max_upload_bytes:
                await out_file.close()
                destination.unlink(missing_ok=True)
                raise HTTPException(
                    status_code=status.HTTP_413_CONTENT_TOO_LARGE,
                    detail="File exceeds the maximum allowed size",
                )
            await out_file.write(chunk)

    if size_bytes == 0:
        destination.unlink(missing_ok=True)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="File is empty")

    attachment = Attachment(
        uploaded_by_id=user.id,
        filename=file.filename or stored_filename,
        content_type=file.content_type or DEFAULT_CONTENT_TYPE,
        size_bytes=size_bytes,
        storage_path=stored_filename,
    )
    db.add(attachment)
    await db.commit()
    await db.refresh(attachment)

    return AttachmentRead.from_model(attachment)


@router.get("/{attachment_id}")
async def download_file(attachment_id: uuid.UUID, db: DbSession) -> Response:
    """Serves an attachment back.

    Deliberately unauthenticated: `<img>` and `<video>` can't carry an
    Authorization header, and the id is an unguessable uuid — the same posture
    the files had when they were served straight off disk. What this route adds
    is the original filename on download, and the inline/attachment decision
    that keeps a stored page from ever rendering on this origin.
    """
    attachment = await db.get(Attachment, attachment_id)
    if attachment is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attachment not found")

    path = Path(get_settings().upload_dir) / attachment.storage_path
    if not path.is_file():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attachment not found")

    disposition = "inline" if attachment.content_type in INLINE_CONTENT_TYPES else "attachment"
    return FileResponse(
        path,
        media_type=attachment.content_type,
        filename=attachment.filename,
        content_disposition_type=disposition,
        # Without this the browser may sniff past the declared type and render
        # something we just said to download.
        headers={"X-Content-Type-Options": "nosniff", "Cache-Control": "private, max-age=86400"},
    )
