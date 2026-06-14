#!/usr/bin/env bash
# Verify shell load order and reserved-name guardrails.
# Usage: check-shell.sh [--audit]
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
AUDIT=false
for arg in "$@"; do
    case "$arg" in
        --audit) AUDIT=true ;;
        -h|--help)
            echo "Usage: check-shell.sh [--audit]"
            echo "  --audit  Extra checks: dev.env permissions, recover-shell.sh executable, lib.sh present"
            exit 0
            ;;
    esac
done
errors=0
warnings=0

fail() { echo "ERROR: $1"; errors=$((errors + 1)); }
warn() { echo "WARN:  $1"; warnings=$((warnings + 1)); }
ok()   { echo "OK:   $1"; }

line_number() {
    grep -nE "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1
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
        _perm=$(stat -c '%a' "$HOME/.config/secrets/dev.env" 2>/dev/null || echo '')
        case "$_perm" in
            600|640) ok "dev.env permissions: $_perm" ;;
            *) warn "dev.env permissions $_perm (recommend 600)" ;;
        esac
    fi
else
    warn 'missing ~/.config/secrets/dev.env (optional)'
fi

# lib.sh wired into env.sh; personal.sh must not use set -a for secrets
if grep -q 'lib.sh' "$CONFIG_DIR/env.sh" 2>/dev/null; then
    ok 'env.sh sources lib.sh'
else
    warn 'env.sh does not source lib.sh'
fi
if grep -qE '^[[:space:]]*set[[:space:]]+-a' "$CONFIG_DIR/personal.sh" 2>/dev/null; then
    fail 'personal.sh uses set -a for secrets (use load_secrets_file in lib.sh)'
else
    ok 'personal.sh does not use set -a'
fi
if grep -vE '^[[:space:]]*#' "$CONFIG_DIR/env.sh" 2>/dev/null | grep -q '\.\./bin'; then
    fail 'env.sh contains ../bin path (use ~/.local/bin/env)'
else
    ok 'env.sh uses explicit ~/.local/bin/env path'
fi

# Bash: Omarchy rc before aliases.sh (source lines only)
check_order "$HOME/.bashrc" 'source.*omarchy/default/bash/rc' 'source.*aliases\.sh' 'bash Omarchy before aliases'

# Zsh: Omarchy functions before aliases.sh (source lines only)
check_order "$HOME/.zshrc" 'source.*omarchy/default/bash/functions' 'source.*aliases\.sh' 'zsh Omarchy functions before aliases'

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

# personal.sh chained from aliases.sh
grep -q 'personal.sh' "$CONFIG_DIR/aliases.sh" \
    && ok 'personal.sh chained from aliases.sh' \
    || fail 'aliases.sh does not source personal.sh'

# Never alias ga or n (ignore comment-only lines)
for reserved in ga n; do
    if grep -R --include='*.sh' -E "^[[:space:]]*alias[[:space:]]+${reserved}=" "$CONFIG_DIR" 2>/dev/null | grep -q .; then
        fail "reserved alias ${reserved}= found under ~/.config/shell"
    else
        ok "no alias ${reserved}= under ~/.config/shell"
    fi
done

# Runtime verification that reserved names resolve to Omarchy functions in zsh
# (catches cases where tool inits/direnv/personal set aliases after the early guard)
if command -v zsh &>/dev/null; then
    for r in n ga gd; do
        if zsh -ic "type -w $r 2>/dev/null" 2>/dev/null | grep -q ': function'; then
            ok "zsh runtime: ${r} is function (Omarchy reserved, reload-safe)"
        else
            warn "zsh runtime: ${r} did not resolve to function (may be aliased)"
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

# migrate.sh should not overwrite existing modules
for module in env.sh aliases.sh functions.sh; do
    grep -q "Keeping existing $module" "$CONFIG_DIR/bin/migrate.sh" \
        && ok "migrate.sh preserves existing $module" \
        || warn "migrate.sh may overwrite $module on rerun"
done

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
    if grep -q 'CONDA_CHANGEPS1=false' "$CONFIG_DIR/env.sh" 2>/dev/null; then
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
grep -q 'path_debug' "$CONFIG_DIR/functions.sh" \
    && ok 'path_debug defined in functions.sh' \
    || warn 'path_debug missing from functions.sh'

