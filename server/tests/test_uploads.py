import pytest
import pytest_asyncio
from httpx import AsyncClient

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture(autouse=True)
async def upload_dir(tmp_path, monkeypatch):
    """Keeps test uploads out of the real upload directory. `get_settings` is
    cached, so it has to be cleared on both sides of the swap."""
    from app.core.config import get_settings

    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))
    get_settings.cache_clear()
    yield tmp_path
    get_settings.cache_clear()


async def _upload(client: AsyncClient, headers: dict[str, str], name: str, content: bytes, content_type: str):
    return await client.post(
        "/api/uploads", files={"file": (name, content, content_type)}, headers=headers
    )


async def test_uploads_accept_any_file_type(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    """Type is not the gate — a spreadsheet or an archive is as postable as a png."""
    resp = await _upload(
        client,
        admin_headers,
        "notes.xlsx",
        b"binary-ish",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["filename"] == "notes.xlsx"
    assert body["size_bytes"] == len(b"binary-ish")
    assert body["url"] == f"/api/uploads/{body['id']}"


async def test_download_returns_the_file_under_its_original_name(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    upload = await _upload(client, admin_headers, "report.pdf", b"%PDF-1.4 ...", "application/pdf")
    resp = await client.get(upload.json()["url"])

    assert resp.status_code == 200
    assert resp.content == b"%PDF-1.4 ..."
    # A PDF may be shown in place, and the name survives the random storage name.
    assert resp.headers["content-disposition"].startswith("inline")
    assert "report.pdf" in resp.headers["content-disposition"]
    assert resp.headers["x-content-type-options"] == "nosniff"


async def test_a_stored_page_is_never_rendered_inline(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    """An uploaded page must not be able to execute on the API's own origin."""
    upload = await _upload(
        client, admin_headers, "payload.html", b"<script>alert(1)</script>", "text/html"
    )
    resp = await client.get(upload.json()["url"])

    assert resp.status_code == 200
    assert resp.headers["content-disposition"].startswith("attachment")


async def test_images_are_served_inline(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    upload = await _upload(client, admin_headers, "shot.png", b"\x89PNG\r\n\x1a\n", "image/png")
    resp = await client.get(upload.json()["url"])
    assert resp.headers["content-disposition"].startswith("inline")


async def test_empty_files_are_rejected(client: AsyncClient, admin_headers: dict[str, str]) -> None:
    resp = await _upload(client, admin_headers, "nothing.txt", b"", "text/plain")
    assert resp.status_code == 400


async def test_oversized_files_are_rejected(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    from app.core.config import get_settings

    get_settings.cache_clear()
    with pytest.MonkeyPatch.context() as patch:
        patch.setenv("MAX_UPLOAD_BYTES", "8")
        get_settings.cache_clear()
        resp = await _upload(client, admin_headers, "big.bin", b"0" * 64, "application/octet-stream")
    get_settings.cache_clear()

    assert resp.status_code == 413


async def test_download_of_an_unknown_attachment_is_404(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    resp = await client.get("/api/uploads/00000000-0000-0000-0000-000000000000")
    assert resp.status_code == 404
