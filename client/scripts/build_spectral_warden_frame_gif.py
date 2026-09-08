#!/usr/bin/env python3
"""Animate only the spectral flame energy while preserving card-frame geometry."""

import argparse
import math
from pathlib import Path

from PIL import Image, ImageEnhance


SIZE = (512, 768)
FRAME_COUNT = 18
FRAME_DURATION_MS = 100


def flame_layer(image: Image.Image) -> Image.Image:
    image = image.resize(SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    source = image.load()
    layer = Image.new("RGBA", SIZE)
    target = layer.load()
    for y in range(SIZE[1]):
        for x in range(SIZE[0]):
            red, green, blue, alpha = source[x, y]
            border_zone = y < 180 or y > 685 or x < 82 or x > 429
            cyan = blue > 105 and green > 75 and blue > red * 1.2
            if border_zone and cyan and alpha:
                intensity = max(0, min(255, (green + blue - red * 2)))
                target[x, y] = (red, green, blue, min(alpha, intensity))
    return layer


def shifted(layer: Image.Image, phase: float, strength: float) -> Image.Image:
    width = round(SIZE[0] * (1 + 0.004 * math.sin(phase)))
    height = round(SIZE[1] * (1 + 0.006 * math.cos(phase)))
    animated = layer.resize((width, height), Image.Resampling.BICUBIC)
    animated = ImageEnhance.Brightness(animated).enhance(0.92 + 0.18 * math.sin(phase + 0.4))
    alpha = animated.getchannel("A").point(lambda value: round(value * strength))
    animated.putalpha(alpha)
    canvas = Image.new("RGBA", SIZE)
    canvas.alpha_composite(animated, (
        (SIZE[0] - width) // 2 + round(2 * math.sin(phase)),
        (SIZE[1] - height) // 2 + round(3 * math.cos(phase)),
    ))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--alternate", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    base = Image.open(args.source).resize(SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    primary_flames = flame_layer(base)
    alternate_flames = flame_layer(Image.open(args.alternate))
    frames: list[Image.Image] = []
    for index in range(FRAME_COUNT):
        phase = 2 * math.pi * index / FRAME_COUNT
        transition = (1 - math.cos(phase)) / 2
        frame = base.copy()
        frame.alpha_composite(shifted(primary_flames, phase, 0.34 + 0.18 * (1 - transition)))
        frame.alpha_composite(shifted(alternate_flames, phase + 1.3, 0.30 * transition))
        frames.append(frame)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        args.output,
        save_all=True,
        append_images=frames[1:],
        duration=FRAME_DURATION_MS,
        loop=0,
        disposal=2,
        optimize=True,
    )
    print(f"Created {args.output}: {FRAME_COUNT} frames, {1000 // FRAME_DURATION_MS} fps")


if __name__ == "__main__":
    main()