# PATH helpers
grep -q 'path_prepend' "$CONFIG_DIR/env.sh" \
    && ok 'env.sh defines path_prepend' \
    || warn 'env.sh missing path_prepend'
grep -q 'path_append' "$CONFIG_DIR/env.sh" \
    && ok 'env.sh defines path_append' \
    || warn 'env.sh missing path_append'

# migrate rc policy
grep -q -- '--force-rc' "$CONFIG_DIR/bin/migrate.sh" \
    && ok 'migrate.sh supports --force-rc' \
    || warn 'migrate.sh missing --force-rc flag'
grep -q 'should_write_rc' "$CONFIG_DIR/bin/migrate.sh" \
    && ok 'migrate.sh preserves hand-edited rc files' \
    || warn 'migrate.sh may always overwrite rc files'

# Verification workflow
grep -q 'FZF_DEFAULT_OPTS' "$CONFIG_DIR/env.sh" \
    && ok 'env.sh: FZF_DEFAULT_OPTS' \
    || warn 'env.sh: FZF_DEFAULT_OPTS missing'
grep -q 'agent_verify' "$CONFIG_DIR/functions.sh" \
    && ok 'functions.sh: agent_verify' \
    || warn 'functions.sh: agent_verify missing'
grep -q '^vf()' "$CONFIG_DIR/functions.sh" \
    && ok 'functions.sh: vf' \
    || warn 'functions.sh: vf missing'
[[ -x "$CONFIG_DIR/bin/agent-verify-layout.sh" ]] \
    && ok 'agent-verify-layout.sh executable' \
    || warn 'agent-verify-layout.sh missing or not executable'
[[ -f "$HOME/.config/tmux/tmux.conf" ]] \
    && ok 'tmux.conf present' \
    || warn 'tmux.conf missing (run migrate.sh)'
[[ -f "$CONFIG_DIR/VERIFICATION.md" ]] \
    && ok 'VERIFICATION.md present' \
    || warn 'VERIFICATION.md missing'
[[ -f "$HOME/.config/nvim/lua/plugins/verification-workflow.lua" ]] \
    && ok 'nvim verification-workflow plugin' \
    || warn 'nvim verification-workflow plugin missing (optional)'

# fish tier-1 tools
FISH_CFG="$HOME/.config/fish/config.fish"
if [[ -f "$FISH_CFG" ]]; then
    grep -q 'direnv hook fish' "$FISH_CFG" && ok 'fish: direnv hooked' || warn 'fish: direnv missing'
    grep -q 'functions.sh' "$FISH_CFG" && ok 'fish: functions.sh sourced' || warn 'fish: functions.sh missing'
    grep -q 'fzf --fish' "$FISH_CFG" && ok 'fish: fzf hooked' || warn 'fish: fzf missing'
    grep -q 'thefuck --alias' "$FISH_CFG" && ok 'fish: thefuck hooked' || warn 'fish: thefuck missing'
fi

# Static analysis via shellcheck (install: pacman -S shellcheck)
if command -v shellcheck &>/dev/null; then
    shellcheck_for_file() {
        local _f="$1" _shell _exclude
        case "$_f" in
            */lib.sh|*/env.sh|*/personal.sh) _shell="sh" ;;
            *) _shell="bash" ;;
        esac
        _exclude='SC1090,SC1091'
        if shellcheck -s "$_shell" -x -S warning -e "$_exclude" "$_f" >/dev/null 2>&1; then
            ok "shellcheck: ${_f#$CONFIG_DIR/}"
        else
            fail "shellcheck: ${_f#$CONFIG_DIR/} (run: shellcheck -s $_shell -x ${_f})"
        fi
    }
    while IFS= read -r -d '' _scf; do
        shellcheck_for_file "$_scf"
    done < <(find "$CONFIG_DIR" -name '*.sh' -print0 2>/dev/null)
else
    warn 'shellcheck not installed (optional: pacman -S shellcheck)'
fi

if [[ "$AUDIT" == true ]]; then
    [[ -x "$CONFIG_DIR/bin/recover-shell.sh" ]] && ok 'recover-shell.sh is executable' || warn 'recover-shell.sh missing or not executable'
    [[ -f "$CONFIG_DIR/lib.sh" ]] && ok 'lib.sh present' || fail 'lib.sh missing'
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