#!/usr/bin/env python3
"""check_palette.py - S2 TS-2 gate: every PNG pixel must use an approved
ART_DIRECTION palette color (exact match) and binary alpha (0 or 255).

Usage: check_palette.py [--category NAME] <png-file-or-dir> [...]

Category -> allowed palette: region categories get their region palette +
Common; agents/ui get Common + UI; unknown categories get the full union.
See packages/agents_ex/assets/art/ART_DIRECTION.md (v1, approved 2026-07-16).
"""

import argparse
import pathlib
import sys

from PIL import Image

COMMON = {"2A2119", "F2E6C8", "2E5E8C", "4E86B8", "6E4A2E", "9A6B42", "5C5850", "8C877C"}
HUB = {"D9BE8C", "B8935E", "B85C40", "8A5C36", "9C9484", "C24E4E", "4E7AA6", "E8C86A"}
LUMENVEIL = {"74B356", "4E8A3E", "A8CE72", "3F7A46", "2E5C38", "E3C25C", "C2A15C", "8FBF8A"}
GRAYMARCH = {"7A8F7D", "5C7263", "9AAA92", "48594E", "6E8A9E", "B4C2AC", "8A7A5C", "A6B8C2"}
EMBERVAULT = {"9E4A32", "6E3226", "C26936", "E08A3C", "F2B03E", "7A4A3A", "4A2E28", "D9C2A6"}
VOIDREACH = {"5A4A7E", "3E3258", "8A6BB1", "C08AE0", "2A2340", "493E66", "6E86A6", "E0D9F2"}
UI = {"E8C86A", "B84A4A", "4E9E6E", "4E7AA6", "F2E6C8", "2A2119"}

CATEGORY_PALETTES = {
    "hub": COMMON | HUB,
    "lumenveil": COMMON | LUMENVEIL,
    "graymarch": COMMON | GRAYMARCH,
    "embervault": COMMON | EMBERVAULT,
    "voidreach": COMMON | VOIDREACH,
    "agents": COMMON | UI,
    "ui": COMMON | UI,
}

ALL = COMMON | HUB | LUMENVEIL | GRAYMARCH | EMBERVAULT | VOIDREACH | UI


def to_rgb(hex_set):
    return {tuple(int(h[i : i + 2], 16) for i in (0, 2, 4)) for h in hex_set}


def check_file(path, allowed):
    image = Image.open(path).convert("RGBA")
    violations = set()

    for r, g, b, a in image.getdata():
        if a == 0:
            continue
        if a != 255:
            violations.add(f"alpha={a}")
        elif (r, g, b) not in allowed:
            violations.add(f"#{r:02X}{g:02X}{b:02X}")

    return sorted(violations)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--category", default=None)
    parser.add_argument("paths", nargs="+")
    args = parser.parse_args()

    palette = CATEGORY_PALETTES.get(args.category, ALL)
    allowed = to_rgb(palette)

    files = []
    for raw in args.paths:
        path = pathlib.Path(raw)
        if path.is_dir():
            files.extend(sorted(path.rglob("*.png")))
        else:
            files.append(path)

    failed = 0
    for file in files:
        violations = check_file(file, allowed)
        if violations:
            failed += 1
            print(f"PALETTE FAIL {file}: {', '.join(violations[:8])}")

    if failed:
        print(f"palette check failed: {failed}/{len(files)} file(s)")
        return 1

    print(f"palette check ok: {len(files)} file(s), category={args.category or 'any'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
