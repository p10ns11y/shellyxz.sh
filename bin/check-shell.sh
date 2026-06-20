#!/usr/bin/env bash
# Verify shell load order and reserved-name guardrails.
# Usage: check-shell.sh [--audit] [--shellcheck-only]
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
AUDIT=false
SHELLCHECK_ONLY=false
ENV_FILE="$CONFIG_DIR/core/env.sh"
[[ -f "$ENV_FILE" ]] || ENV_FILE="$CONFIG_DIR/env.sh"
FUNCS_FILE="$CONFIG_DIR/core/functions.sh"
[[ -f "$FUNCS_FILE" ]] || FUNCS_FILE="$CONFIG_DIR/functions.sh"
ALIASES_FILE="$CONFIG_DIR/core/aliases.sh"
[[ -f "$ALIASES_FILE" ]] || ALIASES_FILE="$CONFIG_DIR/aliases.sh"
LIB_FILE="$CONFIG_DIR/core/lib.sh"
[[ -f "$LIB_FILE" ]] || LIB_FILE="$CONFIG_DIR/lib.sh"
for arg in "$@"; do
    case "$arg" in
        --audit) AUDIT=true ;;
        --shellcheck-only) SHELLCHECK_ONLY=true ;;
        -h|--help)
            echo "Usage: check-shell.sh [--audit] [--shellcheck-only]"
            echo "  --audit            Extra checks: dev.env permissions, recover-shell.sh executable, lib.sh present"
            echo "  --shellcheck-only  Static analysis on *.sh only (at priority tier)"
            exit 0
            ;;
    esac
done
errors=0
warnings=0

fail() { echo "ERROR: $1"; errors=$((errors + 1)); }
warn() { echo "WARN:  $1"; warnings=$((warnings + 1)); }
ok()   { echo "OK:   $1"; }

