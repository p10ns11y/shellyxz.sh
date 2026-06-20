#!/usr/bin/env sh
# ~/.config/shell/core/path.sh — PATH helpers (POSIX sh).
# path_prepend / path_append are O(1) when the dir is absent or already positioned.
#
# Vocabulary: target_directory, path_segment, seen_path_segments, deduped_path

_path_remove_segment() {
    target_directory="$1"
    [ -n "$target_directory" ] || return 0
    case ":$PATH:" in
        *":$target_directory:"*) ;;
        *) return 0 ;;
    esac
    if [ -n "${ZSH_VERSION:-}" ]; then
        # zsh path array — faster than manual scan (not POSIX; guarded)
        # shellcheck disable=SC3030,SC2206,SC3057
        path=(${path:#${target_directory}})
        return 0
    fi
    if [ -n "${BASH_VERSION:-}" ]; then
        wrapped_path=":${PATH}:"
        while case "$wrapped_path" in *":${target_directory}:"*) true;; *) false;; esac; do
            # shellcheck disable=SC3060
            wrapped_path="${wrapped_path//:${target_directory}:/:}"
        done
        wrapped_path="${wrapped_path#:}"
        PATH="${wrapped_path%:}"
        unset wrapped_path
        return 0
    fi
    deduped_path=""
    path_segment_scan="$PATH"
    while [ -n "$path_segment_scan" ]; do
        case "$path_segment_scan" in
            *:*) current_segment="${path_segment_scan%%:*}"; path_segment_scan="${path_segment_scan#*:}" ;;
            *) current_segment="$path_segment_scan"; path_segment_scan="" ;;
        esac
        [ -n "$current_segment" ] || continue
        [ "$current_segment" = "$target_directory" ] && continue
        deduped_path="${deduped_path:+${deduped_path}:}$current_segment"
    done
    PATH="$deduped_path"
    unset deduped_path path_segment_scan current_segment target_directory wrapped_path
}

path_prepend() {
    prepend_directory="$1"
    [ -d "$prepend_directory" ] || return
    case ":$PATH:" in
        ":${prepend_directory}:"*) return 0 ;;
        *":${prepend_directory}:"*) _path_remove_segment "$prepend_directory" ;;
        *) export PATH="$prepend_directory${PATH:+:$PATH}"; unset prepend_directory; return 0 ;;
    esac
    export PATH="$prepend_directory${PATH:+:$PATH}"
    unset prepend_directory
}

path_append() {
    append_directory="$1"
    [ -d "$append_directory" ] || return
    case ":$PATH:" in
        *":${append_directory}:"*) ;;
        *) export PATH="${PATH:+$PATH:}$append_directory"; unset append_directory; return 0 ;;
    esac
    case "$PATH" in
        "$append_directory"|*:"$append_directory") return 0 ;;
    esac
    _path_remove_segment "$append_directory"
    export PATH="${PATH:+$PATH:}$append_directory"
    unset append_directory
}

path_add() { path_prepend "$@"; }

# shellcheck disable=SC1091
. "${SHELL_ROOT:-$HOME/.config/shell}/core/path-resolve.sh"

# Remove a segment from PATH (exact match). Used to drop inherited junk before building.
path_drop() {
    _path_remove_segment "$1"
    export PATH
    unset target_directory
}

# Collapse duplicate segments (keep first = highest priority).
path_dedupe() {
    deduped_path=""
    seen_path_segments=""
    path_segment=""
    for path_segment in $(printf '%s' "$PATH" | tr ':' ' '); do
        [ -n "$path_segment" ] || continue
        case "$seen_path_segments" in
            *"|${path_segment}|"*) continue ;;
        esac
        seen_path_segments="${seen_path_segments}|${path_segment}|"
        deduped_path="${deduped_path:+${deduped_path}:}$path_segment"
    done
    PATH="$deduped_path"
    export PATH
    unset deduped_path seen_path_segments path_segment
}

unset target_directory deduped_path path_segment_scan current_segment prepend_directory append_directory wrapped_path 2>/dev/null || true
