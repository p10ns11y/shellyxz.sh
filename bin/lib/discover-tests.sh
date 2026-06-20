#!/usr/bin/env sh
# Canonical test discovery — discover_tests(root) → JSON.
# Mirrors parse-project-tests.py discover(); consumed by run-project-tests.sh and parse-project-tests.sh.
# Usage: discover-tests.sh ROOT   OR   source and call discover_tests "$root"

set -e

DISCOVER_MAX_RUN=2
DISCOVER_TESTS_JSON=''

_discover_tests_reset() {
    DISCOVER_MAX_RUN=2
    DISCOVER_TESTS_JSON=''
    DISCOVER_TEST_IDS=''
    DISCOVER_TEST_CMDS=''
    DISCOVER_TEST_LABELS=''
    DISCOVER_TEST_WATCH=''
    _discover_prio=1
}

_discover_tests_add() {
    local id="$1" cmd="$2" label="$3" watch="${4:-}"
    local entry sep
    entry=$(printf '{"id":"%s","priority":%s,"command":"%s","label":"%s"' \
        "$id" "$_discover_prio" "$cmd" "$label")
    if [ -n "$watch" ]; then
        entry="${entry},$(printf '"watch_command":"%s"' "$watch")"
    fi
    entry="${entry}}"
    if [ -n "$DISCOVER_TESTS_JSON" ]; then
        sep=','
    else
        sep=''
    fi
    DISCOVER_TESTS_JSON="${DISCOVER_TESTS_JSON}${sep}${entry}"
    DISCOVER_TEST_IDS="${DISCOVER_TEST_IDS}${DISCOVER_TEST_IDS:+|}$id"
    DISCOVER_TEST_CMDS="${DISCOVER_TEST_CMDS}${DISCOVER_TEST_CMDS:+|}$cmd"
    DISCOVER_TEST_LABELS="${DISCOVER_TEST_LABELS}${DISCOVER_TEST_LABELS:+|}$label"
    DISCOVER_TEST_WATCH="${DISCOVER_TEST_WATCH}${DISCOVER_TEST_WATCH:+|}${watch:-}"
    _discover_prio=$((_discover_prio + 1))
}

discover_tests_collect() {
    local root="${1:?root}"
    root="$(cd "$root" && pwd)"
    local check test_dir base script

    _discover_tests_reset

    if [ -f "$root/package.json" ]; then
        if [ -f "$root/pnpm-lock.yaml" ]; then
            _discover_tests_add npm-test "pnpm test" "package.json test script" "pnpm test --watch"
        else
            _discover_tests_add npm-test "npm test" "package.json test script" "npm test --watch"
        fi
    fi

    if [ -f "$root/Cargo.toml" ]; then
        _discover_tests_add cargo-test "cargo test" "Cargo.toml test suite" "cargo watch -x test"
    fi

    if [ -f "$root/pyproject.toml" ] || [ -f "$root/pytest.ini" ]; then
        _discover_tests_add pytest pytest "Python pytest suite" pytest
    fi

    check="$root/bin/check-shell.sh"
    if [ -f "$check" ]; then
        _discover_tests_add shellcheck "$check --shellcheck-only" "shellcheck static analysis"
    fi

    test_dir="$root/bin/test"
    if [ -d "$test_dir" ]; then
        for script in "$test_dir"/*.test.sh; do
            [ -f "$script" ] || continue
            base=$(basename "$script" .test.sh)
            _discover_tests_add "$base" "$script" "unit test $(basename "$script")"
        done
    fi

    if [ -f "$check" ]; then
        _discover_tests_add load-order "$check" "full shell audit"
    fi

    if [ -z "$DISCOVER_TESTS_JSON" ]; then
        _discover_tests_add none "echo 'at: no tests — add .agents/verification/cockpit.yaml or package.json/Cargo.toml/bin/check-shell.sh'" "no runner detected"
        DISCOVER_MAX_RUN=0
    fi
}

discover_tests() {
    discover_tests_collect "$1"
    printf '{"max_run":%s,"tests":[%s]}\n' "$DISCOVER_MAX_RUN" "$DISCOVER_TESTS_JSON"
}

if [ "$(basename "$0")" = "discover-tests.sh" ]; then
    discover_tests "${1:?root}"
fi
