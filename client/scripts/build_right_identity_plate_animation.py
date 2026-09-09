#!/usr/bin/env python3
"""Build a transparent, right-half-only animated identity plate from RGBA artwork."""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter


CANVAS_SIZE = (456, 80)
HALF_WIDTH = CANVAS_SIZE[0] // 2
ORNAMENT_SIZE = (228, 78)


def parse_color(value: str) -> tuple[int, int, int]:
    normalized = value.removeprefix("#")
    if len(normalized) != 6:
        raise argparse.ArgumentTypeError("color must use RRGGBB or #RRGGBB")
    try:
        return tuple(int(normalized[index:index + 2], 16) for index in (0, 2, 4))
    except ValueError as error:
        raise argparse.ArgumentTypeError("color must use hexadecimal digits") from error


def prepare_ornament(source_path: Path) -> Image.Image:
    source = Image.open(source_path).convert("RGBA")
    right = source.crop((source.width // 2, 0, source.width, source.height))
    source_alpha = right.getchannel("A")
    if source_alpha.getextrema() == (255, 255):
        # Some image generators render their transparency preview as a pale
        # checkerboard. Recover a cutout mask without removing the saturated
        # energy seams or the dark ornament itself.
        red, green, blue = right.convert("RGB").split()
        darkest_channel = ImageChops.darker(ImageChops.darker(red, green), blue)
        distance_from_white = ImageChops.invert(darkest_channel)
        source_alpha = distance_from_white.point(
            lambda value: 0 if value < 18 else min(255, round((value - 18) * 3.2))
        )
    source_alpha = source_alpha.point(lambda value: 0 if value < 40 else value)
    right.putalpha(source_alpha)
    alpha_box = right.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("source has no visible pixels in its right half")
    right = right.crop(alpha_box).resize(ORNAMENT_SIZE, Image.Resampling.LANCZOS)
    alpha = right.getchannel("A").point(
        lambda value: 0 if value < 88 else round((value - 88) * 255 / 167)
    )
    right.putalpha(alpha)
    return right


def frame_for(
    ornament: Image.Image,
    index: int,
    frame_count: int,
    glow_color: tuple[int, int, int],
    particle_color: tuple[int, int, int],
) -> Image.Image:
    phase = 2 * math.pi * index / frame_count
    pulse = 1.0 + 0.09 * math.sin(phase)
    bright = ImageEnhance.Brightness(ornament).enhance(pulse)

    glow_alpha = ornament.getchannel("A").filter(ImageFilter.GaussianBlur(3.2))
    glow_alpha = glow_alpha.point(
        lambda value: round(value * (0.22 + 0.10 * (math.sin(phase) + 1) / 2))
    )
    glow = Image.new("RGBA", ornament.size, (*glow_color, 0))
    glow.putalpha(glow_alpha)

    energy = Image.new("RGBA", ornament.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(energy)
    for particle in range(5):
        progress = (index / frame_count + particle / 5) % 1
        x = round(12 + progress * (ornament.width - 24))
        y = round(ornament.height / 2 + 13 * math.sin(phase + particle * 1.35))
        radius = 1 + particle % 2
        draw.ellipse(
            (x - radius, y - radius, x + radius, y + radius),
            fill=(*particle_color, 180),
        )
    energy = energy.filter(ImageFilter.GaussianBlur(0.7))
    energy.putalpha(Image.composite(energy.getchannel("A"), Image.new("L", ornament.size), ornament.getchannel("A")))

    right_layer = Image.alpha_composite(glow, bright)
    right_layer = Image.alpha_composite(right_layer, energy)
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(
        right_layer,
        (CANVAS_SIZE[0] - ornament.width, (CANVAS_SIZE[1] - ornament.height) // 2),
    )
    final_alpha = canvas.getchannel("A").point(
        lambda value: 0 if value < 150 else round((value - 150) * 255 / 105)
    )
    canvas.putalpha(final_alpha)
    # Enforce the contract after every operation, including resampling and blur.
    canvas.paste((0, 0, 0, 0), (0, 0, HALF_WIDTH, CANVAS_SIZE[1]))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--frames", type=Path, required=True)
    parser.add_argument("--count", type=int, default=24)
    parser.add_argument("--glow-color", type=parse_color, default=parse_color("16D3FF"))
    parser.add_argument("--particle-color", type=parse_color, default=parse_color("B9FAFF"))
    args = parser.parse_args()
    if not 2 <= args.count <= 90:
        parser.error("--count must be between 2 and 90")

    ornament = prepare_ornament(args.source)
    args.frames.mkdir(parents=True, exist_ok=True)
    for index in range(args.count):
        frame_for(
            ornament,
            index,
            args.count,
            args.glow_color,
            args.particle_color,
        ).save(args.frames / f"{index:03d}.png")
    print(f"Created {args.count} right-half identity-plate frames in {args.frames}")


if __name__ == "__main__":
    main()
