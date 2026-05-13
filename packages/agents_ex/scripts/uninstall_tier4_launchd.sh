#!/usr/bin/env bash
set -euo pipefail

LABEL="${AFW_TIER4_LAUNCHD_LABEL:-com.afw.tier4-node}"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" >/dev/null 2>&1 || true
rm -f "${PLIST_PATH}"

echo "Uninstalled ${LABEL}"
