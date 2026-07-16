#!/usr/bin/env python3
"""make_preview.py - renders SVG sprites onto both ground tones of their
region at pixel-perfect scale for the TS-4 master preview gate.

Usage:
  make_preview.py --out preview_hub.png --bg1 '#D9BE8C' --bg2 '#B8935E' \
      [--scale 4] sprite1.svg sprite2.svg ...
"""

import argparse
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

PAD = 12
LABEL_H = 14


def render(svg, scale):
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
        out = tmp.name
    subprocess.run(["rsvg-convert", "-z", str(scale), str(svg), "-o", out], check=True)
    image = Image.open(out).convert("RGBA")
    pathlib.Path(out).unlink()
    return image


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--bg1", required=True)
    parser.add_argument("--bg2", required=True)
    parser.add_argument("--scale", type=int, default=4)
    parser.add_argument("svgs", nargs="+")
    args = parser.parse_args()

    sprites = [(pathlib.Path(p), render(p, args.scale)) for p in args.svgs]
    backgrounds = [hex_rgb(args.bg1), hex_rgb(args.bg2)]

    cell_w = max(image.width for _, image in sprites) + PAD * 2
    cell_h = max(image.height for _, image in sprites) + PAD * 2 + LABEL_H
    sheet = Image.new("RGBA", (cell_w * 2, cell_h * len(sprites)), (31, 27, 22, 255))
    draw = ImageDraw.Draw(sheet)

    for row, (path, image) in enumerate(sprites):
        for col, bg in enumerate(backgrounds):
            x0, y0 = col * cell_w, row * cell_h
            draw.rectangle([x0 + 2, y0 + 2, x0 + cell_w - 3, y0 + cell_h - LABEL_H - 3], fill=bg + (255,))
            sheet.alpha_composite(
                image,
                (x0 + (cell_w - image.width) // 2, y0 + PAD + (cell_h - PAD * 2 - LABEL_H - image.height) // 2),
            )

        draw.text((row * 0 + 6, (row + 1) * cell_h - LABEL_H), path.stem, fill=(247, 232, 199, 255))

    sheet.convert("RGB").save(args.out)
    print(f"preview: {args.out} ({sheet.width}x{sheet.height})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
