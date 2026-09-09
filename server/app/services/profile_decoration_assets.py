from dataclasses import dataclass
from io import BytesIO

from PIL import Image, ImageSequence, UnidentifiedImageError

ROLE_SPECS = {
    "card-frame": {"size": (600, 908), "bytes": 2 * 1024 * 1024, "frames": 1, "pixels": 600 * 908},
    "card-top": {"size": (600, 128), "bytes": 5 * 1024 * 1024, "frames": 90, "pixels": 6_912_000},
    "avatar-frame": {"size": (384, 384), "bytes": 3 * 1024 * 1024, "frames": 90, "pixels": 13_300_000},
    "identity-plate": {"size": (456, 80), "bytes": 4 * 1024 * 1024, "frames": 90, "pixels": 3_300_000},
}


class DecorationValidationError(ValueError):
    pass


@dataclass(frozen=True)
class ValidatedDecoration:
    extension: str
    content_type: str
    source_size: tuple[int, int]
    animated: bool
    poster: bytes | None


def _transparent_ratio(image: Image.Image, box: tuple[int, int, int, int]) -> float:
    alpha = image.convert("RGBA").getchannel("A").crop(box)
    return alpha.histogram()[0] / max(1, alpha.width * alpha.height)


def validate_decoration(data: bytes, role: str) -> ValidatedDecoration:
    spec = ROLE_SPECS[role]
    if not data:
        raise DecorationValidationError("The decoration file is empty")
    if len(data) > spec["bytes"]:
        raise DecorationValidationError(
            f"{role} exceeds the {spec['bytes'] // (1024 * 1024)} MiB limit"
        )

    try:
        image = Image.open(BytesIO(data))
        image.load()
        image.seek(0)
    except (UnidentifiedImageError, OSError, SyntaxError) as error:
        raise DecorationValidationError("The file is not a decodable PNG or GIF") from error

    if image.format not in {"PNG", "GIF"}:
        raise DecorationValidationError("Custom decorations accept only real PNG or GIF files")
    if image.size != spec["size"]:
        raise DecorationValidationError(
            f"{role} must be {spec['size'][0]} × {spec['size'][1]} px; received {image.width} × {image.height} px"
        )
    frames = getattr(image, "n_frames", 1)
    if frames > spec["frames"]:
        raise DecorationValidationError(
            f"The animation has {frames} frames; the maximum is {spec['frames']}"
        )
    if image.width * image.height * frames > spec["pixels"]:
        raise DecorationValidationError("The decoded animation exceeds the pixel limit")
    if role == "card-frame" and frames != 1:
        raise DecorationValidationError("Card frames must be static; upload animation as card top")

    if image.format == "PNG" and "A" not in image.getbands() and "transparency" not in image.info:
        raise DecorationValidationError("PNG decorations must contain an alpha channel")
    if image.format == "GIF" and "transparency" not in image.info:
        raise DecorationValidationError("GIF decorations must contain a transparency index")

    durations: list[int] = []
    decoded_frames: list[Image.Image] = []
    try:
        for frame in ImageSequence.Iterator(image):
            decoded_frames.append(frame.convert("RGBA"))
            durations.append(int(frame.info.get("duration", image.info.get("duration", 0))))
    except (OSError, SyntaxError) as error:
        raise DecorationValidationError("Every animation frame must be decodable") from error
    if frames > 1:
        if image.info.get("loop") != 0:
            raise DecorationValidationError("Animated decorations must loop continuously")
        if sum(durations) > 6000:
            raise DecorationValidationError("The animation may last at most 6 seconds")
        if any(duration < 67 for duration in durations):
            raise DecorationValidationError("Animation speed may not exceed 15 fps")

    for index, frame in enumerate(decoded_frames):
        if role == "avatar-frame" and _transparent_ratio(frame, (99, 99, 285, 285)) < 0.98:
            raise DecorationValidationError(
                f"Avatar frame {index + 1} must keep at least 98% of the protected center transparent"
            )
        if role == "card-frame" and _transparent_ratio(frame, (40, 170, 560, 844)) < 0.98:
            raise DecorationValidationError(
                "The card frame must keep at least 98% of the profile content area transparent"
            )
        if role == "card-top" and frame.getpixel((image.width // 2, image.height - 1))[3] != 0:
            raise DecorationValidationError(
                f"Card-top frame {index + 1} must keep the bottom center transparent"
            )
        if role == "identity-plate":
            if _transparent_ratio(frame, (0, 0, image.width // 2, image.height)) != 1:
                raise DecorationValidationError(
                    f"Identity-plate frame {index + 1} has visible pixels in the left half"
                )
            right_ratio = _transparent_ratio(
                frame, (image.width // 2, 0, image.width, image.height)
            )
            if right_ratio < 0.55:
                raise DecorationValidationError(
                    f"Identity-plate frame {index + 1} must keep at least 55% of its right half transparent"
                )
            if right_ratio == 1:
                raise DecorationValidationError("The identity plate has no visible right-side ornament")

    poster: bytes | None = None
    if frames > 1:
        output = BytesIO()
        decoded_frames[0].save(output, format="PNG", optimize=True)
        poster = output.getvalue()
    return ValidatedDecoration(
        extension=".gif" if image.format == "GIF" else ".png",
        content_type="image/gif" if image.format == "GIF" else "image/png",
        source_size=image.size,
        animated=frames > 1,
        poster=poster,
    )
