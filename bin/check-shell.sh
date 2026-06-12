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

# Bash: Omarchy rc before aliases.sh (source lines only)
check_order "$HOME/.bashrc" 'source.*omarchy/default/bash/rc' 'source.*aliases\.sh' 'bash Omarchy before aliases'

# Zsh: Omarchy functions before aliases.sh (source lines only)
check_order "$HOME/.zshrc" 'source.*omarchy/default/bash/functions' 'source.*aliases\.sh' 'zsh Omarchy functions before aliases'

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

# Never alias ga (ignore comment-only lines)
if grep -R --include='*.sh' -E '^[[:space:]]*alias[[:space:]]+ga=' "$CONFIG_DIR" 2>/dev/null | grep -q .; then
    fail 'reserved alias ga= found under ~/.config/shell'
else
    ok 'no alias ga= under ~/.config/shell'
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

echo ""
echo "=== summary: $errors error(s), $warnings warning(s) ==="
[[ "$errors" -eq 0 ]]