#!/usr/bin/env bash
# ~/.config/shell/environments/omarchy/bash.sh
# Omarchy shell + aliases + functions + init (skip envs — loaded in core/env.sh).

detect_editor_terminal 2>/dev/null

if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = yes ]; then
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
elif typeset -f source_omarchy >/dev/null 2>&1; then
    source_omarchy shell 2>/dev/null || true
    source_omarchy aliases 2>/dev/null || true
    source_omarchy functions 2>/dev/null || true
    source_omarchy init 2>/dev/null || true
    [[ $- == *i* ]] && bind -f "$OMARCHY_ROOT/default/bash/inputrc" 2>/dev/null || true
elif [[ -f "$OMARCHY_ROOT/default/bash/rc" ]]; then
    # shellcheck disable=SC1091
    source "$OMARCHY_ROOT/default/bash/shell"
    source "$OMARCHY_ROOT/default/bash/aliases"
    source "$OMARCHY_ROOT/default/bash/functions"
    source "$OMARCHY_ROOT/default/bash/init"
    [[ $- == *i* ]] && bind -f "$OMARCHY_ROOT/default/bash/inputrc"
fi
