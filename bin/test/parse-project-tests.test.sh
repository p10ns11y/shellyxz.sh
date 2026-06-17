#!/usr/bin/env bash
# parse-project-tests.test.sh — parser + allowlist smoke tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL=0
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

assert_contains() {
    local desc="$1" needle="$2"
    shift 2
    local out
    out="$("$@" 2>/dev/null || true)"
    if [[ "$out" == *"$needle"* ]]; then
        printf 'ok   %s\n' "$desc"
    else
        printf 'FAIL %s (missing %s)\n' "$desc" "$needle" >&2
        FAIL=$((FAIL + 1))
    fi
}

mkdir -p "$TMP/.agents/verification"
cp "$ROOT/.agents/verification/cockpit.yaml" "$TMP/.agents/verification/"

assert_contains 'cockpit.yaml parses shellcheck' shellcheck \
    python3 "$ROOT/bin/lib/parse-project-tests.py" --root "$TMP"

assert_contains 'tests.yaml fallback' shellcheck \
    python3 "$ROOT/bin/lib/parse-project-tests.py" "$ROOT/.agents/verification/tests.yaml" "$ROOT"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/parse-project-tests.sh"
assert_contains 'bash wrapper returns json' max_run \
    parse_project_tests_json "$ROOT"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/project-tests.sh"
assert_ok 'allowlisted absolute path' run_manifest_command "$ROOT/bin/check-shell.sh --help"
assert_ok 'reject shell metachar' sh -c '! run_manifest_command "echo ok; rm -rf /"'

echo "=== $FAIL failure(s) ==="
[[ "$FAIL" -eq 0 ]]
