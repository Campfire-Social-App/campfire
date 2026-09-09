#!/usr/bin/env python3
"""Normalize generated decoration art and build an animated full-card GIF."""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageEnhance


CARD_SIZE = (512, 768)
AVATAR_SIZE = (512, 512)
FRAME_COUNT = 18
FRAME_DURATION_MS = 100


def is_accent(theme: str, red: int, green: int, blue: int) -> bool:
    if theme == "ember":
        return red > 115 and green > 28 and red > green * 1.25 and red > blue * 1.45
    return blue > 95 and (red > 85 or green > 85) and max(red, green, blue) - min(red, green, blue) > 45


def normalize_card(source: Image.Image) -> Image.Image:
    image = source.resize(CARD_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    pixels = image.load()
    for y in range(CARD_SIZE[1]):
        for x in range(CARD_SIZE[0]):
            if 55 <= x < 457 and 150 <= y < 698:
                pixels[x, y] = (0, 0, 0, 0)
    return image


def normalize_avatar(source: Image.Image) -> Image.Image:
    image = source.resize(AVATAR_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    pixels = image.load()
    center = AVATAR_SIZE[0] // 2
    aperture_radius = 176
    for y in range(AVATAR_SIZE[1]):
        for x in range(AVATAR_SIZE[0]):
            if (x - center) ** 2 + (y - center) ** 2 <= aperture_radius ** 2:
                pixels[x, y] = (0, 0, 0, 0)
            if (x - 424) ** 2 + (y - 424) ** 2 <= 42 ** 2:
                pixels[x, y] = (0, 0, 0, 0)
    return image


def accent_layer(image: Image.Image, theme: str) -> Image.Image:
    source = image.load()
    layer = Image.new("RGBA", image.size)
    target = layer.load()
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = source[x, y]
            if alpha and is_accent(theme, red, green, blue):
                intensity = max(red, green, blue) - min(red, green, blue)
                target[x, y] = (red, green, blue, min(alpha, max(45, intensity)))
    return layer


def animate_layer(layer: Image.Image, phase: float, strength: float, theme: str) -> Image.Image:
    vertical = 4 if theme == "ember" else 2
    horizontal = 2 if theme == "ember" else 1
    width = round(layer.width * (1 + 0.003 * math.sin(phase)))
    height = round(layer.height * (1 + 0.006 * math.cos(phase)))
    result = layer.resize((width, height), Image.Resampling.BICUBIC)
    result = ImageEnhance.Brightness(result).enhance(0.9 + 0.22 * math.sin(phase + 0.5))
    alpha = result.getchannel("A").point(lambda value: round(value * strength))
    result.putalpha(alpha)
    canvas = Image.new("RGBA", layer.size)
    canvas.alpha_composite(result, (
        (layer.width - width) // 2 + round(horizontal * math.sin(phase)),
        (layer.height - height) // 2 + round(vertical * math.cos(phase)),
    ))
    return canvas


def protect_card_center(image: Image.Image) -> None:
    pixels = image.load()
    for y in range(150, 698):
        for x in range(55, 457):
            pixels[x, y] = (0, 0, 0, 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--theme", choices=("ember", "neon"), required=True)
    parser.add_argument("--card-source", type=Path, required=True)
    parser.add_argument("--avatar-source", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    args.output_dir.mkdir(parents=True, exist_ok=True)
    prefix = "ember-sovereign" if args.theme == "ember" else "neon-revenant"
    card = normalize_card(Image.open(args.card_source))
    avatar = normalize_avatar(Image.open(args.avatar_source))
    energy = accent_layer(card, args.theme)

    poster_path = args.output_dir / f"{prefix}-frame-poster.webp"
    avatar_path = args.output_dir / f"{prefix}-avatar.webp"
    gif_path = args.output_dir / f"{prefix}-frame-animated.gif"
    card.save(poster_path, "WEBP", lossless=True, method=6)
    avatar.save(avatar_path, "WEBP", lossless=True, method=6)

    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        phase = 2 * math.pi * index / FRAME_COUNT
        frame = card.copy()
        frame.alpha_composite(animate_layer(energy, phase, 0.38 + 0.14 * math.sin(phase + 0.8), args.theme))
        protect_card_center(frame)
        frames.append(frame)
    frames[0].save(
        gif_path,
        save_all=True,
        append_images=frames[1:],
        duration=FRAME_DURATION_MS,
        loop=0,
        disposal=2,
        optimize=True,
    )
    print(f"Created {prefix}: {FRAME_COUNT} frames, {1000 // FRAME_DURATION_MS} fps")


if __name__ == "__main__":
    main()
