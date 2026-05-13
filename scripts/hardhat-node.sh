#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONTRACTS_DIR="${ROOT_DIR}/packages/contracts"
HARDHAT_BIN="${CONTRACTS_DIR}/node_modules/.bin/hardhat"
TARGET_MAJOR="${AFW_NODE_MAJOR:-20}"

if [[ ! -x "${HARDHAT_BIN}" ]]; then
  echo "Hardhat is not installed. Run: cd packages/contracts && npm ci" >&2
  exit 1
fi

node_major() {
  "$1" -p "process.versions.node.split('.')[0]" 2>/dev/null || true
}

supported_major() {
  [[ "$1" == "20" || "$1" == "22" ]]
}

run_with_node() {
  local node_bin="$1"
  shift
  exec "${node_bin}" "${HARDHAT_BIN}" "$@"
}

if [[ -n "${AFW_NODE_BIN:-}" ]]; then
  major="$(node_major "${AFW_NODE_BIN}")"
  if supported_major "${major}"; then
    run_with_node "${AFW_NODE_BIN}" "$@"
  fi

  echo "AFW_NODE_BIN points to unsupported Node major ${major}; expected 20 or 22." >&2
  exit 1
fi

for candidate in \
  "/opt/homebrew/opt/node@${TARGET_MAJOR}/bin/node" \
  "/usr/local/opt/node@${TARGET_MAJOR}/bin/node" \
  "/opt/homebrew/opt/node@22/bin/node" \
  "/usr/local/opt/node@22/bin/node" \
  "/opt/homebrew/opt/node@20/bin/node" \
  "/usr/local/opt/node@20/bin/node"; do
  if [[ -x "${candidate}" ]] && supported_major "$(node_major "${candidate}")"; then
    run_with_node "${candidate}" "$@"
  fi
done

if command -v node >/dev/null 2>&1; then
  current_node="$(command -v node)"
  current_major="$(node_major "${current_node}")"
  if supported_major "${current_major}"; then
    run_with_node "${current_node}" "$@"
  fi
fi

exec npx -y "node@${TARGET_MAJOR}" "${HARDHAT_BIN}" "$@"
