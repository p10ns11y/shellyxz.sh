#!/usr/bin/env bash
# On-demand sync: shellyxz checkout → ~/.config/shell (preserves local/, environment, backups/).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$SCRIPT_DIR/sync-to-config.py" "$@"
