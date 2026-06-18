#!/usr/bin/env sh
# ~/.config/shell/core/path-resolve.sh
# PATH contract executor + runtime verification (POSIX sh).

SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"
PATH_CONTRACT="${PATH_CONTRACT:-$SHELL_ROOT/core/path.contract}"
LOCAL_PATH_CONTRACT="${LOCAL_PATH_CONTRACT:-$SHELL_ROOT/local/path.contract}"
TOOL_CONTRACT="${TOOL_CONTRACT:-$SHELL_ROOT/core/tool.contract}"

_path_contract_env_ok() {
    _cond="$1"
    [ -z "$_cond" ] && return 0
    case "$_cond" in
        omarchy)
            resolve_shell_environment 2>/dev/null || true
            case " ${SHELL_ENVIRONMENT:-} " in
                *" omarchy "*) return 0 ;;
                *) return 1 ;;
            esac
            ;;
        *) return 0 ;;
    esac
}

path_contract_resolve_token() {
    _tok="$1"
    [ -n "$_tok" ] || return 1
    case "$_tok" in
        PNPM_HOME) printf '%s' "${PNPM_HOME:-}" ;;
        OMARCHY_PATH/bin)
            _op="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
            printf '%s/bin' "$_op"
            ;;
        HOME/bin) printf '%s/bin' "$HOME" ;;
        .local/bin) printf '%s/.local/bin' "$HOME" ;;
        mise/shims) printf '%s/.local/share/mise/shims' "$HOME" ;;
        mamba/bin) printf '%s/mamba/bin' "$HOME" ;;
        .vector/bin) printf '%s/.vector/bin' "$HOME" ;;
        .grok/bin) printf '%s/.grok/bin' "$HOME" ;;
        .risc0/bin) printf '%s/.risc0/bin' "$HOME" ;;
        .cargo/bin) printf '%s/.cargo/bin' "$HOME" ;;
        .bun/bin) printf '%s/.bun/bin' "$HOME" ;;
        .opencode/bin) printf '%s/.opencode/bin' "$HOME" ;;
        solana/install/active_release/bin)
            printf '%s/.local/share/solana/install/active_release/bin' "$HOME"
            ;;
        .vite-plus/bin) printf '%s/.vite-plus/bin' "$HOME" ;;
        miniconda/condabin) printf '%s/miniconda/condabin' "$HOME" ;;
        PWD/*)
            _root="${PATH_CONTRACT_PROJECT_ROOT:-$PWD}"
            printf '%s/%s' "$_root" "${_tok#PWD/}"
            ;;
        /*) printf '%s' "$_tok" ;;
        *) printf '%s/%s' "$HOME" "$_tok" ;;
    esac
}

path_contract_resolve_deny() {
    _tok="$1"
    case "$_tok" in
        /condabin) printf '/condabin' ;;
        .local/share/../bin) printf '%s/.local/share/../bin' "$HOME" ;;
        *)
            path_contract_resolve_token "$_tok"
            ;;
    esac
}

path_deny_sweep() {
    _path_deny_sweep_file() {
        _contract="$1"
        [ -f "$_contract" ] || return 0
        while IFS= read -r _line || [ -n "$_line" ]; do
            case "$_line" in
                \#*) continue ;;
                deny:*)
                    _pat="${_line#deny:}"
                    _dir=$(path_contract_resolve_deny "$_pat")
                    [ -n "$_dir" ] && path_drop "$_dir"
                    ;;
            esac
        done < "$_contract"
    }
    _path_deny_sweep_file "$PATH_CONTRACT"
    _path_deny_sweep_file "$LOCAL_PATH_CONTRACT"
    export PATH
    unset _contract _line _pat _dir
}

_path_contract_phase_wanted() {
    _want="$1"
    _phase="$2"
    if [ -z "$_want" ]; then
        case "$_phase" in
            post_vite|project) return 1 ;;
            *) return 0 ;;
        esac
    fi
    case ":$_want:" in
        *":$_phase:"*) return 0 ;;
        *) return 1 ;;
    esac
}

_path_contract_apply_prepend_list() {
    _list="$1"
    _rev=""
    _item=""
    for _item in $_list; do
        _rev="$_item $_rev"
    done
    for _item in $_rev; do
        [ -n "$_item" ] && path_prepend "$_item"
    done
    unset _rev _item
}

path_contract_apply_file() {
    _contract="$1"
    _phase_filter="$2"
    _skip_post_vite="$3"
    [ -f "$_contract" ] || return 0

    _phase=""
    _prepends=""
    _flush_phase() {
        [ -n "$_prepends" ] || return 0
        _path_contract_apply_prepend_list "$_prepends"
        _prepends=""
    }

    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            \#*|'') continue ;;
            deny:*) continue ;;
            phase:*)
                _flush_phase
                _phase="${_line#phase:}"
                continue
                ;;
            prepend:*)
                _rest="${_line#prepend:}"
                _tok="${_rest%%:*}"
                _cond=""
                case "$_rest" in
                    *:*) _cond="${_rest#*:}" ;;
                esac
                _path_contract_phase_wanted "$_phase_filter" "$_phase" || continue
                [ "$_phase" = post_vite ] && [ "$_skip_post_vite" -eq 1 ] && continue
                _path_contract_env_ok "$_cond" || continue
                _dir=$(path_contract_resolve_token "$_tok")
                [ -n "$_dir" ] && _prepends="$_prepends $_dir"
                ;;
            append:*)
                _flush_phase
                _rest="${_line#append:}"
                _tok="${_rest%%:*}"
                _cond=""
                case "$_rest" in
                    *:*) _cond="${_rest#*:}" ;;
                esac
                _path_contract_phase_wanted "$_phase_filter" "$_phase" || continue
                _path_contract_env_ok "$_cond" || continue
                _dir=$(path_contract_resolve_token "$_tok")
                [ -n "$_dir" ] && path_append "$_dir"
                ;;
            keep:*) ;;
        esac
    done < "$_contract"
    _flush_phase
    unset _phase _prepends _line _rest _tok _cond _dir _contract
}

path_contract_apply_project() {
    _contract="${1:-${PATH_CONTRACT_PROJECT:-$PWD/.path.contract}}"
    _root="${PATH_CONTRACT_PROJECT_ROOT:-$PWD}"
    [ -f "$_contract" ] || return 0
    PATH_CONTRACT_PROJECT_ROOT="$_root"
    export PATH_CONTRACT_PROJECT_ROOT
    path_contract_apply_file "$_contract" "project" 1
    unset _contract _root
}

path_contract_apply_core_only() {
    PATH="${PATH_CONTRACT_STRICT_BASE:-/usr/local/bin:/usr/bin:/bin}"
    export PATH
    path_deny_sweep
    path_contract_apply_file "$PATH_CONTRACT" "" 1
    path_deny_sweep
    path_dedupe
}

path_contract_apply() {
    _phase_filter=""
    _skip_post_vite=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --phase)
                shift
                _phase_filter="${_phase_filter}${_phase_filter:+:}$1"
                shift
                ;;
            --skip-post-vite) _skip_post_vite=1; shift ;;
            *) shift ;;
        esac
    done

    [ -f "$PATH_CONTRACT" ] || [ -f "$LOCAL_PATH_CONTRACT" ] || return 0

    path_contract_apply_file "$PATH_CONTRACT" "$_phase_filter" "$_skip_post_vite"
    path_contract_apply_file "$LOCAL_PATH_CONTRACT" "$_phase_filter" "$_skip_post_vite"
    unset _phase_filter _skip_post_vite
}

path_contract_reassert() {
    path_deny_sweep
    path_contract_apply --phase environment:core:append
    path_contract_apply --phase post_vite
    path_deny_sweep
    path_dedupe
    tool_contract_apply
}

_path_contract_collect_phase_prepends_file() {
    _contract="$1"
    _target_phase="$2"
    _include_post_vite="${3:-1}"
    [ -f "$_contract" ] || return 0
    _phase=""
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            phase:*)
                _phase="${_line#phase:}"
                continue
                ;;
            prepend:*)
                [ "$_phase" != "$_target_phase" ] && continue
                [ "$_phase" = post_vite ] && [ "$_include_post_vite" -eq 0 ] && continue
                _rest="${_line#prepend:}"
                _tok="${_rest%%:*}"
                _cond=""
                case "$_rest" in *:*) _cond="${_rest#*:}" ;; esac
                _path_contract_env_ok "$_cond" || continue
                _dir=$(path_contract_resolve_token "$_tok")
                [ -n "$_dir" ] && [ -d "$_dir" ] && printf '%s\n' "$_dir"
                ;;
        esac
    done < "$_contract"
    unset _contract _phase _line _rest _tok _cond _dir
}

_path_contract_collect_phase_prepends() {
    _target_phase="$1"
    _include_post_vite="${2:-1}"
    # Local overlay wins PATH priority (applied after core); list it first for verify ranks.
    _path_contract_collect_phase_prepends_file "$LOCAL_PATH_CONTRACT" "$_target_phase" "$_include_post_vite"
    _path_contract_collect_phase_prepends_file "$PATH_CONTRACT" "$_target_phase" "$_include_post_vite"
    unset _target_phase _include_post_vite
}

_path_contract_expected_prepend_order() {
    _include_post_vite="${1:-1}"
    if [ "$_include_post_vite" -eq 1 ]; then
        _path_contract_collect_phase_prepends post_vite "$_include_post_vite"
    fi
    _path_contract_collect_phase_prepends core "$_include_post_vite"
    _path_contract_collect_phase_prepends environment "$_include_post_vite"
}

path_contract_verify() {
    _json=0
    _warn_only=0
    _include_post_vite=1
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) _json=1; shift ;;
            --warn-only) _warn_only=1; shift ;;
            --env-only) _include_post_vite=0; shift ;;
            *) shift ;;
        esac
    done

    _fail=0
    _path_contract_verify_deny_file() {
        _contract="$1"
        [ -f "$_contract" ] || return 0
        while IFS= read -r _line || [ -n "$_line" ]; do
            case "$_line" in
                deny:*)
                    _pat="${_line#deny:}"
                    _dir=$(path_contract_resolve_deny "$_pat")
                    [ -n "$_dir" ] && case ":$PATH:" in
                        *":${_dir}:"*)
                            printf 'deny violation: %s in PATH\n' "$_dir" >&2
                            _fail=1
                            ;;
                    esac
                    ;;
            esac
        done < "$_contract"
    }
    _path_contract_verify_deny_file "$PATH_CONTRACT"
    _path_contract_verify_deny_file "$LOCAL_PATH_CONTRACT"
    unset _contract _line _pat _dir

    _seen=""
    _seg=""
    for _seg in $(printf '%s' "$PATH" | tr ':' ' '); do
        [ -n "$_seg" ] || continue
        case "$_seen" in
            *"|${_seg}|"*)
                printf 'duplicate segment: %s\n' "$_seg" >&2
                _fail=1
                ;;
        esac
        _seen="${_seen}|${_seg}|"
    done

    _exp_order=$(_path_contract_expected_prepend_order "$_include_post_vite")
    _prev_rank=0
    _seg=""
    for _seg in $(printf '%s' "$PATH" | tr ':' ' '); do
        [ -n "$_seg" ] || continue
        _rank=0
        _e=""
        _i=0
        for _e in $_exp_order; do
            _i=$((_i + 1))
            [ "$_e" = "$_seg" ] && _rank=$_i && break
        done
        [ "$_rank" -eq 0 ] && continue
        if [ "$_prev_rank" -gt 0 ] && [ "$_rank" -lt "$_prev_rank" ]; then
            printf 'managed order violation: %s (rank %s) before higher-priority segment\n' "$_seg" "$_rank" >&2
            _fail=1
        fi
        _prev_rank=$_rank
    done

    if [ "$_json" -eq 1 ]; then
        if [ "$_fail" -eq 0 ]; then
            printf '{"ok":true}\n'
        else
            printf '{"ok":false}\n'
        fi
    elif [ "$_fail" -ne 0 ]; then
        printf 'PATH contract verify: FAILED\n' >&2
        printf 'Expected managed order (top = highest priority):\n' >&2
        printf '%s\n' "$_exp_order" | nl -ba >&2
        printf 'Actual PATH:\n' >&2
        printf '%s\n' "$PATH" | tr ':' '\n' | nl -ba >&2
    else
        [ "$_json" -eq 0 ] && printf 'PATH contract verify: OK\n'
    fi

    if [ "$_warn_only" -eq 1 ]; then
        return 0
    fi
    return "$_fail"
}

_tool_pinned_path() {
    _c="$1"
    [ -f "$TOOL_CONTRACT" ] || return 1
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            pin:"$_c":*)
                _p="${_line#pin:}"
                _p="${_p#"${_c}":}"
                if [ -x "$_p" ]; then
                    printf '%s\n' "$_p"
                    return 0
                fi
                ;;
        esac
    done < "$TOOL_CONTRACT"
    return 1
}

tool_contract_apply() {
    [ -f "$TOOL_CONTRACT" ] || return 0
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            \#*|'') continue ;;
            pin:*)
                _rest="${_line#pin:}"
                _cmd="${_rest%%:*}"
                _bin="${_rest#*:}"
                [ -x "$_bin" ] || continue
                if [ -n "${ZSH_VERSION:-}" ] || [ -n "${BASH_VERSION:-}" ]; then
                    # shellcheck disable=SC2139
                    eval "${_cmd}() { \"${_bin}\" \"\$@\"; }"
                else
                    # shellcheck disable=SC2139
                    eval "alias ${_cmd}='${_bin}'" 2>/dev/null || true
                fi
                ;;
            warn_shadow:*) ;;
        esac
    done < "$TOOL_CONTRACT"

    if [ -n "${ZSH_VERSION:-}" ]; then
        # shellcheck disable=SC2329
        tool_contract_which() {
            _p="$(_tool_pinned_path "$1" 2>/dev/null || true)"
            if [ -n "$_p" ]; then
                printf '%s\n' "$_p"
                return 0
            fi
            whence -p "$1" 2>/dev/null && return 0
            whence -v "$1" 2>/dev/null && return 0
            command which "$@" 2>/dev/null
        }
        if ! whence which 2>/dev/null | grep -q 'function'; then
            # shellcheck disable=SC2329
            which() { tool_contract_which "$@"; }
        fi
    fi
}

path_shadow_report() {
    _warn_only=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --warn) _warn_only=1; shift ;;
            *) shift ;;
        esac
    done
    [ -f "$TOOL_CONTRACT" ] || return 0
    _found=0
    while IFS= read -r _line || [ -n "$_line" ]; do
        case "$_line" in
            warn_shadow:*)
                _cmds="${_line#warn_shadow:}"
                _cmd=""
                for _cmd in $_cmds; do
                    _pin=""
                    while IFS= read -r _pline || [ -n "$_pline" ]; do
                        case "$_pline" in
                            pin:"$_cmd":*)
                                _pin="${_pline#pin:}"
                                _pin="${_pin#"${_cmd}":}"
                                ;;
                        esac
                    done < "$TOOL_CONTRACT"
                    [ -z "$_pin" ] && continue
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        _resolved=$(whence -p "$_cmd" 2>/dev/null || true)
                    else
                        _resolved=$(command -v "$_cmd" 2>/dev/null || true)
                    fi
                    [ -z "$_resolved" ] && continue
                    [ "$_resolved" = "$_pin" ] && continue
                    printf 'shadow: %s resolves to %s (pinned: %s)\n' "$_cmd" "$_resolved" "$_pin" >&2
                    _found=1
                done
                ;;
        esac
    done < "$TOOL_CONTRACT"
    return "$_found"
}

unset _tok _dir _line _rest _cond _phase _prepends _phase_filter _skip_post_vite 2>/dev/null || true
