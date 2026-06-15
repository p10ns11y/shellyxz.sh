#!/usr/bin/env sh
# ~/.config/shell/core/path.sh — PATH helpers (POSIX sh).

path_prepend() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
    esac
}

path_append() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$PATH:$1" ;;
    esac
}

path_add() { path_prepend "$@"; }

_path_dedupe_key() {
    _p="$1"
    if command -v realpath >/dev/null 2>&1; then
        _k=$(realpath -m "$_p" 2>/dev/null) || _k=""
        if [ -n "$_k" ]; then
            printf '%s' "$_k"
            return
        fi
    fi
    printf '%s' "$_p"
}

# Move dir to front even when already on PATH (path_prepend skips existing entries).
path_promote() {
    _dir="$1"
    [ -d "$_dir" ] || return
    _rest=""
    _scan="$PATH"
    while [ -n "$_scan" ]; do
        case "$_scan" in
            *:*) _p="${_scan%%:*}"; _scan="${_scan#*:}" ;;
            *) _p="$_scan"; _scan="" ;;
        esac
        [ -n "$_p" ] || continue
        [ "$_p" = "$_dir" ] && continue
        if [ -z "$_rest" ]; then
            _rest="$_p"
        else
            _rest="$_rest:$_p"
        fi
    done
    export PATH="$_dir${_rest:+:$_rest}"
    unset _dir _rest _scan _p
}

# Drop duplicate PATH segments (first occurrence wins for `which`).
# Manual ':' split — `set -- $PATH` breaks under zsh (PATH is special).
path_dedupe() {
    _deduped=""
    _seen=":"
    _scan="$PATH"
    while [ -n "$_scan" ]; do
        case "$_scan" in
            *:*) _p="${_scan%%:*}"; _scan="${_scan#*:}" ;;
            *) _p="$_scan"; _scan="" ;;
        esac
        [ -n "$_p" ] || continue
        _key=$(_path_dedupe_key "$_p")
        [ -n "$_key" ] || continue
        case "$_seen" in
            *:"$_key":*) continue ;;
        esac
        _seen="$_seen$_key:"
        if [ -z "$_deduped" ]; then
            _deduped="$_p"
        else
            _deduped="$_deduped:$_p"
        fi
    done
    [ -n "$_deduped" ] && export PATH="$_deduped"
    unset _deduped _seen _scan _p _key
}

# Collapse known aliases and drop broken segments so dedupe can work.
path_normalize() {
    _local_bin="$HOME/.local/bin"
    _local_alias="$HOME/.local/share/../bin"
    case ":$PATH:" in
        *":$_local_alias:"*)
            PATH=$(printf '%s' "$PATH" | sed "s|$_local_alias|$_local_bin|g")
            export PATH
            ;;
    esac
    case ":$PATH:" in
        *:/condabin:*)
            PATH=$(printf '%s' "$PATH" | sed 's|:/condabin||g;s|^/condabin:||;s|^/condabin$||')
            export PATH
            ;;
    esac
    unset _local_bin _local_alias
}

# Call after env.sh and again at end of rc (mise/mamba/vite+ may re-duplicate PATH).
path_finalize() {
    path_normalize
    path_promote "$HOME/bin"
    path_dedupe
}

unset _dir _rest _scan _p _deduped _seen _local_bin _local_alias _key 2>/dev/null || true
