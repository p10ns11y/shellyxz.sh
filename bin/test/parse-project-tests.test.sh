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
    python "$PARSER" --root "$TMP"

assert_contains 'tests.yaml fallback' shellcheck \
    python "$PARSER" "$ROOT/.agents/verification/tests.yaml" "$ROOT"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/parse-project-tests.sh"
assert_contains 'bash wrapper returns json' max_run \
    parse_project_tests_json "$ROOT"

assert_ok 'python allowlisted absolute path' \
    python "$PARSER" --run-cmd "$ROOT/bin/check-shell.sh --help"

assert_fail 'python reject shell metachar' \
    python "$PARSER" --run-cmd "echo ok; rm -rf /"

assert_contains 'python --run summary' 'at summary' \
    python "$PARSER" --run --root "$TMP"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/project-tests.sh"
assert_ok 'bash delegates allowlist to python' run_manifest_command "$ROOT/bin/check-shell.sh --help"
assert_fail 'bash delegates reject metachar' run_manifest_command "echo ok; rm -rf /"

assert_contains 'sh discover finds shellcheck' shellcheck \
    sh "$ROOT/bin/lib/parse-project-tests-discover.sh" "$ROOT"

assert_contains 'discover-tests canonical emitter' shellcheck \
    sh "$ROOT/bin/lib/discover-tests.sh" "$ROOT"

assert_contains 'sh discover without python via wrapper' shellcheck \
    env PATH=/usr/bin:/bin bash -c "
        source \"$ROOT/bin/lib/parse-project-tests.sh\"
        parse_project_tests_json \"$ROOT\"
    "

if command -v python >/dev/null 2>&1; then
    sh_norm="$(sh "$ROOT/bin/lib/discover-tests.sh" "$ROOT" | python -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))')"
    py_norm="$(python "$PARSER" --discover "$ROOT" | python -c 'import json,sys; print(json.dumps(json.load(sys.stdin), sort_keys=True))')"
    if [ "$sh_norm" = "$py_norm" ]; then
        printf 'ok   py/sh discover_tests JSON parity\n'
    else
        printf 'FAIL py/sh discover_tests JSON parity\n' >&2
        printf '  sh: %s\n' "$sh_norm" >&2
        printf '  py: %s\n' "$py_norm" >&2
        FAIL=$((FAIL + 1))
    fi
fi

# shellcheck source=/dev/null
source "$ROOT/bin/lib/test-allowlist.sh"
assert_ok 'sh allowlist absolute path' run_allowlisted_command "$ROOT/bin/check-shell.sh --help"
assert_fail 'sh allowlist reject metachar' run_allowlisted_command "echo ok; rm -rf /"
assert_fail 'sh allowlist reject unknown runner' run_allowlisted_command "curl http://evil"

assert_ok 'cockpit-mcp verify on shell repo' \
    "$ROOT/bin/cockpit-mcp.sh" verify "$ROOT"

echo "=== $FAIL failure(s) ==="
[[ "$FAIL" -eq 0 ]]
