import uuid
from pathlib import Path

import aiofiles
from fastapi import APIRouter, HTTPException, UploadFile, status

from app.core.config import get_settings
from app.core.deps import CurrentUser, DbSession
from app.models.attachment import Attachment
from app.schemas.attachment import AttachmentRead

router = APIRouter(prefix="/api/uploads", tags=["uploads"])

ALLOWED_CONTENT_TYPES = {
    "image/png",
    "image/jpeg",
    "image/gif",
    "image/webp",
    "video/mp4",
    "video/webm",
    "audio/mpeg",
    "audio/ogg",
    "audio/wav",
    "application/pdf",
    "application/zip",
    "text/plain",
}


@router.post("", response_model=AttachmentRead, status_code=status.HTTP_201_CREATED)
async def upload_file(user: CurrentUser, db: DbSession, file: UploadFile) -> AttachmentRead:
    settings = get_settings()

    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Tipo de arquivo não suportado: {file.content_type}",
        )

    upload_dir = Path(settings.upload_dir)
    upload_dir.mkdir(parents=True, exist_ok=True)

    suffix = Path(file.filename or "").suffix[:16]
    stored_filename = f"{uuid.uuid4().hex}{suffix}"
    destination = upload_dir / stored_filename

    size_bytes = 0
    async with aiofiles.open(destination, "wb") as out_file:
        while chunk := await file.read(1024 * 1024):
            size_bytes += len(chunk)
            if size_bytes > settings.max_upload_bytes:
                await out_file.close()
                destination.unlink(missing_ok=True)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail="Arquivo excede o tamanho máximo permitido",
                )
            await out_file.write(chunk)

    attachment = Attachment(
        uploaded_by_id=user.id,
        filename=file.filename or stored_filename,
        content_type=file.content_type,
        size_bytes=size_bytes,
        storage_path=stored_filename,
    )
    db.add(attachment)
    await db.commit()
    await db.refresh(attachment)

    return AttachmentRead(
        id=attachment.id,
        filename=attachment.filename,
        content_type=attachment.content_type,
        size_bytes=attachment.size_bytes,
        url=f"/uploads/{attachment.storage_path}",
        created_at=attachment.created_at,
    )
