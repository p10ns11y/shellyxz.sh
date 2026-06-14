#!/usr/bin/env sh
# ~/.config/shell/lib.sh
# Shared safe-loading helpers for env.sh, personal.sh, and rc entrypoints.
# POSIX sh — safe to source from bash, zsh (via source), and fish (via bass).

# Omarchy layout (pin for audits; override OMARCHY_ROOT to relocate)
#   $OMARCHY_ROOT/default/bash/envs
#   $OMARCHY_ROOT/default/bash/aliases   (defines n() among other aliases)
#   $OMARCHY_ROOT/default/bash/functions (ga, gd worktree helpers)
#   $OMARCHY_ROOT/default/bash/rc        (bash monolithic bundle)
OMARCHY_ROOT="${OMARCHY_ROOT:-$HOME/.local/share/omarchy}"

# Return 0 when stdin and stdout are both ttys (interactive session).
_is_interactive_session() {
    [ -t 0 ] && [ -t 1 ]
}

# Sets SHELL_IN_EDITOR_TERMINAL to yes|no (Cursor/VS Code integrated terminal vs native).
# Call detect_editor_terminal, then test the variable — avoids shell exit-code confusion.
detect_editor_terminal() {
    export SHELL_IN_EDITOR_TERMINAL=no
    case "${TERM_PROGRAM:-}" in
        vscode|cursor|Cursor) export SHELL_IN_EDITOR_TERMINAL=yes; return ;;
    esac
    if [ -n "${VSCODE_IPC_HOOK:-}" ]; then export SHELL_IN_EDITOR_TERMINAL=yes; return; fi
    if [ -n "${VSCODE_CWD:-}" ]; then export SHELL_IN_EDITOR_TERMINAL=yes; return; fi
    if [ -n "${CURSOR_AGENT:-}" ]; then export SHELL_IN_EDITOR_TERMINAL=yes; return; fi
    if [ -n "${VSCODE_PID:-}" ]; then export SHELL_IN_EDITOR_TERMINAL=yes; return; fi
    case "${CHROME_DESKTOP:-}" in
        *cursor*|*code*) export SHELL_IN_EDITOR_TERMINAL=yes; return ;;
    esac
    case "${APPIMAGE:-}" in
        *cursor*|*Cursor*|*code*) export SHELL_IN_EDITOR_TERMINAL=yes; return ;;
    esac
}

# Regular file owned by us (or root), not world-writable, not a symlink.
_file_is_safe_to_source() {
    _f="$1"
    [ -n "$_f" ] && [ -f "$_f" ] || return 1
    [ -L "$_f" ] && return 1
    _uid=$(stat -c '%u' "$_f" 2>/dev/null) || return 1
    _me=$(id -u 2>/dev/null) || return 1
    [ "$_uid" = "$_me" ] || [ "$_uid" = 0 ] || return 1
    _perm=$(stat -c '%a' "$_f" 2>/dev/null) || return 1
    case $((_perm % 10)) in
        2|3|6|7) return 1 ;;  # other-writable
    esac
    return 0
}

# Source a dotfile only when ownership/permission checks pass.
source_if_safe() {
    _f="$1"
    if _file_is_safe_to_source "$_f"; then
        # shellcheck disable=SC1090
        . "$_f"
        return 0
    fi
    return 1
}

# Print path to an Omarchy bash module (envs, aliases, functions, rc) or return 1.
omarchy_file() {
    _part="$1"
    _path="$OMARCHY_ROOT/default/bash/$_part"
    if [ -f "$_path" ]; then
        printf '%s\n' "$_path"
        return 0
    fi
    if [ "${OMARCHY_WARN:-0}" = 1 ]; then
        printf 'lib.sh: missing Omarchy module: %s\n' "$_path" >&2
    fi
    return 1
}

# Source an Omarchy module when present; no-op when Omarchy is absent.
source_omarchy() {
    _part="$1"
    _path=$(omarchy_file "$_part") || return 1
    # shellcheck disable=SC1090
    . "$_path"
}

# Load KEY=value secrets without set -a (validates names; skips comments/blanks).
# Intended for ~/.config/secrets/dev.env — keep that file mode 600.
load_secrets_file() {
    _file="$1"
    _file_is_safe_to_source "$_file" || return 1
    _line _key _val
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            ''|'#'*) continue ;;
            export\ *) _line="${_line#export }" ;;
        esac
        _key="${_line%%=*}"
        _val="${_line#*=}"
        case "$_key" in
            *[!A-Za-z0-9_]*|""|[0-9]*) continue ;;
        esac
        case "$_val" in
            \"*\") _val="${_val#\"}"; _val="${_val%\"}" ;;
            \'*\') _val="${_val#\'}"; _val="${_val%\'}" ;;
        esac
        export "$_key=$_val"
    done < "$_file"
}

# Set SHELL to the running interpreter when SHELL_TRUTH_SEEKER=1 (default).
# Downside: overwrites inherited $SHELL; scripts that expect passwd default may disagree.
# Disable: SHELL_TRUTH_SEEKER=0 before sourcing env.sh
shell_truth_seeker() {
    [ "${SHELL_TRUTH_SEEKER:-1}" = 1 ] || return 0
    if [ -n "${ZSH_VERSION+set}" ]; then
        _shell_bin=$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)
        [ -x "$_shell_bin" ] && export SHELL="$_shell_bin"
    elif [ -n "${BASH_VERSION+set}" ]; then
        _shell_bin=$(command -v bash 2>/dev/null || echo /usr/bin/bash)
        [ -x "$_shell_bin" ] && export SHELL="$_shell_bin"
    fi
    unset _shell_bin
}

unset _f _uid _me _perm _part _path _line _key _val _shell_bin 2>/dev/null || true
