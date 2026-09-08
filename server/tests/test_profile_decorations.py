from io import BytesIO

import pytest
import pytest_asyncio
from httpx import AsyncClient
from PIL import Image, ImageDraw

pytestmark = pytest.mark.asyncio


@pytest_asyncio.fixture(autouse=True)
async def upload_dir(tmp_path, monkeypatch):
    from app.core.config import get_settings

    monkeypatch.setenv("UPLOAD_DIR", str(tmp_path))
    get_settings.cache_clear()
    yield tmp_path
    get_settings.cache_clear()


def identity_plate_png(*, visible_left: bool = False, size: tuple[int, int] = (456, 80)) -> bytes:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    x = 20 if visible_left else round(size[0] * 0.82)
    draw.rounded_rectangle(
        (x, min(18, size[1] - 2), min(x + 54, size[0] - 1), min(62, size[1] - 1)),
        radius=8,
        fill=(0, 220, 255, 230),
    )
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


def identity_plate_gif() -> bytes:
    frames = []
    for offset in (0, 8):
        frame = Image.new("RGBA", (456, 80), (0, 0, 0, 0))
        ImageDraw.Draw(frame).ellipse((382 + offset, 20, 426 + offset, 60), fill=(180, 40, 255, 255))
        frames.append(frame)
    output = BytesIO()
    frames[0].save(
        output,
        format="GIF",
        save_all=True,
        append_images=frames[1:],
        duration=100,
        loop=0,
        disposal=2,
        transparency=0,
    )
    return output.getvalue()


def static_decoration_png(role: str) -> bytes:
    sizes = {"card-frame": (600, 908), "card-top": (600, 128), "avatar-frame": (384, 384)}
    image = Image.new("RGBA", sizes[role], (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    if role == "card-frame":
        draw.rectangle((0, 0, 599, 24), fill=(255, 110, 0, 255))
        draw.rectangle((0, 884, 599, 907), fill=(255, 110, 0, 255))
        draw.rectangle((0, 0, 24, 907), fill=(255, 110, 0, 255))
        draw.rectangle((575, 0, 599, 907), fill=(255, 110, 0, 255))
    elif role == "card-top":
        draw.polygon(((80, 56), (300, 0), (520, 56), (300, 88)), fill=(80, 210, 255, 240))
    else:
        draw.ellipse((18, 18, 366, 366), outline=(190, 70, 255, 255), width=28)
    output = BytesIO()
    image.save(output, format="PNG")
    return output.getvalue()


async def upload(
    client: AsyncClient, headers: dict[str, str], role: str, name: str, data: bytes
):
    return await client.post(
        f"/api/users/@me/decorations/{role}",
        files={"file": (name, data, "application/octet-stream")},
        headers=headers,
    )


async def test_user_uploads_and_selects_custom_identity_plate(
    client: AsyncClient, admin_headers: dict[str, str], admin_user
) -> None:
    response = await upload(
        client, admin_headers, "identity-plate", "my-plate.png", identity_plate_png()
    )
    assert response.status_code == 200, response.text
    asset = response.json()["custom_decoration_assets"]["identity-plate"]
    assert asset["format"] == "png"
    assert asset["source_size"] == [456, 80]
    assert asset["animated"] is False
    assert asset["src"].startswith("/api/uploads/")
    assert response.json()["identity_plate_decoration"] == "none"

    selected = await client.patch(
        "/api/users/@me/profile",
        json={"identity_plate_decoration": "custom"},
        headers=admin_headers,
    )
    assert selected.status_code == 200, selected.text
    assert selected.json()["user"]["identity_plate_decoration"] == "custom"
    assert selected.json()["user"]["custom_identity_plate"]["src"] == asset["src"]

    members = await client.get("/api/users", headers=admin_headers)
    current = next(item for item in members.json() if item["id"] == str(admin_user.id))
    assert current["custom_identity_plate"]["source_size"] == [456, 80]


async def test_gif_upload_creates_reduced_motion_poster(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    response = await upload(
        client, admin_headers, "identity-plate", "animated.gif", identity_plate_gif()
    )
    assert response.status_code == 200, response.text
    asset = response.json()["custom_decoration_assets"]["identity-plate"]
    assert asset["animated"] is True
    assert asset["poster_src"].startswith("/api/uploads/")
    poster = await client.get(asset["poster_src"])
    assert poster.status_code == 200
    assert poster.headers["content-type"] == "image/png"


async def test_user_can_upload_each_static_decoration_role(
    client: AsyncClient, admin_headers: dict[str, str]
) -> None:
    for role in ("card-frame", "card-top", "avatar-frame"):
        response = await upload(
            client, admin_headers, role, f"my-{role}.png", static_decoration_png(role)
        )
        assert response.status_code == 200, response.text
        assert response.json()["custom_decoration_assets"][role]["format"] == "png"


@pytest.mark.parametrize(
    ("name", "data", "expected"),
    [
        ("wrong.png", identity_plate_png(size=(228, 40)), "must be 456 × 80"),
        ("unsafe.png", identity_plate_png(visible_left=True), "visible pixels in the left half"),
        ("fake.png", b"<svg><script>alert(1)</script></svg>", "not a decodable PNG or GIF"),
    ],
)
async def test_invalid_custom_assets_are_rejected(
    client: AsyncClient,
    admin_headers: dict[str, str],
    name: str,
    data: bytes,
    expected: str,
) -> None:
    response = await upload(client, admin_headers, "identity-plate", name, data)
    assert response.status_code == 422
    assert expected in response.json()["detail"]
