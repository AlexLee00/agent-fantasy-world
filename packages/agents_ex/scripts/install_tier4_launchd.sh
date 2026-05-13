#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="${AFW_TIER4_LAUNCHD_LABEL:-com.afw.tier4-node}"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
LOG_DIR="${ROOT_DIR}/logs"
MIX_BIN="${MIX_BIN:-$(command -v mix)}"
PORT="${TIER4_NODE_PORT:-18791}"
BACKEND="${TIER4_NODE_BACKEND:-afw-basic}"
PUBLIC_URL="${TIER4_NODE_PUBLIC_URL:-}"

mkdir -p "${HOME}/Library/LaunchAgents" "${LOG_DIR}"

if [[ -z "${MIX_BIN}" ]]; then
  echo "mix executable not found. Set MIX_BIN=/path/to/mix." >&2
  exit 1
fi

cat > "${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>-i</string>
    <string>HOME=${HOME}</string>
    <string>PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    <string>/bin/zsh</string>
    <string>-lc</string>
    <string>cd "${ROOT_DIR}" &amp;&amp; AFW_DISABLE_BOOT_AGENTS=1 TIER4_NODE_BACKEND="${BACKEND}" TIER4_NODE_PORT="${PORT}" TIER4_NODE_PUBLIC_URL="${PUBLIC_URL}" "${MIX_BIN}" run --no-start scripts/run_tier4_node.exs</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>${ROOT_DIR}</string>
  <key>StandardOutPath</key>
  <string>${LOG_DIR}/tier4-node.out.log</string>
  <key>StandardErrorPath</key>
  <string>${LOG_DIR}/tier4-node.err.log</string>
</dict>
</plist>
PLIST

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
launchctl kickstart -k "gui/$(id -u)/${LABEL}"

echo "Installed ${LABEL}"
echo "Plist: ${PLIST_PATH}"
echo "Port: ${PORT}"
echo "Backend: ${BACKEND}"
echo "Public URL: ${PUBLIC_URL:-local-only}"
echo "Logs: ${LOG_DIR}/tier4-node.out.log, ${LOG_DIR}/tier4-node.err.log"
