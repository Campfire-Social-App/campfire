#!/usr/bin/env python3
"""Turns the shared app artwork into the two square PNGs the launcher-icon
generator needs.

The source is the same file the Tauri client ships (`client/src-tauri/
app-icon.png`), so both clients install with the same face. It is a rounded
badge with transparent corners and a little slack around it, which is right for
a desktop icon and wrong for both mobile shapes, in opposite ways:

* **iOS and legacy Android** want an opaque square. The badge's own corner
  radius is close enough to iOS's mask that the artwork survives it, so the
  badge is kept and the transparent corners are filled with a blurred,
  zoomed copy of itself — no colour has to be guessed, and nothing shows
  through where the two roundings disagree.
* **Android adaptive** draws the foreground on a 108dp canvas and shows only
  the middle 72dp, under whatever mask the launcher uses. A rounded badge there
  would read as a square trapped inside a circle, so the frame is cropped away
  and the scene alone fills the canvas; `flutter_launcher_icons` then insets it
  into the safe zone, which leaves the fire whole under every mask shape.

Run from `app/`:

    python3 tool/generate_icon_sources.py

then `dart run flutter_launcher_icons` to fan the two files out across the
densities. Both outputs are committed; this only has to run again if the
artwork changes.
"""

from pathlib import Path

from PIL import Image, ImageFilter

SOURCE = Path(__file__).resolve().parents[2] / "client" / "src-tauri" / "app-icon.png"
OUT = Path(__file__).resolve().parent.parent / "assets" / "icon"

SIZE = 1024

# How much of the badge is scene rather than frame. A rounded rect of corner
# radius r has no transparent corner inside a centred square of side
# w - 2r(1 - 1/√2); at r ≈ 0.2w that is ~0.88w, and 0.86 leaves a margin for
# the glow that sits just inside the rim.
SCENE = 0.86


def badge(image: Image.Image) -> Image.Image:
    """The artwork itself, without the transparent slack around it.

    Measured by coverage rather than by `getbbox`: the source carries a few
    stray specks outside the badge, and one opaque pixel is enough to make a
    bounding box useless.
    """
    width, height = image.size
    alpha = image.split()[3].load()
    rows = [
        y
        for y in range(height)
        if sum(1 for x in range(0, width, 4) if alpha[x, y] > 200) * 4 > width * 0.3
    ]
    columns = [
        x
        for x in range(width)
        if sum(1 for y in range(0, height, 4) if alpha[x, y] > 200) * 4 > height * 0.3
    ]
    return image.crop((columns[0], rows[0], columns[-1] + 1, rows[-1] + 1))


def square(image: Image.Image) -> Image.Image:
    """Centres a not-quite-square crop on a transparent square canvas."""
    side = max(image.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(image, ((side - image.width) // 2, (side - image.height) // 2))
    return canvas


def opaque_icon(art: Image.Image) -> Image.Image:
    """The badge over a blurred, zoomed copy of itself, so the corners are
    filled with the colours that were next to them."""
    art = square(art).resize((SIZE, SIZE), Image.LANCZOS)

    zoom = int(SIZE * 1.4)
    backdrop = art.resize((zoom, zoom), Image.LANCZOS).crop(
        ((zoom - SIZE) // 2, (zoom - SIZE) // 2, (zoom + SIZE) // 2, (zoom + SIZE) // 2)
    )
    # Over black first: the zoomed copy has transparent corners of its own, and
    # a blur would smear that transparency back into the fill.
    backdrop = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (4, 8, 26, 255)), backdrop)
    backdrop = backdrop.filter(ImageFilter.GaussianBlur(SIZE // 24))

    return Image.alpha_composite(backdrop, art)


def scene_of(art: Image.Image) -> Image.Image:
    """The artwork inside the badge, with the frame and its rounded corners
    cropped away."""
    width, height = art.size
    side = min(width, height) * SCENE
    return art.crop(
        (
            round((width - side) / 2),
            round((height - side) / 2),
            round((width + side) / 2),
            round((height + side) / 2),
        )
    )


def adaptive_foreground(art: Image.Image) -> Image.Image:
    """The scene alone, edge to edge.

    The safe zone is not this file's job: `flutter_launcher_icons` wraps the
    foreground in a 16% inset, which leaves it covering 68% of the 108dp canvas
    against the 72dp the mask shows — so what survives every mask shape is
    almost the whole scene, and the fire never touches an edge.
    """
    return scene_of(art).resize((SIZE, SIZE), Image.LANCZOS)


def main() -> None:
    art = badge(Image.open(SOURCE).convert("RGBA"))
    OUT.mkdir(parents=True, exist_ok=True)
    opaque_icon(art).save(OUT / "icon.png")
    adaptive_foreground(art).save(OUT / "icon_foreground.png")
    print(f"wrote {OUT}/icon.png and {OUT}/icon_foreground.png from {SOURCE.name}")


if __name__ == "__main__":
    main()
