#!/usr/bin/env sh
# ~/.config/shell/environments/omarchy/fish.sh — bash syntax for bass.

if typeset -f source_omarchy >/dev/null 2>&1; then
    source_omarchy aliases 2>/dev/null || true
elif [ -f "$OMARCHY_ROOT/default/bash/aliases" ]; then
    # shellcheck disable=SC1091
    . "$OMARCHY_ROOT/default/bash/aliases"
fi
