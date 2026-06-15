#!/usr/bin/env sh
# ~/.config/shell/core/path.sh — PATH helpers (POSIX sh).
# path_prepend / path_append are O(1) when the dir is absent or already positioned.

_path_remove_segment() {
    _target="$1"
    [ -n "$_target" ] || return 0
    case ":$PATH:" in
        *":$_target:"*) ;;
        *) return 0 ;;
    esac
    if [ -n "${ZSH_VERSION:-}" ]; then
        path=(${path:#${_target}})
        return 0
    fi
    if [ -n "${BASH_VERSION:-}" ]; then
        _wrapped=":${PATH}:"
        while case "$_wrapped" in *":${_target}:"*) true;; *) false;; esac; do
            _wrapped="${_wrapped//:${_target}:/:}"
        done
        _wrapped="${_wrapped#:}"
        PATH="${_wrapped%:}"
        unset _wrapped
        return 0
    fi
    _rest=""
    _scan="$PATH"
    while [ -n "$_scan" ]; do
        case "$_scan" in
            *:*) _p="${_scan%%:*}"; _scan="${_scan#*:}" ;;
            *) _p="$_scan"; _scan="" ;;
        esac
        [ -n "$_p" ] || continue
        [ "$_p" = "$_target" ] && continue
        _rest="${_rest:+$_rest:}$_p"
    done
    PATH="$_rest"
    unset _rest _scan _p _target _wrapped
}

path_prepend() {
    _dir="$1"
    [ -d "$_dir" ] || return
    case ":$PATH:" in
        ":${_dir}:"*) return 0 ;;
        *":${_dir}:"*) _path_remove_segment "$_dir" ;;
        *) export PATH="$_dir${PATH:+:$PATH}"; unset _dir; return 0 ;;
    esac
    export PATH="$_dir${PATH:+:$PATH}"
    unset _dir
}

path_append() {
    _dir="$1"
    [ -d "$_dir" ] || return
    case ":$PATH:" in
        *":${_dir}:"*) ;;
        *) export PATH="${PATH:+$PATH:}$_dir"; unset _dir; return 0 ;;
    esac
    case "$PATH" in
        "$_dir"|*:"$_dir") return 0 ;;
    esac
    _path_remove_segment "$_dir"
    export PATH="${PATH:+$PATH:}$_dir"
    unset _dir
}

path_add() { path_prepend "$@"; }

unset _target _rest _scan _p _dir _wrapped 2>/dev/null || true
