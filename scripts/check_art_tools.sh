#!/usr/bin/env bash
# check_art_tools.sh — S2 C-1: verify the pixel-art pipeline toolchain.
# Exits non-zero when a required tool is missing, with install hints.
set -euo pipefail

status=0

check() {
  local name="$1" cmd="$2" hint="$3"

  if command -v "$cmd" >/dev/null 2>&1; then
    echo "OK   ${name} ($(command -v "$cmd"))"
  else
    echo "MISS ${name} — install with: ${hint}"
    status=1
  fi
}

check "rsvg-convert (librsvg)" rsvg-convert "brew install librsvg"
check "free-tex-packer-cli" free-tex-packer-cli "npm i -g free-tex-packer-cli"

exit "$status"
