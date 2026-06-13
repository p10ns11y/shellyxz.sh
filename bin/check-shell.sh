#!/usr/bin/env bash
# Verify shell load order and reserved-name guardrails.
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
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
else
    warn 'missing ~/.config/secrets/dev.env (optional)'
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

# Direnv hooks when direnv is installed
if command -v direnv &>/dev/null; then
    grep -q 'direnv hook bash' "$HOME/.bashrc" && ok 'direnv hooked in bash' || fail 'direnv missing from ~/.bashrc'
    grep -q 'direnv hook zsh' "$HOME/.zshrc" && ok 'direnv hooked in zsh' || fail 'direnv missing from ~/.zshrc'
else
    warn 'direnv not installed; skipping hook checks'
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

# Login files delegate PATH to env.sh
if [[ -f "$HOME/.zprofile" ]] && grep -q 'config/shell/env.sh' "$HOME/.zprofile"; then
    ok 'zprofile delegates PATH to env.sh'
elif [[ -f "$HOME/.zprofile" ]] && grep -q '^export PATH=' "$HOME/.zprofile"; then
    warn 'zprofile still has hardcoded PATH export'
fi
if [[ -f "$HOME/.profile" ]] && grep -q 'config/shell/env.sh' "$HOME/.profile"; then
    ok 'profile sources env.sh'
elif [[ -f "$HOME/.profile" ]] && grep -q '^export PATH=' "$HOME/.profile"; then
    warn 'profile still has hardcoded PATH export'
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

# fish tier-1 tools
FISH_CFG="$HOME/.config/fish/config.fish"
if [[ -f "$FISH_CFG" ]]; then
    grep -q 'direnv hook fish' "$FISH_CFG" && ok 'fish: direnv hooked' || warn 'fish: direnv missing'
    grep -q 'functions.sh' "$FISH_CFG" && ok 'fish: functions.sh sourced' || warn 'fish: functions.sh missing'
    grep -q 'fzf --fish' "$FISH_CFG" && ok 'fish: fzf hooked' || warn 'fish: fzf missing'
    grep -q 'thefuck --alias' "$FISH_CFG" && ok 'fish: thefuck hooked' || warn 'fish: thefuck missing'
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