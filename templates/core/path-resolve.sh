#!/usr/bin/env sh
# ~/.config/shell/core/path-resolve.sh
# PATH contract executor + runtime verification (POSIX sh).
#
# Vocabulary: path_token, contract_line, phase_name, environment_gate,
# deny_pattern, resolved_directory, pending_prepend_dirs, path_segment,
# expected_prepend_order, contract_file_path

SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"
PATH_CONTRACT="${PATH_CONTRACT:-$SHELL_ROOT/core/path.contract}"
LOCAL_PATH_CONTRACT="${LOCAL_PATH_CONTRACT:-$SHELL_ROOT/local/path.contract}"
TOOL_CONTRACT="${TOOL_CONTRACT:-$SHELL_ROOT/core/tool.contract}"

path_contract_environment_gate_passes() {
    environment_gate="$1"
    [ -z "$environment_gate" ] && return 0
    case "$environment_gate" in
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
    path_token="$1"
    [ -n "$path_token" ] || return 1
    case "$path_token" in
        PNPM_HOME) printf '%s' "${PNPM_HOME:-}" ;;
        OMARCHY_PATH/bin)
            omarchy_root="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
            printf '%s/bin' "$omarchy_root"
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
            project_root="${PATH_CONTRACT_PROJECT_ROOT:-$PWD}"
            printf '%s/%s' "$project_root" "${path_token#PWD/}"
            ;;
        /*) printf '%s' "$path_token" ;;
        *) printf '%s/%s' "$HOME" "$path_token" ;;
    esac
}

path_contract_resolve_deny() {
    path_token="$1"
    case "$path_token" in
        /condabin) printf '/condabin' ;;
        .local/share/../bin) printf '%s/.local/share/../bin' "$HOME" ;;
        *)
            path_contract_resolve_token "$path_token"
            ;;
    esac
}

path_deny_sweep() {
    _path_deny_sweep_contract_file() {
        contract_file_path="$1"
        [ -f "$contract_file_path" ] || return 0
        while IFS= read -r contract_line || [ -n "$contract_line" ]; do
            case "$contract_line" in
                \#*) continue ;;
                deny:*)
                    deny_pattern="${contract_line#deny:}"
                    resolved_directory=$(path_contract_resolve_deny "$deny_pattern")
                    [ -n "$resolved_directory" ] && path_drop "$resolved_directory"
                    ;;
            esac
        done < "$contract_file_path"
    }
    _path_deny_sweep_contract_file "$PATH_CONTRACT"
    _path_deny_sweep_contract_file "$LOCAL_PATH_CONTRACT"
    export PATH
    unset contract_file_path contract_line deny_pattern resolved_directory
}

path_contract_phase_matches_filter() {
    phase_filter="$1"
    phase_name="$2"
    if [ -z "$phase_filter" ]; then
        case "$phase_name" in
            post_vite|project) return 1 ;;
            *) return 0 ;;
        esac
    fi
    case ":$phase_filter:" in
        *":$phase_name:"*) return 0 ;;
        *) return 1 ;;
    esac
}

_path_contract_apply_prepend_list() {
    prepend_directory_list="$1"
    reversed_directories=""
    directory_entry=""
    remaining_words="$prepend_directory_list"
    while [ -n "$remaining_words" ]; do
        case "$remaining_words" in
            *" "*) directory_entry="${remaining_words%% *}"; remaining_words="${remaining_words#"$directory_entry"}"; remaining_words="${remaining_words# }" ;;
            *) directory_entry="$remaining_words"; remaining_words="" ;;
        esac
        [ -n "$directory_entry" ] && reversed_directories="$directory_entry $reversed_directories"
    done
    remaining_words="$reversed_directories"
    while [ -n "$remaining_words" ]; do
        case "$remaining_words" in
            *" "*) directory_entry="${remaining_words%% *}"; remaining_words="${remaining_words#"$directory_entry"}"; remaining_words="${remaining_words# }" ;;
            *) directory_entry="$remaining_words"; remaining_words="" ;;
        esac
        [ -n "$directory_entry" ] && path_prepend "$directory_entry"
    done
    unset reversed_directories directory_entry remaining_words prepend_directory_list
}

path_contract_apply_file() {
    contract_file_path="$1"
    phase_filter="$2"
    skip_post_vite="$3"
    [ -f "$contract_file_path" ] || return 0

    phase_name=""
    pending_prepend_dirs=""
    _flush_pending_prepends() {
        [ -n "$pending_prepend_dirs" ] || return 0
        _path_contract_apply_prepend_list "$pending_prepend_dirs"
        pending_prepend_dirs=""
    }

    while IFS= read -r contract_line || [ -n "$contract_line" ]; do
        case "$contract_line" in
            \#*|'') continue ;;
            deny:*) continue ;;
            phase:*)
                _flush_pending_prepends
                phase_name="${contract_line#phase:}"
                continue
                ;;
            prepend:*)
                line_rest="${contract_line#prepend:}"
                path_token="${line_rest%%:*}"
                environment_gate=""
                case "$line_rest" in
                    *:*) environment_gate="${line_rest#*:}" ;;
                esac
                path_contract_phase_matches_filter "$phase_filter" "$phase_name" || continue
                [ "$phase_name" = post_vite ] && [ "$skip_post_vite" -eq 1 ] && continue
                path_contract_environment_gate_passes "$environment_gate" || continue
                resolved_directory=$(path_contract_resolve_token "$path_token")
                [ -n "$resolved_directory" ] && pending_prepend_dirs="$pending_prepend_dirs $resolved_directory"
                ;;
            append:*)
                _flush_pending_prepends
                line_rest="${contract_line#append:}"
                path_token="${line_rest%%:*}"
                environment_gate=""
                case "$line_rest" in
                    *:*) environment_gate="${line_rest#*:}" ;;
                esac
                path_contract_phase_matches_filter "$phase_filter" "$phase_name" || continue
                path_contract_environment_gate_passes "$environment_gate" || continue
                resolved_directory=$(path_contract_resolve_token "$path_token")
                [ -n "$resolved_directory" ] && path_append "$resolved_directory"
                ;;
            keep:*) ;;
        esac
    done < "$contract_file_path"
    _flush_pending_prepends
    unset phase_name pending_prepend_dirs contract_line line_rest path_token environment_gate resolved_directory contract_file_path
}

path_contract_apply_project() {
    contract_file_path="${1:-${PATH_CONTRACT_PROJECT:-$PWD/.path.contract}}"
    project_root="${PATH_CONTRACT_PROJECT_ROOT:-$PWD}"
    [ -f "$contract_file_path" ] || return 0
    PATH_CONTRACT_PROJECT_ROOT="$project_root"
    export PATH_CONTRACT_PROJECT_ROOT
    path_contract_apply_file "$contract_file_path" "project" 1
    unset contract_file_path project_root
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
    phase_filter=""
    skip_post_vite=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --phase)
                shift
                phase_filter="${phase_filter}${phase_filter:+:}$1"
                shift
                ;;
            --skip-post-vite) skip_post_vite=1; shift ;;
            *) shift ;;
        esac
    done

    [ -f "$PATH_CONTRACT" ] || [ -f "$LOCAL_PATH_CONTRACT" ] || return 0

    path_contract_apply_file "$PATH_CONTRACT" "$phase_filter" "$skip_post_vite"
    path_contract_apply_file "$LOCAL_PATH_CONTRACT" "$phase_filter" "$skip_post_vite"
    unset phase_filter skip_post_vite
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
    contract_file_path="$1"
    target_phase_name="$2"
    include_post_vite="${3:-1}"
    [ -f "$contract_file_path" ] || return 0
    phase_name=""
    while IFS= read -r contract_line || [ -n "$contract_line" ]; do
        case "$contract_line" in
            phase:*)
                phase_name="${contract_line#phase:}"
                continue
                ;;
            prepend:*)
                [ "$phase_name" != "$target_phase_name" ] && continue
                [ "$phase_name" = post_vite ] && [ "$include_post_vite" -eq 0 ] && continue
                line_rest="${contract_line#prepend:}"
                path_token="${line_rest%%:*}"
                environment_gate=""
                case "$line_rest" in *:*) environment_gate="${line_rest#*:}" ;; esac
                path_contract_environment_gate_passes "$environment_gate" || continue
                resolved_directory=$(path_contract_resolve_token "$path_token")
                [ -n "$resolved_directory" ] && [ -d "$resolved_directory" ] && printf '%s\n' "$resolved_directory"
                ;;
        esac
    done < "$contract_file_path"
    unset contract_file_path phase_name contract_line line_rest path_token environment_gate resolved_directory
}

_path_contract_collect_phase_prepends() {
    target_phase_name="$1"
    include_post_vite="${2:-1}"
    # Local overlay wins PATH priority (applied after core); list it first for verify ranks.
    _path_contract_collect_phase_prepends_file "$LOCAL_PATH_CONTRACT" "$target_phase_name" "$include_post_vite"
    _path_contract_collect_phase_prepends_file "$PATH_CONTRACT" "$target_phase_name" "$include_post_vite"
    unset target_phase_name include_post_vite
}

_path_contract_expected_prepend_order() {
    include_post_vite="${1:-1}"
    if [ "$include_post_vite" -eq 1 ]; then
        _path_contract_collect_phase_prepends post_vite "$include_post_vite"
    fi
    _path_contract_collect_phase_prepends core "$include_post_vite"
    _path_contract_collect_phase_prepends environment "$include_post_vite"
}

path_contract_verify() {
    emit_json=0
    warn_only_mode=0
    include_post_vite=1
    while [ $# -gt 0 ]; do
        case "$1" in
            --json) emit_json=1; shift ;;
            --warn-only) warn_only_mode=1; shift ;;
            --env-only) include_post_vite=0; shift ;;
            *) shift ;;
        esac
    done

    verify_failed=0
    _path_contract_verify_deny_file() {
        contract_file_path="$1"
        [ -f "$contract_file_path" ] || return 0
        while IFS= read -r contract_line || [ -n "$contract_line" ]; do
            case "$contract_line" in
                deny:*)
                    deny_pattern="${contract_line#deny:}"
                    resolved_directory=$(path_contract_resolve_deny "$deny_pattern")
                    [ -n "$resolved_directory" ] && case ":$PATH:" in
                        *":${resolved_directory}:"*)
                            printf 'deny violation: %s in PATH\n' "$resolved_directory" >&2
                            verify_failed=1
                            ;;
                    esac
                    ;;
            esac
        done < "$contract_file_path"
    }
    _path_contract_verify_deny_file "$PATH_CONTRACT"
    _path_contract_verify_deny_file "$LOCAL_PATH_CONTRACT"
    unset contract_file_path contract_line deny_pattern resolved_directory

    seen_path_segments=""
    path_segment=""
    for path_segment in $(printf '%s' "$PATH" | tr ':' ' '); do
        [ -n "$path_segment" ] || continue
        case "$seen_path_segments" in
            *"|${path_segment}|"*)
                printf 'duplicate segment: %s\n' "$path_segment" >&2
                verify_failed=1
                ;;
        esac
        seen_path_segments="${seen_path_segments}|${path_segment}|"
    done

    expected_prepend_order=$(_path_contract_expected_prepend_order "$include_post_vite")
    expected_directory=""
    while IFS= read -r expected_directory || [ -n "$expected_directory" ]; do
        [ -n "$expected_directory" ] || continue
        case ":$PATH:" in
            *":${expected_directory}:"*) ;;
            *)
                printf 'missing managed segment: %s\n' "$expected_directory" >&2
                verify_failed=1
                ;;
        esac
    done <<EOF
$expected_prepend_order
EOF

    previous_rank=0
    path_segment=""
    for path_segment in $(printf '%s' "$PATH" | tr ':' ' '); do
        [ -n "$path_segment" ] || continue
        path_segment_rank=0
        expected_directory=""
        rank_index=0
        while IFS= read -r expected_directory || [ -n "$expected_directory" ]; do
            [ -n "$expected_directory" ] || continue
            rank_index=$((rank_index + 1))
            [ "$expected_directory" = "$path_segment" ] && path_segment_rank=$rank_index && break
        done <<EOF
$expected_prepend_order
EOF
        [ "$path_segment_rank" -eq 0 ] && continue
        if [ "$previous_rank" -gt 0 ] && [ "$path_segment_rank" -lt "$previous_rank" ]; then
            printf 'managed order violation: %s (rank %s) before higher-priority segment\n' "$path_segment" "$path_segment_rank" >&2
            verify_failed=1
        fi
        previous_rank=$path_segment_rank
    done

    if [ "$emit_json" -eq 1 ]; then
        if [ "$verify_failed" -eq 0 ]; then
            printf '{"ok":true}\n'
        else
            printf '{"ok":false}\n'
        fi
    elif [ "$verify_failed" -ne 0 ]; then
        printf 'PATH contract verify: FAILED\n' >&2
        printf 'Expected managed order (top = highest priority):\n' >&2
        printf '%s\n' "$expected_prepend_order" | nl -ba >&2
        printf 'Actual PATH:\n' >&2
        printf '%s\n' "$PATH" | tr ':' '\n' | nl -ba >&2
    else
        [ "$emit_json" -eq 0 ] && printf 'PATH contract verify: OK\n'
    fi

    if [ "$warn_only_mode" -eq 1 ]; then
        return 0
    fi
    return "$verify_failed"
}

_tool_pinned_path() {
    command_name="$1"
    [ -f "$TOOL_CONTRACT" ] || return 1
    while IFS= read -r contract_line || [ -n "$contract_line" ]; do
        case "$contract_line" in
            pin:"$command_name":*)
                pin_line_rest="${contract_line#pin:}"
                pin_line_rest="${pin_line_rest#"$command_name":}"
                if [ -x "$pin_line_rest" ]; then
                    printf '%s\n' "$pin_line_rest"
                    return 0
                fi
                ;;
        esac
    done < "$TOOL_CONTRACT"
    return 1
}

tool_contract_apply() {
    [ -f "$TOOL_CONTRACT" ] || return 0
    while IFS= read -r contract_line || [ -n "$contract_line" ]; do
        case "$contract_line" in
            \#*|'') continue ;;
            pin:*)
                pin_line_rest="${contract_line#pin:}"
                command_name="${pin_line_rest%%:*}"
                pinned_binary_path="${pin_line_rest#*:}"
                [ -x "$pinned_binary_path" ] || continue
                if [ -n "${ZSH_VERSION:-}" ] || [ -n "${BASH_VERSION:-}" ]; then
                    # shellcheck disable=SC2139
                    eval "${command_name}() { \"${pinned_binary_path}\" \"\$@\"; }"
                else
                    # shellcheck disable=SC2139
                    eval "alias ${command_name}='${pinned_binary_path}'" 2>/dev/null || true
                fi
                ;;
            warn_shadow:*) ;;
        esac
    done < "$TOOL_CONTRACT"

    if [ -n "${ZSH_VERSION:-}" ]; then
        # shellcheck disable=SC2329
        tool_contract_which() {
            pinned_binary_path="$(_tool_pinned_path "$1" 2>/dev/null || true)"
            if [ -n "$pinned_binary_path" ]; then
                printf '%s\n' "$pinned_binary_path"
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
    warn_only_mode=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --warn) warn_only_mode=1; shift ;;
            *) shift ;;
        esac
    done
    [ -f "$TOOL_CONTRACT" ] || return 0
    shadow_found=0
    while IFS= read -r contract_line || [ -n "$contract_line" ]; do
        case "$contract_line" in
            warn_shadow:*)
                shadow_command_list="${contract_line#warn_shadow:}"
                shadow_command=""
                for shadow_command in $shadow_command_list; do
                    pinned_binary_path=""
                    while IFS= read -r tool_contract_line || [ -n "$tool_contract_line" ]; do
                        case "$tool_contract_line" in
                            pin:"$shadow_command":*)
                                pinned_binary_path="${tool_contract_line#pin:}"
                                pinned_binary_path="${pinned_binary_path#"$shadow_command":}"
                                ;;
                        esac
                    done < "$TOOL_CONTRACT"
                    [ -z "$pinned_binary_path" ] && continue
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        resolved_binary_path=$(whence -p "$shadow_command" 2>/dev/null || true)
                    else
                        resolved_binary_path=$(command -v "$shadow_command" 2>/dev/null || true)
                    fi
                    [ -z "$resolved_binary_path" ] && continue
                    [ "$resolved_binary_path" = "$pinned_binary_path" ] && continue
                    printf 'shadow: %s resolves to %s (pinned: %s)\n' "$shadow_command" "$resolved_binary_path" "$pinned_binary_path" >&2
                    shadow_found=1
                done
                ;;
        esac
    done < "$TOOL_CONTRACT"
    return "$shadow_found"
}

unset path_token resolved_directory contract_line line_rest environment_gate phase_name pending_prepend_dirs phase_filter skip_post_vite 2>/dev/null || true
