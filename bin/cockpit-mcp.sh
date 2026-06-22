#!/usr/bin/env bash
# Shim → plugins/verification (SN-4). Stable path for tmux binds and migrate.
set -euo pipefail
shim_path="${BASH_SOURCE[0]:-$0}"
shim_name="$(basename "$shim_path")"
shell_root="${SHELL_ROOT:-$HOME/.config/shell}"
plugin_script="${shell_root}/plugins/verification/bin/${shim_name}"
if [ ! -x "$plugin_script" ]; then
    echo "${shim_name}: missing $plugin_script" >&2
    exit 1
fi
exec "$plugin_script" "$@"
