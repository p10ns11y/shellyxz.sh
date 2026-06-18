#!/usr/bin/env bash
# path-contract.test.sh — unit tests for PATH contract resolver.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL=0

assert_ok() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'ok   %s\n' "$desc"
    else
        printf 'FAIL %s\n' "$desc" >&2
        FAIL=$((FAIL + 1))
    fi
}

assert_fail() {
    local desc="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        printf 'FAIL %s (expected failure)\n' "$desc" >&2
        FAIL=$((FAIL + 1))
    else
        printf 'ok   %s\n' "$desc"
    fi
}

assert_contains() {
    local desc="$1" needle="$2"
    shift 2
    local out
    out=$("$@" 2>/dev/null || true)
    if [[ "$out" == *"$needle"* ]]; then
        printf 'ok   %s\n' "$desc"
    else
        printf 'FAIL %s (missing %s in output)\n' "$desc" "$needle" >&2
        FAIL=$((FAIL + 1))
    fi
}

TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

mkdir -p "$TEST_HOME/bin" "$TEST_HOME/.local/bin" "$TEST_HOME/.config/shell/core"
cp "$ROOT/core/path.contract" "$ROOT/core/path-resolve.sh" "$ROOT/core/path.sh" "$ROOT/core/lib.sh" \
    "$TEST_HOME/.config/shell/core/"

export HOME="$TEST_HOME"
export SHELL_ROOT="$TEST_HOME/.config/shell"
export SHELL_ENVIRONMENT=generic
export PNPM_HOME="$TEST_HOME/.local/share/pnpm"
export PATH="/usr/local/bin:/usr/bin:/bin"

# shellcheck disable=SC1091
. "$SHELL_ROOT/core/lib.sh"
# shellcheck disable=SC1091
. "$SHELL_ROOT/core/path.sh"

assert_ok 'path_deny_sweep runs' path_deny_sweep
assert_ok 'path_contract_apply runs' path_contract_apply
assert_ok 'path_contract_apply post_vite runs' path_contract_apply --phase post_vite

assert_contains 'HOME/bin first after apply' "$TEST_HOME/bin" sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    path_contract_apply
    path_contract_apply --phase post_vite
    printf '%s' \"\$PATH\" | tr ':' '\n' | head -1
"

assert_ok 'path_contract_verify passes clean PATH' sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    path_deny_sweep
    path_contract_apply
    path_contract_apply --phase post_vite
    path_deny_sweep
    path_contract_verify --json | grep -q '\"ok\":true'
"

export PATH="/condabin:$PATH"
assert_fail 'deny /condabin detected' sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    path_contract_verify --json | grep -q '\"ok\":true'
"

export PATH="/usr/bin:/bin"
assert_ok 'path_contract_resolve_token HOME/bin' sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    [ \"\$(path_contract_resolve_token HOME/bin)\" = \"$TEST_HOME/bin\" ]
"

if [[ -f "$ROOT/core/tool.contract" ]]; then
    cp "$ROOT/core/tool.contract" "$TEST_HOME/.config/shell/core/"
    assert_ok 'tool_contract_apply runs' tool_contract_apply
fi

# local/path.contract overlay
mkdir -p "$TEST_HOME/.grok/bin" "$TEST_HOME/.config/shell/local"
cat > "$TEST_HOME/.config/shell/local/path.contract" <<EOF
phase:core
prepend:.grok/bin
EOF

assert_contains 'local overlay prepends .grok/bin' "$TEST_HOME/.grok/bin" sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    path_deny_sweep
    path_contract_apply
    printf '%s' \"\$PATH\"
"

assert_ok 'path_contract_verify with local overlay' sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    path_deny_sweep
    path_contract_apply
    path_deny_sweep
    path_contract_verify --json | grep -q '\"ok\":true'
"

# phase:project (direnv per-repo fragment)
PROJECT_ROOT="$TEST_HOME/myrepo"
mkdir -p "$PROJECT_ROOT/bin"
cat > "$PROJECT_ROOT/.path.contract" <<EOF
phase:project
append:PWD/bin
EOF

assert_contains 'project phase appends PWD/bin' "$PROJECT_ROOT/bin" sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    export PATH='/usr/bin:/bin'
    export PATH_CONTRACT_PROJECT_ROOT='$PROJECT_ROOT'
    path_contract_apply_project '$PROJECT_ROOT/.path.contract'
    printf '%s' \"\$PATH\"
"

assert_ok 'project phase excluded from default path_contract_apply' sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    export PATH='/usr/bin:/bin'
    export PATH_CONTRACT_PROJECT_ROOT='$PROJECT_ROOT'
    path_contract_apply
    ! printf '%s' \"\$PATH\" | tr ':' '\n' | grep -qx '$PROJECT_ROOT/bin'
"

assert_ok 'path_contract_verify still passes without project phase' sh -c "
    . \"$SHELL_ROOT/core/path.sh\"
    path_deny_sweep
    path_contract_apply
    path_contract_apply --phase post_vite
    path_deny_sweep
    path_contract_verify --json | grep -q '\"ok\":true'
"

echo "=== $FAIL failure(s) ==="
[[ "$FAIL" -eq 0 ]]
