#!/usr/bin/env python3
"""px2svg.py - converts .px text pixel grids into ART_DIRECTION-compliant
SVGs (1 pixel = 1 <rect>, palette-only colors, crispEdges).

.px format:
    # comment lines (ignored)
    category: hub
    X=#D9BE8C            (single-char legend entries; '.' = transparent)
    grid:
    ..XX..
    .XXXX.

Usage: px2svg.py <in.px> [out.svg]   (default: same path with .svg)
"""

import pathlib
import re
import sys


def parse(path):
    category = "unknown"
    legend = {}
    rows = []
    in_grid = False

    for raw in path.read_text().splitlines():
        line = raw.rstrip("\n")

        if in_grid:
            if line.strip():
                rows.append(line)
            continue

        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped == "grid:":
            in_grid = True
            continue
        if stripped.startswith("category:"):
            category = stripped.split(":", 1)[1].strip()
            continue

        match = re.fullmatch(r"(.)=(#[0-9A-F]{6})", stripped)
        if not match:
            raise ValueError(f"bad legend line: {stripped!r}")
        legend[match.group(1)] = match.group(2)

    if not rows:
        raise ValueError("empty grid")

    width = len(rows[0])
    for index, row in enumerate(rows):
        if len(row) != width:
            raise ValueError(f"row {index} has length {len(row)}, expected {width}")

    return category, legend, rows


def emit(category, legend, rows):
    height = len(rows)
    width = len(rows[0])
    parts = [
        f"<!-- AFW 32px | palette: {category} | ART_DIRECTION v1 -->",
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" '
        f'width="{width}" height="{height}" shape-rendering="crispEdges">',
    ]

    for y, row in enumerate(rows):
        for x, char in enumerate(row):
            if char == ".":
                continue
            if char not in legend:
                raise ValueError(f"unknown pixel {char!r} at {x},{y}")
            parts.append(f'  <rect x="{x}" y="{y}" width="1" height="1" fill="{legend[char]}"/>')

    parts.append("</svg>")
    return "\n".join(parts) + "\n"


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    src = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else src.with_suffix(".svg")

    category, legend, rows = parse(src)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(emit(category, legend, rows))
    print(f"{src.name}: {len(rows[0])}x{len(rows)} -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