run_shellcheck_checks() {
    if command -v shellcheck &>/dev/null; then
        shellcheck_for_file() {
            local shell_script_path="$1" shellcheck_dialect shellcheck_exclude_codes
            case "$shell_script_path" in
                */lib.sh|*/env.sh|*/path.sh|*/personal.sh|*/environments/generic/*) shellcheck_dialect="sh" ;;
                *) shellcheck_dialect="bash" ;;
            esac
            shellcheck_exclude_codes='SC1090,SC1091'
            if shellcheck -s "$shellcheck_dialect" -x -S warning -e "$shellcheck_exclude_codes" "$shell_script_path" >/dev/null 2>&1; then
                ok "shellcheck: ${shell_script_path#$CONFIG_DIR/}"
            else
                fail "shellcheck: ${shell_script_path#$CONFIG_DIR/} (run: shellcheck -s $shellcheck_dialect -x ${shell_script_path})"
            fi
        }
        while IFS= read -r -d '' shell_script_file; do
            shellcheck_for_file "$shell_script_file"
        done < <(find "$CONFIG_DIR" -name '*.sh' -print0 2>/dev/null)
    else
        warn 'shellcheck not installed (optional: pacman -S shellcheck)'
    fi
}

if [[ "$SHELLCHECK_ONLY" == true ]]; then
    echo "=== shellcheck ==="
    run_shellcheck_checks
    echo ""
    echo "=== summary: $errors error(s), $warnings warning(s) ==="
    [[ "$errors" -eq 0 ]]
    exit $?
fi

# Avoid rg-as-grep alias breaking -E patterns (common on Omarchy)
if command -v grep >/dev/null 2>&1 && grep --version 2>/dev/null | head -1 | grep -qi gnu; then
    GREP=(grep)
else
    GREP=(command grep)
fi

line_number() {
    "${GREP[@]}" -nE "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1 || true
}

check_order() {
    local file="$1" first_pat="$2" second_pat="$3" label="$4"
    local first second
    first="$(line_number "$file" "$first_pat")"
    second="$(line_number "$file" "$second_pat")"
    if [[ -z "$first" || -z "$second" ]]; then
        warn "$label: could not find both markers in $file"
        return
    fi
    if [[ "$first" -lt "$second" ]]; then
        ok "$label: correct order in $file"
    else
        fail "$label: $second_pat must come after $first_pat in $file"
    fi
}

echo "=== shell config checks ==="

# Secrets must not live in the shell git repo (breaks Cursor cwd + direnv)
if [[ -f "$CONFIG_DIR/.envrc" || -f "$CONFIG_DIR/.env" ]]; then
    fail 'secrets .envrc/.env found in ~/.config/shell — move to ~/.config/secrets/'
else
    ok 'no .envrc/.env in shell repo'
fi
if [[ -f "$HOME/.config/secrets/dev.env" ]]; then
    ok 'dev secrets at ~/.config/secrets/dev.env'
    if [[ "$AUDIT" == true ]]; then
        secrets_file_mode=$(stat -c '%a' "$HOME/.config/secrets/dev.env" 2>/dev/null || echo '')
        case "$secrets_file_mode" in
            600|640) ok "dev.env permissions: $secrets_file_mode" ;;
            *) warn "dev.env permissions $secrets_file_mode (recommend 600)" ;;
        esac
    fi
else
    warn 'missing ~/.config/secrets/dev.env (optional)'
fi

# lib wired into env; personal must not use set -a
if grep -q 'lib.sh' "$ENV_FILE" 2>/dev/null || grep -q 'core/lib.sh' "$CONFIG_DIR/env.sh" 2>/dev/null; then
    ok 'env sources lib.sh'
else
    warn 'env does not source lib.sh'
fi
personal_overlay_path="$CONFIG_DIR/local/personal.sh"
[[ -f "$personal_overlay_path" ]] || personal_overlay_path="$CONFIG_DIR/personal.sh"
if grep -qE '^[[:space:]]*set[[:space:]]+-a' "$personal_overlay_path" 2>/dev/null; then
    fail 'personal.sh uses set -a for secrets (use load_secrets_file in lib.sh)'
else
    ok 'personal.sh does not use set -a'
fi
if grep -vE '^[[:space:]]*#|_local_alias|path_drop' "$ENV_FILE" 2>/dev/null | grep -q '\.\./bin'; then
    fail 'env contains ../bin PATH (use ~/.local/bin)'
else
    ok 'env has no ../bin PATH entries'
fi

# Environment hooks before aliases in rc files
environment_hook_pattern='(source_environment_shell|source_layer_shell|source_omarchy|omarchy/)'
check_order "$HOME/.bashrc" "$environment_hook_pattern" 'aliases\.sh' 'bash environment before aliases'
check_order "$HOME/.zshrc" "$environment_hook_pattern" 'aliases\.sh' 'zsh environment before aliases'
if "${GREP[@]}" -q 'source_layer_shell' "$HOME/.zshrc" 2>/dev/null \
    || "${GREP[@]}" -q 'source_layer_shell' "$HOME/.bashrc" 2>/dev/null; then
    warn 'rc still uses removed source_layer_shell — run: ~/.config/shell/bin/migrate.sh --sync-rc'
fi

# Login shell identity + current process reality check
u="${USER:-$(id -un 2>/dev/null || whoami)}"
login_shell="$(getent passwd "$u" 2>/dev/null | cut -d: -f7 || echo '')"
current_proc="$(ps -p $$ -o comm= 2>/dev/null || echo "$0")"
mismatch=0

if [[ -n "$login_shell" ]]; then
    if [[ "$login_shell" == "/usr/bin/zsh" || "$login_shell" == "/bin/zsh" ]]; then
        ok "default login shell is zsh (passwd: $login_shell)"
    else
        warn "default login shell is '$login_shell' (chsh -s /usr/bin/zsh to switch)"
    fi
else
    warn "could not determine login shell via getent passwd"
fi

# What is *actually* running right now (far more reliable than $SHELL)
if [[ "$current_proc" == "zsh" || "$current_proc" == "-zsh" ]]; then
    ok "current process is zsh (ps says: $current_proc)"
elif [[ "$current_proc" == "bash" || "$current_proc" == "-bash" ]]; then
    ok "current process is bash (ps says: $current_proc)"
else
    warn "current process reported by ps as: $current_proc (use 'echo \$0' or 'ps -p \$\$ -o comm=')"
fi

# $SHELL is frequently a lie after chsh + exec / in long-lived terminals
if [[ "$SHELL" != "$login_shell" && -n "$login_shell" ]]; then
    warn "\$SHELL ($SHELL) differs from passwd login shell — this is *normal* and often persists even after 'exec /usr/bin/zsh -l' because terminals export the original value and shells inherit it."
    mismatch=1
fi

echo "  Reliable current shell check: shell_debug   (or: echo \$0; ps -p \$\$ -o comm=; echo \${ZSH_VERSION:-} \${BASH_VERSION:-})"

# Direnv hooks when direnv is installed; guarded hooks when absent
if command -v direnv &>/dev/null; then
    grep -q 'direnv hook bash' "$HOME/.bashrc" && ok 'direnv hooked in bash' || fail 'direnv missing from ~/.bashrc'
    grep -q 'direnv hook zsh' "$HOME/.zshrc" && ok 'direnv hooked in zsh' || fail 'direnv missing from ~/.zshrc'
else
    if grep -q 'direnv hook bash' "$HOME/.bashrc" 2>/dev/null; then
        if grep -q 'command -v direnv' "$HOME/.bashrc"; then
            ok 'bashrc direnv hook guarded (direnv not installed)'
        else
            warn 'bashrc calls direnv hook without command -v guard — bin/migrate.sh --force-rc'
        fi
    else
        ok 'bashrc has no direnv hook'
    fi
    if grep -q 'direnv hook zsh' "$HOME/.zshrc" 2>/dev/null; then
        if grep -q 'command -v direnv' "$HOME/.zshrc"; then
            ok 'zshrc direnv hook guarded (direnv not installed)'
        else
            warn 'zshrc calls direnv hook without command -v guard — bin/migrate.sh --force-rc'
        fi
    else
        ok 'zshrc has no direnv hook'
    fi
fi

# personal chained from aliases
grep -qE 'personal\.sh|local/personal' "$ALIASES_FILE" \
    && ok 'personal overlay chained from aliases' \
    || fail 'aliases does not source personal overlay'

# Never alias ga or n (ignore comment-only lines)
for reserved in ga n; do
    if grep -R --include='*.sh' -E "^[[:space:]]*alias[[:space:]]+${reserved}=" "$CONFIG_DIR" 2>/dev/null | grep -q .; then
        fail "reserved alias ${reserved}= found under ~/.config/shell"
    else
        ok "no alias ${reserved}= under ~/.config/shell"
    fi
done

# Runtime verification that reserved names resolve to Omarchy functions in zsh
# Skip in editor terminals (Omarchy hooks may be reduced; not a config defect)
if command -v zsh &>/dev/null; then
    zsh_runtime_env=()
    if [[ -n "${CURSOR_AGENT:-}" || "${TERM_PROGRAM:-}" == *[Cc]ursor* ]]; then
        zsh_runtime_env=(SHELL_IN_EDITOR_TERMINAL=yes)
    fi
    for r in n ga gd; do
        if env "${zsh_runtime_env[@]}" zsh -ic "type -w $r 2>/dev/null" 2>/dev/null | "${GREP[@]}" -q ': function'; then
            ok "zsh runtime: ${r} is function (Omarchy reserved, reload-safe)"
        elif [[ ${#zsh_runtime_env[@]} -gt 0 ]]; then
            ok "zsh runtime: ${r} skipped (editor terminal)"
        else
            warn "zsh runtime: ${r} did not resolve to function (run migrate.sh --sync-rc?)"
        fi
    done
fi

# functions.sh wired into rc files
grep -q 'functions.sh' "$HOME/.bashrc" \
    && ok 'functions.sh sourced in bash' \
    || warn 'functions.sh not sourced in ~/.bashrc'
grep -q 'functions.sh' "$HOME/.zshrc" \
    && ok 'functions.sh sourced in zsh' \
    || warn 'functions.sh not sourced in ~/.zshrc'

# migrate preserves core modules
if grep -q 'install_if_missing' "$CONFIG_DIR/bin/tasks/install-modules.sh" 2>/dev/null; then
    ok 'migrate uses install_if_missing (preserves existing modules)'
else
    warn 'migrate may overwrite modules on rerun'
fi

grep -q -- '--force-rc' "$CONFIG_DIR/bin/migrate.sh" \
    && ok 'migrate.sh supports --force-rc' \
    || warn 'migrate.sh missing --force-rc flag'

# Modular layout
[[ -f "$CONFIG_DIR/core/env.sh" ]] && ok 'core/env.sh present' || warn 'core/env.sh missing'
[[ -f "$CONFIG_DIR/environments/generic/env.sh" ]] && ok 'environments/generic present' || warn 'environments/generic missing'
[[ -f "$CONFIG_DIR/environments/omarchy/env.sh" ]] && ok 'environments/omarchy present' || warn 'environments/omarchy missing'
grep -q 'resolve_shell_environment' "$LIB_FILE" 2>/dev/null \
    && ok 'source_environments API in lib.sh' \
    || warn 'resolve_shell_environment missing from lib.sh'
grep -q '_path_remove_segment' "$CONFIG_DIR/core/path.sh" 2>/dev/null \
    && ok 'path_prepend removes-then-adds (idempotent)' \
    || warn 'path_prepend idempotency helper missing'
grep -q 'local/overwrite.sh' "$ENV_FILE" 2>/dev/null \
    && ok 'env.sh supports local/overwrite.sh' \
    || warn 'local/overwrite.sh hook missing from env.sh'
grep -q '_SHELL_ENV_SH_LOADED' "$ENV_FILE" 2>/dev/null \
    && ok 'env re-entry guard present' \
    || warn 'env missing _SHELL_ENV_SH_LOADED guard'

# Duplicate Omarchy envs in zshrc
if grep -q 'omarchy/default/bash/envs' "$HOME/.zshrc"; then
    warn 'zshrc still sources Omarchy envs (duplicate of env.sh)'
else
    ok 'zshrc does not duplicate Omarchy envs'
fi

# Login files delegate PATH to env.sh (migrate generates when missing or managed)
for login_file in zprofile profile; do
    if [[ -f "$HOME/.${login_file}" ]]; then
        if grep -q 'config/shell/env.sh' "$HOME/.${login_file}"; then
            ok "${HOME}/.${login_file} delegates to env.sh"
        else
            warn "${HOME}/.${login_file} exists but does not source env.sh"
        fi
    else
        warn "missing ${HOME}/.${login_file} (run bin/migrate.sh)"
    fi
done
if [[ -f "$HOME/.zshenv" ]]; then
    grep -q 'export SHELL=' "$HOME/.zshenv" && ok 'zshenv sets SHELL' || warn 'zshenv missing export SHELL='
else
    warn 'missing ~/.zshenv (run bin/migrate.sh)'
fi
if [[ -f "$HOME/.bash_profile" ]]; then
    grep -q 'bashrc' "$HOME/.bash_profile" && ok 'bash_profile sources bashrc' || warn 'bash_profile may not source ~/.bashrc'
else
    warn 'missing ~/.bash_profile (run bin/migrate.sh)'
fi

# Starship + mamba prompt pairing
if command -v starship &>/dev/null; then
    if [[ -f "$HOME/.config/starship.toml" ]]; then
        ok 'starship.toml present'
        if grep -q '\[conda\]' "$HOME/.config/starship.toml"; then
            ok 'starship.toml has [conda] module'
        else
            warn 'starship.toml missing [conda] module (duplicate env prefix risk with mamba)'
        fi
    else
        warn 'starship installed but ~/.config/starship.toml missing (run migrate or cp starship.ex.toml)'
    fi
    if grep -q 'CONDA_CHANGEPS1=false' "$ENV_FILE" 2>/dev/null; then
        ok 'CONDA_CHANGEPS1=false in env.sh'
    else
        warn 'env.sh missing CONDA_CHANGEPS1=false'
    fi
fi
if [[ -f "$CONFIG_DIR/starship.ex.toml" ]]; then
    ok 'starship.ex.toml present in repo'
else
    warn 'starship.ex.toml missing from ~/.config/shell'
fi

# path_debug helper
grep -q 'path_debug' "$FUNCS_FILE" \
    && ok 'path_debug defined in functions.sh' \
    || warn 'path_debug missing from functions.sh'

# PATH helpers
grep -q 'path_prepend' "$CONFIG_DIR/core/path.sh" 2>/dev/null \
    && ok 'core/path.sh defines path_prepend' \
    || warn 'path_prepend missing'
grep -q 'path_append' "$CONFIG_DIR/core/path.sh" 2>/dev/null \
    && ok 'core/path.sh defines path_append' \
    || warn 'path_append missing'

# PATH contract v2 (core/path.contract + path-resolve.sh + runtime verify)
PATH_CONTRACT="$CONFIG_DIR/core/path.contract"
PATH_RESOLVE="$CONFIG_DIR/core/path-resolve.sh"
TOOL_CONTRACT="$CONFIG_DIR/core/tool.contract"
if [[ -f "$PATH_CONTRACT" ]]; then
    grep -q '^phase:core' "$PATH_CONTRACT" \
        && ok 'path.contract v2 format (phase:core)' \
        || warn 'path.contract missing phase:core (v2 format)'
    grep -q '^deny:' "$PATH_CONTRACT" \
        && ok 'path.contract has deny list' \
        || warn 'path.contract missing deny entries'
else
    warn 'core/path.contract missing'
fi
[[ -f "$PATH_RESOLVE" ]] && ok 'core/path-resolve.sh present' || warn 'core/path-resolve.sh missing'
grep -q 'path_contract_apply' "$ENV_FILE" 2>/dev/null \
    && ok 'env.sh uses path_contract_apply' \
    || warn 'env.sh missing path_contract_apply'
grep -q 'path_deny_sweep' "$ENV_FILE" 2>/dev/null \
    && ok 'env.sh uses path_deny_sweep' \
    || warn 'env.sh missing path_deny_sweep'
grep -q 'tool_contract_apply' "$ENV_FILE" 2>/dev/null \
    && ok 'env.sh uses tool_contract_apply' \
    || warn 'env.sh missing tool_contract_apply'
[[ -f "$TOOL_CONTRACT" ]] && ok 'core/tool.contract present' || warn 'core/tool.contract missing'
LOCAL_PATH_CONTRACT="$CONFIG_DIR/local/path.contract"
LOCAL_PATH_EXAMPLE="$CONFIG_DIR/local/path.contract.example"
if [[ -f "$LOCAL_PATH_CONTRACT" || -f "$LOCAL_PATH_EXAMPLE" ]]; then
    ok 'local/path.contract or example present'
else
    warn 'local/path.contract missing (copy from local/path.contract.example for personal PATH)'
fi
grep -q 'LOCAL_PATH_CONTRACT' "$PATH_RESOLVE" 2>/dev/null \
    && ok 'path-resolve.sh supports local/path.contract overlay' \
    || warn 'path-resolve.sh missing LOCAL_PATH_CONTRACT overlay'
if [[ -f "$PATH_RESOLVE" ]]; then
    core_apply_line_number=$(grep -n 'path_contract_apply_file "\$PATH_CONTRACT"' "$PATH_RESOLVE" | head -1 | cut -d: -f1)
    local_apply_line_number=$(grep -n 'path_contract_apply_file "\$LOCAL_PATH_CONTRACT"' "$PATH_RESOLVE" | head -1 | cut -d: -f1)
    local_rank_line_number=$(grep -n '_path_contract_collect_phase_prepends_file "\$LOCAL_PATH_CONTRACT"' "$PATH_RESOLVE" | head -1 | cut -d: -f1)
    core_rank_line_number=$(grep -n '_path_contract_collect_phase_prepends_file "\$PATH_CONTRACT"' "$PATH_RESOLVE" | head -1 | cut -d: -f1)
    if [[ -n "$core_apply_line_number" && -n "$local_apply_line_number" && "$core_apply_line_number" -lt "$local_apply_line_number" \
          && -n "$local_rank_line_number" && -n "$core_rank_line_number" && "$local_rank_line_number" -lt "$core_rank_line_number" ]]; then
        ok 'local overlay invariant: apply core→local, verify ranks local→core'
    else
        warn 'path-resolve.sh overlay order broken (apply core→local; verify collect local→core)'
    fi
    unset core_apply_line_number local_apply_line_number local_rank_line_number core_rank_line_number
fi
PATH_CONTRACT_PROJECT_SH="$CONFIG_DIR/bin/path-contract-project.sh"
if [[ -x "$PATH_CONTRACT_PROJECT_SH" ]]; then
    ok 'bin/path-contract-project.sh present and executable'
else
    warn 'bin/path-contract-project.sh missing or not executable (SN-2 direnv project fragment)'
fi
grep -q 'path_contract_apply_project' "$PATH_RESOLVE" 2>/dev/null \
    && ok 'path-resolve.sh has path_contract_apply_project' \
    || warn 'path-resolve.sh missing path_contract_apply_project'
if [[ -f "$PATH_RESOLVE" ]]; then
    grep -qE 'post_vite\|project' "$PATH_RESOLVE" \
        && ok 'path-resolve.sh excludes project from unfiltered apply' \
        || warn 'path-resolve.sh should exclude project phase from default apply'
fi
if [[ -f "$PATH_CONTRACT" ]]; then
    if grep -qE '^prepend:.*(grok|risc0|solana|vite-plus|rocm|\.vector)' "$PATH_CONTRACT" 2>/dev/null \
        || grep -qE '^append:.*/opt/rocm' "$PATH_CONTRACT" 2>/dev/null; then
        warn 'core/path.contract still has personal toolchain entries (move to local/path.contract)'
    else
        ok 'core/path.contract free of personal toolchain entries'
    fi
fi
if ! grep -q 'path_prepend.*OMARCHY' "$CONFIG_DIR/environments/omarchy/env.sh" 2>/dev/null; then
    ok 'omarchy env.sh delegates PATH to contract'
else
    warn 'omarchy env.sh still has path_prepend (should be in path.contract only)'
fi

# Runtime PATH verify (full zsh login session — catches post-hook mutations)
if command -v zsh &>/dev/null && [[ -f "$PATH_RESOLVE" ]]; then
    path_contract_runtime_json=$(zsh -lic 'path_contract_verify --json 2>/dev/null' || true)
    if [[ "$path_contract_runtime_json" == *'"ok":true'* ]]; then
        ok 'PATH runtime contract verify (zsh -lic)'
    elif [[ -n "$path_contract_runtime_json" ]]; then
        warn 'PATH runtime contract mismatch (run: zsh -lic path_check)'
    else
        warn 'PATH runtime verify unavailable (path_contract_verify not in zsh session)'
    fi
    path_shadow_report_output=$(zsh -lic 'path_shadow_report --warn 2>&1' || true)
    if [[ -z "$path_shadow_report_output" ]]; then
        ok 'no tool.contract shadow warnings'
    else
        while IFS= read -r shadow_warning_line; do
            [[ -n "$shadow_warning_line" ]] && warn "$shadow_warning_line"
        done <<< "$path_shadow_report_output"
    fi
fi

# Init capture script
[[ -x "$CONFIG_DIR/bin/capture-shell-init.sh" ]] \
    && ok 'capture-shell-init.sh present' \
    || warn 'capture-shell-init.sh missing'

# migrate rc policy
grep -q -- '--sync-rc' "$CONFIG_DIR/bin/migrate.sh" \
    && ok 'migrate.sh supports --sync-rc' \
    || warn 'migrate.sh missing --sync-rc flag'
grep -q 'should_write_rc' "$CONFIG_DIR/bin/lib/migrate-common.sh" \
    && ok 'migrate.sh preserves hand-edited rc files' \
    || warn 'migrate rc policy helpers missing from migrate-common.sh'

# Verification workflow
grep -q 'FZF_DEFAULT_OPTS' "$ENV_FILE" \
    && ok 'env.sh: FZF_DEFAULT_OPTS' \
    || warn 'env.sh: FZF_DEFAULT_OPTS missing'
grep -q 'agent_verify' "$FUNCS_FILE" \
    && ok 'functions.sh: agent_verify' \
    || warn 'functions.sh: agent_verify missing'
grep -q "alias ab='agent_build'" "$ALIASES_FILE" \
    && ok 'aliases.sh: ab (agent build)' \
    || warn 'aliases.sh: ab alias missing'
grep -q 'agent_build' "$FUNCS_FILE" \
    && ok 'functions.sh: agent_build' \
    || warn 'functions.sh: agent_build missing'
grep -q '^vf()' "$FUNCS_FILE" \
    && ok 'functions.sh: vf' \
    || warn 'functions.sh: vf missing'
[[ -x "$CONFIG_DIR/bin/agent-verify-layout.sh" ]] \
    && ok 'agent-verify-layout.sh executable' \
    || warn 'agent-verify-layout.sh missing or not executable'
[[ -x "$CONFIG_DIR/bin/agent-build-layout.sh" ]] \
    && ok 'agent-build-layout.sh executable' \
    || warn 'agent-build-layout.sh missing or not executable'
VERIFY_LAUNCH="$CONFIG_DIR/bin/lib/verify-launch.sh"
grep -q 'agent_strict_path_check' "$VERIFY_LAUNCH" 2>/dev/null \
    && ok 'verify-launch.sh has agent strict PATH helpers' \
    || warn 'verify-launch.sh missing agent strict PATH (SN-3)'
grep -q 'path_contract_apply_core_only' "$PATH_RESOLVE" 2>/dev/null \
    && ok 'path-resolve.sh has path_contract_apply_core_only' \
    || warn 'path-resolve.sh missing path_contract_apply_core_only'
[[ -x "$CONFIG_DIR/bin/cockpit-mcp.sh" ]] \
    && ok 'bin/cockpit-mcp.sh present (SN-7 headless verbs)' \
    || warn 'bin/cockpit-mcp.sh missing'
[[ -x "$CONFIG_DIR/bin/lib/discover-tests.sh" ]] \
    && ok 'discover-tests.sh present (SN-8 canonical emitter)' \
    || warn 'discover-tests.sh missing'

[[ -x "$CONFIG_DIR/bin/lib/parse-project-tests-discover.sh" ]] \
    && ok 'parse-project-tests-discover.sh present (SN-8 shim)' \
    || warn 'parse-project-tests-discover.sh missing'
[[ -f "$HOME/.config/tmux/tmux.conf" ]] \
    && ok 'tmux.conf present' \
    || warn 'tmux.conf missing (run migrate.sh)'
tmux_verify_conf_path="$HOME/.config/tmux/verify.conf"
if [[ -f "$tmux_verify_conf_path" ]]; then
    if grep -q 'bind B' "$tmux_verify_conf_path" 2>/dev/null; then
        ok 'tmux verify.conf: Prefix+B (build)'
    else
        warn 'tmux verify.conf missing bind B — run bin/sync-tmux-verify.sh'
    fi
    if grep -q 'bind V' "$tmux_verify_conf_path" 2>/dev/null; then
        ok 'tmux verify.conf: Prefix+V (verify)'
    else
        warn 'tmux verify.conf missing bind V — run bin/sync-tmux-verify.sh'
    fi
    if grep -q 'bind T' "$tmux_verify_conf_path" 2>/dev/null; then
        ok 'tmux verify.conf: Prefix+T (test)'
    else
        warn 'tmux verify.conf missing bind T — run bin/sync-tmux-verify.sh'
    fi
    if grep -q 'tmux-keymap-menu' "$tmux_verify_conf_path" 2>/dev/null; then
        ok 'tmux verify.conf: keymap menu (Prefix+?)'
    else
        warn 'tmux verify.conf missing keymap menu — merge from tmux.verify.conf.ex'
    fi
    if grep -q 'tmux-mode-sync' "$tmux_verify_conf_path" 2>/dev/null || grep -q 'tmux.status-mode.conf.ex' "$tmux_verify_conf_path" 2>/dev/null; then
        ok 'tmux verify.conf: mode display hooks (tmux-mode-sync)'
    else
        warn 'tmux verify.conf missing mode display — merge from tmux.verify.conf.ex'
    fi
    tmux_status_right_length="$(tmux show-options -gv status-right-length 2>/dev/null || echo 0)"
    if [[ "${tmux_status_right_length:-0}" -ge 100 ]]; then
        ok "tmux status-right-length: $tmux_status_right_length (mode bar fits)"
    else
        warn "tmux status-right-length $tmux_status_right_length — need >=100 for mode display (run: tmux-mode-sync.sh apply)"
    fi
    unset tmux_status_right_length
fi
[[ -x "$CONFIG_DIR/bin/tmux-keymap-menu.sh" ]] \
    && ok 'tmux-keymap-menu.sh executable' \
    || warn 'tmux-keymap-menu.sh missing or not executable'
[[ -f "$CONFIG_DIR/bin/data/tmux-keymaps.tsv" ]] \
    && ok 'tmux-keymaps.tsv present' \
    || warn 'tmux-keymaps.tsv missing'
if [[ -x "$CONFIG_DIR/bin/test/verify-workflow-root.test.sh" ]]; then
    if "$CONFIG_DIR/bin/test/verify-workflow-root.test.sh" >/tmp/verify-workflow-root.test.out 2>&1; then
        ok 'verify_workflow_root tests pass'
    else
        warn 'verify_workflow_root tests failed (see /tmp/verify-workflow-root.test.out)'
    fi
fi

if [[ -x "$CONFIG_DIR/bin/test/strict-path.test.sh" ]]; then
    if "$CONFIG_DIR/bin/test/strict-path.test.sh" >/tmp/strict-path.test.out 2>&1; then
        ok 'agent_strict_path tests pass'
    else
        warn 'agent_strict_path tests failed (see /tmp/strict-path.test.out)'
    fi
fi
unset tmux_verify_conf_path
[[ -f "$CONFIG_DIR/arch-design/VERIFICATION.md" ]] \
    && ok 'arch-design/VERIFICATION.md present' \
    || warn 'arch-design/VERIFICATION.md missing'
[[ -f "$HOME/.config/nvim/lua/plugins/verification-workflow.lua" ]] \
    && ok 'nvim verification-workflow plugin' \
    || warn 'nvim verification-workflow plugin missing (optional)'

GIT_VERIFY="$HOME/.config/git/verification"
if [[ -f "$GIT_VERIFY" ]]; then
    if git config --global --get-all include.path 2>/dev/null | grep -qF "$GIT_VERIFY"; then
        ok 'git include.path → verification (delta)'
    else
        warn 'git verification exists but include.path not set — git config --global include.path ~/.config/git/verification'
    fi
fi

# Verification tools are on PATH after env.sh (~/.cargo/bin, system packages).
# check-shell often runs from a bare bash subshell — prime PATH like interactive shells.
if [[ -z "${_CHECK_SHELL_ENV_LOADED:-}" && -f "$ENV_FILE" ]]; then
    # shellcheck disable=SC1091
    . "$ENV_FILE" 2>/dev/null || true
    export _CHECK_SHELL_ENV_LOADED=1
fi
command -v delta &>/dev/null \
    && ok 'delta on PATH' \
    || warn 'delta not on PATH (install git-delta or cargo install git-delta)'
command -v procs &>/dev/null \
    && ok 'procs installed (ps alias when sourced)' \
    || warn 'procs not installed (optional: paru -S procs)'
command -v difft &>/dev/null \
    && ok 'difftastic installed (gdf/gdfs when sourced)' \
    || warn 'difftastic not installed (optional: paru -S difftastic)'

# fish tier-1 tools
FISH_CFG="$HOME/.config/fish/config.fish"

# Doc triage + skills collapse (SN-6)
[[ -f "$CONFIG_DIR/PLUGIN.md" ]] && ok 'PLUGIN.md present (kernel boundary)' || warn 'PLUGIN.md missing'
CURSOR_SKILLS="$CONFIG_DIR/.cursor/skills"
AGENTS_SKILLS="$CONFIG_DIR/.agents/skills"
if [[ -L "$CURSOR_SKILLS" ]] && [[ "$(readlink -f "$CURSOR_SKILLS" 2>/dev/null)" == "$(readlink -f "$AGENTS_SKILLS" 2>/dev/null)" ]]; then
    ok '.cursor/skills symlinks to .agents/skills'
elif [[ -d "$AGENTS_SKILLS" ]]; then
    warn '.cursor/skills should symlink to .agents/skills (duplicate skill trees)'
fi
[[ -f "$CONFIG_DIR/local/omarchy.sh.example" ]] \
    && ok 'local/omarchy.sh.example present' \
    || warn 'local/omarchy.sh.example missing (Omarchy overlay pattern)'

if [[ -f "$FISH_CFG" ]]; then
    grep -q 'direnv hook fish' "$FISH_CFG" && ok 'fish: direnv hooked' || warn 'fish: direnv missing'
    grep -q 'functions.sh' "$FISH_CFG" && ok 'fish: functions.sh sourced' || warn 'fish: functions.sh missing'
    grep -q 'fzf --fish' "$FISH_CFG" && ok 'fish: fzf hooked' || warn 'fish: fzf missing'
    grep -q 'thefuck --alias' "$FISH_CFG" && ok 'fish: thefuck hooked' || warn 'fish: thefuck missing'
fi

# Static analysis via shellcheck (install: pacman -S shellcheck)
run_shellcheck_checks

if [[ "$AUDIT" == true ]]; then
    [[ -x "$CONFIG_DIR/bin/recover-shell.sh" ]] && ok 'recover-shell.sh is executable' || warn 'recover-shell.sh missing or not executable'
    [[ -f "$LIB_FILE" ]] && ok 'lib.sh present' || fail 'lib.sh missing'
    [[ -x "$CONFIG_DIR/bin/check-template-sync.sh" ]] && "$CONFIG_DIR/bin/check-template-sync.sh" || warn 'template sync check failed'
fi

echo ""
if [[ "${mismatch:-0}" -eq 1 ]]; then
    echo ">>> \$SHELL is a lying ghost variable. It was set by the *original* terminal/login process"
    echo ">>> and is inherited across 'exec'. Even a successful 'exec /usr/bin/zsh -l' often leaves"
    echo ">>> the old value in the environment. The prompt, ZSH_VERSION, and 'ps -p \$\$ -o comm=' are truth."
    echo ">>>"
    echo ">>> 'reload' only re-sources rc files for the *current* interpreter. It does not switch shells."
    echo ">>>"
    echo ">>> To replace the current process with your real default login shell:"
    echo ">>>     exec $login_shell -l"
    echo ">>> Then immediately run:  shell_debug   or your verification one-liner."
    echo ""
fi
echo "=== summary: $errors error(s), $warnings warning(s) ==="
[[ "$errors" -eq 0 ]]