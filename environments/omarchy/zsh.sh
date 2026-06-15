#!/usr/bin/env bash
# ~/.config/shell/environments/omarchy/zsh.sh
# Omarchy aliases + functions (envs loaded via environments/omarchy/env.sh in core/env.sh).

for _name in n ga gd reload; do
    unalias "$_name" 2>/dev/null || true
    unfunction "$_name" 2>/dev/null || true
done

if typeset -f source_omarchy >/dev/null 2>&1; then
    source_omarchy aliases 2>/dev/null || true
    source_omarchy functions 2>/dev/null || true
else
    if [[ -f "$OMARCHY_ROOT/default/bash/aliases" ]]; then
        # shellcheck disable=SC1091
        source "$OMARCHY_ROOT/default/bash/aliases"
    fi
    if [[ -f "$OMARCHY_ROOT/default/bash/functions" ]]; then
        # shellcheck disable=SC1091
        source "$OMARCHY_ROOT/default/bash/functions"
    fi
fi

unset _name
