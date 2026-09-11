#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATER="$SCRIPT_DIR/scripts/update.py"

if command -v python3 >/dev/null 2>&1; then
  exec python3 -B "$UPDATER" "$@"
elif [[ -x /run/current-system/sw/bin/python3 ]]; then
  exec /run/current-system/sw/bin/python3 -B "$UPDATER" "$@"
elif command -v nix >/dev/null 2>&1 && [[ -z "${SELFHOST_UPDATE_IN_DEVSHELL:-}" ]]; then
  exec env SELFHOST_UPDATE_IN_DEVSHELL=1 nix develop --no-write-lock-file "$SCRIPT_DIR" --command python3 -B "$UPDATER" "$@"
else
  echo "update.sh: Python 3 is required (PATH, system profile, or flake devShell)" >&2
  exit 1
fi
