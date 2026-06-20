#!/usr/bin/env sh
# ~/.config/shell/core/lib.sh
# Shared safe-loading helpers — distro-agnostic core.
#
# Vocabulary: source_candidate_path, file_owner_uid, environment_preset_name,
# environment_script_path, omarchy_module_path, secrets_line, secret_key

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
    source_candidate_path="$1"
    [ -n "$source_candidate_path" ] && [ -f "$source_candidate_path" ] || return 1
    [ -L "$source_candidate_path" ] && return 1
    file_owner_uid=$(stat -c '%u' "$source_candidate_path" 2>/dev/null) || return 1
    current_user_uid=$(id -u 2>/dev/null) || return 1
    [ "$file_owner_uid" = "$current_user_uid" ] || [ "$file_owner_uid" = 0 ] || return 1
    file_mode_octal=$(stat -c '%a' "$source_candidate_path" 2>/dev/null) || return 1
    case $((file_mode_octal % 10)) in
        2|3|6|7) return 1 ;;
    esac
    return 0
}

source_if_safe() {
    source_candidate_path="$1"
    if _file_is_safe_to_source "$source_candidate_path"; then
        # shellcheck disable=SC1090
        . "$source_candidate_path"
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
    for environment_preset_name in $SHELL_ENVIRONMENT; do
        environment_script_path="$SHELL_ROOT/environments/$environment_preset_name/env.sh"
        if [ -f "$environment_script_path" ]; then
            # shellcheck disable=SC1090
            . "$environment_script_path"
        elif [ "${SHELL_ENVIRONMENT_WARN:-0}" = 1 ]; then
            printf 'lib.sh: missing environment: %s\n' "$environment_script_path" >&2
        fi
    done
    unset environment_preset_name environment_script_path
}

source_environment_shell() {
    shell_module_name="$1"
    resolve_shell_environment
    for environment_preset_name in $SHELL_ENVIRONMENT; do
        environment_script_path="$SHELL_ROOT/environments/$environment_preset_name/${shell_module_name}.sh"
        if [ -f "$environment_script_path" ]; then
            # shellcheck disable=SC1090
            . "$environment_script_path"
        fi
    done
    unset shell_module_name environment_preset_name environment_script_path
}

omarchy_file() {
    omarchy_module_name="$1"
    omarchy_module_path="$OMARCHY_ROOT/default/bash/$omarchy_module_name"
    if [ -f "$omarchy_module_path" ]; then
        printf '%s\n' "$omarchy_module_path"
        return 0
    fi
    if [ "${OMARCHY_WARN:-0}" = 1 ]; then
        printf 'lib.sh: missing Omarchy module: %s\n' "$omarchy_module_path" >&2
    fi
    return 1
}

source_omarchy() {
    omarchy_module_name="$1"
    omarchy_module_path=$(omarchy_file "$omarchy_module_name") || return 1
    # shellcheck disable=SC1090
    . "$omarchy_module_path"
}

load_secrets_file() {
    secrets_file_path="$1"
    _file_is_safe_to_source "$secrets_file_path" || return 1
    secrets_line secret_key secret_value
    while IFS= read -r secrets_line || [ -n "$secrets_line" ]; do
        case "$secrets_line" in
            ''|'#'*) continue ;;
            export\ *) secrets_line="${secrets_line#export }" ;;
        esac
        secret_key="${secrets_line%%=*}"
        secret_value="${secrets_line#*=}"
        case "$secret_key" in
            *[!A-Za-z0-9_]*|""|[0-9]*) continue ;;
        esac
        case "$secret_value" in
            \"*\") secret_value="${secret_value#\"}"; secret_value="${secret_value%\"}" ;;
            \'*\') secret_value="${secret_value#\'}"; secret_value="${secret_value%\'}" ;;
        esac
        export "$secret_key=$secret_value"
    done < "$secrets_file_path"
}

shell_truth_seeker() {
    [ "${SHELL_TRUTH_SEEKER:-1}" = 1 ] || return 0
    if [ -n "${ZSH_VERSION+set}" ]; then
        resolved_shell_binary=$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)
        [ -x "$resolved_shell_binary" ] && export SHELL="$resolved_shell_binary"
    elif [ -n "${BASH_VERSION+set}" ]; then
        resolved_shell_binary=$(command -v bash 2>/dev/null || echo /usr/bin/bash)
        [ -x "$resolved_shell_binary" ] && export SHELL="$resolved_shell_binary"
    fi
    unset resolved_shell_binary
}

unset source_candidate_path file_owner_uid current_user_uid file_mode_octal omarchy_module_name omarchy_module_path secrets_file_path secrets_line secret_key secret_value environment_preset_name environment_script_path shell_module_name 2>/dev/null || true
