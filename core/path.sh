#!/usr/bin/env sh
# ~/.config/shell/core/path.sh — PATH helpers (POSIX sh).
# path_prepend / path_append remove existing occurrences of the segment first,
# then add once — no global dedupe/normalize pass needed.

_path_remove_segment() {
    _target="$1"
    _rest=""
    _scan="$PATH"
    while [ -n "$_scan" ]; do
        case "$_scan" in
            *:*) _p="${_scan%%:*}"; _scan="${_scan#*:}" ;;
            *) _p="$_scan"; _scan="" ;;
        esac
        [ -n "$_p" ] || continue
        [ "$_p" = "$_target" ] && continue
        if [ -z "$_rest" ]; then
            _rest="$_p"
        else
            _rest="$_rest:$_p"
        fi
    done
    PATH="$_rest"
    unset _target _rest _scan _p
}

# Highest priority: remove dir if present, then prepend once.
path_prepend() {
    _dir="$1"
    [ -d "$_dir" ] || return
    _path_remove_segment "$_dir"
    export PATH="$_dir${PATH:+:$PATH}"
    unset _dir
}

# Lowest priority: remove dir if present, then append once.
path_append() {
    _dir="$1"
    [ -d "$_dir" ] || return
    _path_remove_segment "$_dir"
    export PATH="${PATH:+$PATH:}$_dir"
    unset _dir
}

path_add() { path_prepend "$@"; }

unset _target _rest _scan _p _dir 2>/dev/null || true
