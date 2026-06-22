#!/usr/bin/env bash
# Install or refresh ~/.config/tmux/verify.conf from tmux.verify.conf.ex.
# Usage: sync-tmux-verify.sh [--reload]
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/shell}"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [ -f "$CONFIG_DIR/tmux.verify.conf.ex" ]; then
    SRC="$CONFIG_DIR/tmux.verify.conf.ex"
else
    SRC="$PLUGIN_ROOT/conf/tmux.verify.conf.ex"
fi
DEST="${HOME}/.config/tmux/verify.conf"
TMUX_CONF="${HOME}/.config/tmux/tmux.conf"
MANAGED_MARKER="Managed by ~/.config/shell/bin/migrate.sh"
RELOAD=0

if [[ "${1:-}" == "--reload" ]]; then
    RELOAD=1
fi

if [[ ! -f "$SRC" ]]; then
    echo "sync-tmux-verify: missing $SRC" >&2
    exit 1
fi

mkdir -p "$(dirname "$DEST")"

if [[ -f "$DEST" ]] && ! grep -qF "$MANAGED_MARKER" "$DEST" 2>/dev/null; then
    echo "sync-tmux-verify: $DEST is not managed — backup and use --force, or merge binds by hand" >&2
    echo "  cp $SRC $DEST   # if you want the template wholesale" >&2
    exit 1
fi

cp "$SRC" "$DEST"
echo "sync-tmux-verify: installed $DEST"

if [[ -f "$TMUX_CONF" ]] && ! grep -qF 'source-file ~/.config/tmux/verify.conf' "$TMUX_CONF" 2>/dev/null; then
    echo "sync-tmux-verify: WARN tmux.conf does not source verify.conf — run migrate.sh" >&2
fi

cat <<'EOF'

Reload tmux (inside a tmux session):
  Prefix+q     (Ctrl+Space, release, then q)

Workflow keys — use SHIFT (capital letters):
  Prefix+B     agent build   (Shift+b — not lowercase b)
  Prefix+V     verify cockpit (Shift+v — not lowercase v = vertical split)
  Prefix+T     test cockpit   (Shift+t)

Omarchy splits (unchanged, lowercase):
  Prefix+h     split horizontal
  Prefix+v     split vertical

Keymap menu: Prefix+?  or click status-right
EOF

if [[ "$RELOAD" == 1 ]] && [[ -n "${TMUX:-}" ]]; then
    tmux source-file "$TMUX_CONF" 2>/dev/null && echo "sync-tmux-verify: reloaded tmux.conf in this session"
fi
