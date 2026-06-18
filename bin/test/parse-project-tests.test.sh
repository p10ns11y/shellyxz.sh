#!/usr/bin/env bash
# parse-project-tests.test.sh — parser + allowlist + runner smoke tests.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARSER="$ROOT/bin/lib/parse-project-tests.py"
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
    python3 "$PARSER" --root "$TMP"

assert_contains 'tests.yaml fallback' shellcheck \
    python3 "$PARSER" "$ROOT/.agents/verification/tests.yaml" "$ROOT"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/parse-project-tests.sh"
assert_contains 'bash wrapper returns json' max_run \
    parse_project_tests_json "$ROOT"

assert_ok 'python allowlisted absolute path' \
    python3 "$PARSER" --run-cmd "$ROOT/bin/check-shell.sh --help"

assert_fail 'python reject shell metachar' \
    python3 "$PARSER" --run-cmd "echo ok; rm -rf /"

assert_contains 'python --run summary' 'at summary' \
    python3 "$PARSER" --run --root "$TMP"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/project-tests.sh"
assert_ok 'bash delegates allowlist to python' run_manifest_command "$ROOT/bin/check-shell.sh --help"
assert_fail 'bash delegates reject metachar' run_manifest_command "echo ok; rm -rf /"

echo "=== $FAIL failure(s) ==="
[[ "$FAIL" -eq 0 ]]
