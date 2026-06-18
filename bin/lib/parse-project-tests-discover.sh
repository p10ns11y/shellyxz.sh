#!/usr/bin/env sh
# POSIX sh test auto-discovery — mirrors parse-project-tests.py discover().
# Usage: parse-project-tests-discover.sh ROOT
# Prints test plan JSON to stdout.

set -e

root="${1:?root}"
root="$(cd "$root" && pwd)"

max_run=2
prio=1
tests=""
add_test() {
    local id="$1" cmd="$2" label="$3" watch="${4:-}"
    local entry
    entry=$(printf '{"id":"%s","priority":%s,"command":"%s","label":"%s"' \
        "$id" "$prio" "$cmd" "$label")
    if [ -n "$watch" ]; then
        entry="${entry},$(printf '"watch_command":"%s"' "$watch")"
    fi
    entry="${entry}}"
    if [ -n "$tests" ]; then
        tests="${tests},${entry}"
    else
        tests="$entry"
    fi
    prio=$((prio + 1))
}

if [ -f "$root/package.json" ]; then
    if [ -f "$root/pnpm-lock.yaml" ]; then
        add_test npm-test "pnpm test" "package.json test script" "pnpm test --watch"
    else
        add_test npm-test "npm test" "package.json test script" "npm test --watch"
    fi
fi

if [ -f "$root/Cargo.toml" ]; then
    add_test cargo-test "cargo test" "Cargo.toml test suite" "cargo watch -x test"
fi

if [ -f "$root/pyproject.toml" ] || [ -f "$root/pytest.ini" ]; then
    add_test pytest pytest "Python pytest suite" pytest
fi

check="$root/bin/check-shell.sh"
if [ -f "$check" ]; then
    add_test shellcheck "$check --shellcheck-only" "shellcheck static analysis"
fi

test_dir="$root/bin/test"
if [ -d "$test_dir" ]; then
    for script in "$test_dir"/*.test.sh; do
        [ -f "$script" ] || continue
        base=$(basename "$script" .test.sh)
        add_test "$base" "$script" "unit test $(basename "$script")"
    done
fi

if [ -f "$check" ]; then
    add_test load-order "$check" "full shell audit"
fi

if [ -z "$tests" ]; then
    tests='{"id":"none","priority":1,"command":"echo at: no tests — add .agents/verification/cockpit.yaml or package.json/Cargo.toml/bin/check-shell.sh","label":"no runner detected"}'
    max_run=0
fi

printf '{"max_run":%s,"tests":[%s]}\n' "$max_run" "$tests"
