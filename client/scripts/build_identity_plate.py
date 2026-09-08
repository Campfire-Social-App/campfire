#!/usr/bin/env python3
"""Normalize a generated nameplate master to the Campfire 456x80 contract."""

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


OUTPUT_SIZE = (456, 80)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--crop", nargs=4, type=int, metavar=("LEFT", "TOP", "RIGHT", "BOTTOM"), required=True)
    parser.add_argument("--remove-light-background", action="store_true")
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    plate = source.crop(tuple(args.crop)).resize(OUTPUT_SIZE, Image.Resampling.LANCZOS).convert("RGBA")
    mask = Image.new("L", OUTPUT_SIZE)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, OUTPUT_SIZE[0] - 1, OUTPUT_SIZE[1] - 1), radius=16, fill=255)
    if args.remove_light_background:
        source_pixels = plate.load()
        mask_pixels = mask.load()
        for y in range(OUTPUT_SIZE[1]):
            for x in range(OUTPUT_SIZE[0]):
                red, green, blue, _alpha = source_pixels[x, y]
                if min(red, green, blue) > 188 and max(red, green, blue) - min(red, green, blue) < 24:
                    mask_pixels[x, y] = 0
    plate.putalpha(mask)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    plate.save(args.output, "WEBP", lossless=True, method=6)
    print(f"Created {args.output} ({OUTPUT_SIZE[0]}x{OUTPUT_SIZE[1]})")


if __name__ == "__main__":
    main()
