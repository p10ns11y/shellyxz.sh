#!/usr/bin/env bash
# capture-shell-init.test.sh — managed rc should not flag template-owned inits as DUPLICATE.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL=0
TEST_HOME=$(mktemp -d)
trap 'rm -rf "$TEST_HOME"' EXIT

cp "$ROOT/templates/zshrc" "$TEST_HOME/.zshrc"

out=$(HOME="$TEST_HOME" CONFIG_DIR="$ROOT" bash "$ROOT/bin/capture-shell-init.sh" 2>&1 || true)

if printf '%s' "$out" | grep -q 'DUPLICATE.*templates/zshrc'; then
    printf 'FAIL managed zshrc should not report DUPLICATE for template-owned inits\n' >&2
    printf '%s\n' "$out" >&2
    FAIL=$((FAIL + 1))
else
    printf 'ok   managed zshrc skips template-owned DUPLICATE noise\n'
fi

# Installer PATH pollution on managed rc should still flag (not template-owned)
echo '. "$HOME/.cargo/env"' >> "$TEST_HOME/.zshrc"
out2=$(HOME="$TEST_HOME" CONFIG_DIR="$ROOT" bash "$ROOT/bin/capture-shell-init.sh" 2>&1 || true)
if printf '%s' "$out2" | grep -q 'DUPLICATE.*core/path.contract'; then
    printf 'ok   extra PATH init on managed rc still flagged\n'
else
    printf 'FAIL extra cargo env should be DUPLICATE\n' >&2
    printf '%s\n' "$out2" >&2
    FAIL=$((FAIL + 1))
fi

# Managed profile: GPG lines from template are OK; installer PATH hooks are not.
cp "$ROOT/templates/zshrc" "$TEST_HOME/.zshrc"
cp "$ROOT/templates/login/profile" "$TEST_HOME/.profile"
out3=$(HOME="$TEST_HOME" CONFIG_DIR="$ROOT" bash "$ROOT/bin/capture-shell-init.sh" 2>&1 || true)
profile_out=$(printf '%s' "$out3" | awk '/Scanning.*\.profile$/{p=1} p && /Scanning/{if (!/\.profile$/) exit} p')
if printf '%s' "$profile_out" | grep -q 'DUPLICATE'; then
    printf 'FAIL managed profile should not report DUPLICATE for template lines\n' >&2
    printf '%s\n' "$out3" >&2
    FAIL=$((FAIL + 1))
else
    printf 'ok   managed profile skips template-owned lines\n'
fi

echo '. "$HOME/.cargo/env"' >> "$TEST_HOME/.profile"
out4=$(HOME="$TEST_HOME" CONFIG_DIR="$ROOT" bash "$ROOT/bin/capture-shell-init.sh" 2>&1 || true)
profile_out2=$(printf '%s' "$out4" | awk '/Scanning.*\.profile$/{p=1} p && /Scanning/{if (!/\.profile$/) exit} p')
if printf '%s' "$profile_out2" | grep -q 'DUPLICATE.*core/path.contract'; then
    printf 'ok   extra cargo env on managed profile still flagged\n'
else
    printf 'FAIL extra cargo env on profile should be DUPLICATE\n' >&2
    printf '%s\n' "$out4" >&2
    FAIL=$((FAIL + 1))
fi

echo "=== $FAIL failure(s) ==="
[[ "$FAIL" -eq 0 ]]
