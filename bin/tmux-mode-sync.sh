#!/usr/bin/env bash
# Shim → plugins/verification (SN-4). Stable path for tmux binds and migrate.
set -euo pipefail
shell_root="${SHELL_ROOT:-$HOME/.config/shell}"
plugin_script="${shell_root}/plugins/verification/bin/$(basename "$0")"
if [ ! -x "$plugin_script" ]; then
    echo "$(basename "$0"): missing $plugin_script" >&2
    exit 1
fi
exec "$plugin_script" "$@"
