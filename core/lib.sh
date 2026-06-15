#!/usr/bin/env sh
# ~/.config/shell/core/lib.sh
# Shared safe-loading helpers — distro-agnostic core.

SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"

OMARCHY_ROOT="${OMARCHY_ROOT:-$HOME/.local/share/omarchy}"

_is_interactive_session() {
    [ -t 0 ] && [ -t 1 ]
}

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

_file_is_safe_to_source() {
    _f="$1"
    [ -n "$_f" ] && [ -f "$_f" ] || return 1
    [ -L "$_f" ] && return 1
    _uid=$(stat -c '%u' "$_f" 2>/dev/null) || return 1
    _me=$(id -u 2>/dev/null) || return 1
    [ "$_uid" = "$_me" ] || [ "$_uid" = 0 ] || return 1
    _perm=$(stat -c '%a' "$_f" 2>/dev/null) || return 1
    case $((_perm % 10)) in
        2|3|6|7) return 1 ;;
    esac
    return 0
}

source_if_safe() {
    _f="$1"
    if _file_is_safe_to_source "$_f"; then
        # shellcheck disable=SC1090
        . "$_f"
        return 0
    fi
    return 1
}

# Resolve SHELL_ENVIRONMENT: env var → environment file → auto-detect.
# Does NOT read ~/.profile (POSIX login) — use ~/.config/shell/environment only.
resolve_shell_environment() {
    if [ -n "${SHELL_ENVIRONMENT:-}" ]; then
        export SHELL_ENVIRONMENT
        return 0
    fi
    if [ -f "$SHELL_ROOT/environment" ]; then
        # shellcheck disable=SC1091
        . "$SHELL_ROOT/environment"
    fi
    if [ -z "${SHELL_ENVIRONMENT:-}" ]; then
        if [ -d "$HOME/.local/share/omarchy" ]; then
            SHELL_ENVIRONMENT=omarchy
        else
            SHELL_ENVIRONMENT=generic
        fi
    fi
    export SHELL_ENVIRONMENT
}

source_environments() {
    resolve_shell_environment
    for _shell_env in $SHELL_ENVIRONMENT; do
        _ef="$SHELL_ROOT/environments/$_shell_env/env.sh"
        if [ -f "$_ef" ]; then
            # shellcheck disable=SC1090
            . "$_ef"
        elif [ "${SHELL_ENVIRONMENT_WARN:-0}" = 1 ]; then
            printf 'lib.sh: missing environment: %s\n' "$_ef" >&2
        fi
    done
    unset _shell_env _ef
}

source_environment_shell() {
    _shell_part="$1"
    resolve_shell_environment
    for _shell_env in $SHELL_ENVIRONMENT; do
        _ef="$SHELL_ROOT/environments/$_shell_env/${_shell_part}.sh"
        if [ -f "$_ef" ]; then
            # shellcheck disable=SC1090
            . "$_ef"
        fi
    done
    unset _shell_part _shell_env _ef
}

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

source_omarchy() {
    _part="$1"
    _path=$(omarchy_file "$_part") || return 1
    # shellcheck disable=SC1090
    . "$_path"
}

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

unset _f _uid _me _perm _part _path _line _key _val _shell_bin _shell_part _shell_env _ef 2>/dev/null || true
