#!/usr/bin/env python3
"""Generates the Nexa Android launcher icon from logo_nexa.png.

The source logo is a navy monogram on white. The app it belongs to is dark navy,
so the same geometry is re-inked in the app's accent colour over the app's
canvas colour. Nothing about the silhouette is redrawn: the mark is lifted from
the source file using its own antialiasing as a coverage mask, then placed on a
flat background.

Two sets of assets come out of this:

  mipmap-<density>/ic_launcher.png              legacy icon, API < 26
  mipmap-<density>/ic_launcher_foreground.png   adaptive foreground, API 26+

The adaptive foreground canvas is 108dp with a 72dp safe zone, which is 66.7% of
the canvas, so the mark is sized to sit inside that circle on every launcher
mask. Colours are the app's own tokens, from
lib/core/constants/design_tokens.dart: canvas #001135, accent #E3F2FD.

Usage:  python3 tool/generate_launcher_icons.py
Needs Pillow and NumPy. Run from anywhere; paths resolve off this file.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "logo_nexa.png"
RES = ROOT / "android/app/src/main/res"

BACKGROUND = (0x00, 0x11, 0x35)  # canvas token
MARK = (0xE3, 0xF2, 0xFD)  # accent token

# Legacy icon, 48dp canvas. The mark stays inside the inscribed circle so a
# launcher that crops the legacy bitmap still shows it whole.
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
LEGACY_MARK = 0.56
LEGACY_RADIUS = 0.18

# Adaptive icon, 108dp canvas, 72dp safe zone.
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
ADAPTIVE_MARK = 0.56


def load_mark() -> Image.Image:
    """The monogram as an alpha mask, cropped to its own bounding box."""
    source = np.asarray(Image.open(SOURCE).convert("RGB")).astype(np.float64)
    ink = source.reshape(-1, 3).min(axis=0)  # the monogram's flat colour
    # Each pixel is a*ink + (1-a)*255, so coverage falls straight out per
    # channel. Averaging the three keeps the antialiased edges smooth.
    coverage = (255.0 - source) / (255.0 - ink)
    mask = np.clip(coverage.mean(axis=2) * 255.0, 0, 255).astype(np.uint8)
    image = Image.fromarray(mask, mode="L")
    return image.crop(image.getbbox())


def place(mark: Image.Image, canvas: int, fraction: float) -> Image.Image:
    """Scales the mark to `fraction` of the canvas height, centred."""
    height = max(1, round(canvas * fraction))
    width = max(1, round(mark.width * height / mark.height))
    scaled = mark.resize((width, height), Image.LANCZOS)
    image = Image.new("L", (canvas, canvas), 0)
    image.paste(scaled, ((canvas - width) // 2, (canvas - height) // 2))
    return image


def tinted(mask: Image.Image) -> Image.Image:
    return Image.merge(
        "RGBA",
        (
            Image.new("L", mask.size, MARK[0]),
            Image.new("L", mask.size, MARK[1]),
            Image.new("L", mask.size, MARK[2]),
            mask,
        ),
    )


def write_legacy(mark: Image.Image) -> None:
    for density, size in LEGACY.items():
        plate = Image.new("RGBA", (size, size), BACKGROUND + (255,))
        # A rounded square, so a launcher that shows the legacy bitmap
        # uncropped still reads the app's own corner language.
        ImageDraw.Draw(plate).rounded_rectangle(
            [(0, 0), (size - 1, size - 1)],
            radius=round(size * LEGACY_RADIUS),
            fill=BACKGROUND + (255,),
        )
        composed = Image.alpha_composite(plate, tinted(place(mark, size, LEGACY_MARK)))
        path = RES / f"mipmap-{density}" / "ic_launcher.png"
        composed.save(path)
        print(f"wrote {path.relative_to(ROOT)}  {size}x{size}")


def write_adaptive(mark: Image.Image) -> None:
    for density, size in ADAPTIVE.items():
        foreground = tinted(place(mark, size, ADAPTIVE_MARK))
        path = RES / f"mipmap-{density}" / "ic_launcher_foreground.png"
        foreground.save(path)
        print(f"wrote {path.relative_to(ROOT)}  {size}x{size}")


def main() -> None:
    mark = load_mark()
    print(f"mark {mark.width}x{mark.height} lifted from {SOURCE.name}")
    write_legacy(mark)
    write_adaptive(mark)


if __name__ == "__main__":
    main()
