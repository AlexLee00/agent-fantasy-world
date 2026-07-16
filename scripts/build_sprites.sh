#!/usr/bin/env bash
# build_sprites.sh — S2 C-3: SVG -> PNG -> per-category spritesheet + atlas.
#
# Source of truth: packages/agents_ex/assets/art/svg/<category>/*.svg
# Output:          packages/agents_ex/priv/static/assets/sprites/<category>.{png,json}
#
# Usage: scripts/build_sprites.sh [--src DIR] [--out DIR] [--skip-palette]
# Wrapped by `mix afw.build_sprites` (packages/agents_ex).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/packages/agents_ex/assets/art/svg"
OUT="$ROOT/packages/agents_ex/priv/static/assets/sprites"
BUILD="${TMPDIR:-/tmp}/afw_art_build"
SKIP_PALETTE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --src) SRC="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --skip-palette) SKIP_PALETTE=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for tool in rsvg-convert free-tex-packer-cli; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "MISS $tool — run scripts/check_art_tools.sh for install hints" >&2
    exit 1
  fi
done

if [[ ! -d "$SRC" ]]; then
  echo "no svg source directory ($SRC) — nothing to build"
  exit 0
fi

rm -rf "$BUILD"
mkdir -p "$BUILD" "$OUT"

shopt -s nullglob
built=0

for dir in "$SRC"/*/; do
  category="$(basename "$dir")"
  svgs=("$dir"*.svg)
  if [[ ${#svgs[@]} -eq 0 ]]; then
    continue
  fi

  pngdir="$BUILD/png/$category"
  mkdir -p "$pngdir"

  for svg in "${svgs[@]}"; do
    base="$(basename "$svg" .svg)"
    rsvg-convert "$svg" -o "$pngdir/$base.png"
  done

  if [[ "$SKIP_PALETTE" -eq 0 ]]; then
    python3 "$ROOT/scripts/check_palette.py" --category "$category" "$pngdir"
  fi

  project="$BUILD/$category.ftpp"
  cat > "$project" <<EOF
{
  "meta": { "version": "0.2.0" },
  "savePath": "$OUT",
  "images": [],
  "folders": ["$pngdir"],
  "packOptions": {
    "textureName": "$category",
    "textureFormat": "png",
    "removeFileExtension": true,
    "prependFolderName": false,
    "base64Export": false,
    "tinify": false,
    "tinifyKey": "",
    "scale": 1,
    "filter": "none",
    "exporter": "Phaser 3",
    "fileName": "$category",
    "savePath": "$OUT",
    "width": 2048,
    "height": 2048,
    "fixedSize": false,
    "powerOfTwo": false,
    "padding": 1,
    "extrude": 0,
    "allowRotation": false,
    "allowTrim": false,
    "trimMode": "trim",
    "alphaThreshold": "0",
    "detectIdentical": true,
    "packer": "MaxRectsPacker",
    "packerMethod": "Smart"
  }
}
EOF

  free-tex-packer-cli --project "$project"

  if [[ ! -f "$OUT/$category.png" || ! -f "$OUT/$category.json" ]]; then
    echo "FAIL $category: expected $OUT/$category.png + .json" >&2
    exit 1
  fi

  echo "OK   $category: ${#svgs[@]} svg -> sheet + atlas"
  built=$((built + 1))
done

if [[ "$built" -eq 0 ]]; then
  echo "no svg assets yet under $SRC — nothing to build"
else
  echo "done: $built category sheet(s) in $OUT"
fi
