#!/usr/bin/env bash
# Run auto-discovered tests without python (allowlist + same rules as discover.sh).
# Usage: parse-project-tests-run.sh --root DIR [--watch] [--all]
set -euo pipefail

ROOT="."
WATCH=0
RUN_ALL=0
MAX_RUN=2

while [[ $# -gt 0 ]]; do
    case "$1" in
        --root)
            ROOT="${2:?}"
            shift 2
            ;;
        --watch) WATCH=1; shift ;;
        --all) RUN_ALL=1; shift ;;
        *) echo "parse-project-tests-run: unknown argument: $1" >&2; exit 1 ;;
    esac
done

ROOT="$(cd "$ROOT" && pwd)"

command_allowed() {
    local cmd="$1" first
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    [ -n "$cmd" ] || return 1
    case "$cmd" in
        *';'*|*'|'*|*'`'*|*'$('*|*'>'*|*'<'*) return 1 ;;
    esac
    first="${cmd%% *}"
    case "$first" in
        bin/*|./*|/*|pnpm|npm|cargo|pytest|python|python3|bash|sh|echo) return 0 ;;
        *) return 1 ;;
    esac
}

run_cmd() {
    local cmd="$1"
    if ! command_allowed "$cmd"; then
        echo "run-project-tests: rejected or not allowlisted: $cmd" >&2
        return 1
    fi
    bash -c "$cmd"
}

declare -a TEST_IDS=() TEST_CMDS=() TEST_LABELS=() TEST_WATCH=()
prio=1

add_test() {
    TEST_IDS+=("$1")
    TEST_CMDS+=("$2")
    TEST_LABELS+=("$3")
    TEST_WATCH+=("${4:-}")
    prio=$((prio + 1))
}

if [ -f "$ROOT/package.json" ]; then
    if [ -f "$ROOT/pnpm-lock.yaml" ]; then
        add_test npm-test "pnpm test" "package.json test script" "pnpm test --watch"
    else
        add_test npm-test "npm test" "package.json test script" "npm test --watch"
    fi
fi

if [ -f "$ROOT/Cargo.toml" ]; then
    add_test cargo-test "cargo test" "Cargo.toml test suite" "cargo watch -x test"
fi

if [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/pytest.ini" ]; then
    add_test pytest pytest "Python pytest suite" pytest
fi

check="$ROOT/bin/check-shell.sh"
if [ -f "$check" ]; then
    add_test shellcheck "$check --shellcheck-only" "shellcheck static analysis"
fi

if [ -d "$ROOT/bin/test" ]; then
    for script in "$ROOT/bin/test"/*.test.sh; do
        [ -f "$script" ] || continue
        base=$(basename "$script" .test.sh)
        add_test "$base" "$script" "unit test $(basename "$script")"
    done
fi

if [ -f "$check" ]; then
    add_test load-order "$check" "full shell audit"
fi

if [ "${#TEST_IDS[@]}" -eq 0 ]; then
    add_test none "echo 'at: no tests — add .agents/verification/cockpit.yaml or package.json/Cargo.toml/bin/check-shell.sh'" "no runner detected"
    MAX_RUN=0
fi

if [ "$RUN_ALL" = 1 ]; then
    limit="${#TEST_IDS[@]}"
else
    limit="$MAX_RUN"
    [ "$limit" -le "${#TEST_IDS[@]}" ] || limit="${#TEST_IDS[@]}"
fi

if [ "$WATCH" = 1 ]; then
    watch_cmd=""
    for w in "${TEST_WATCH[@]}"; do
        [ -n "$w" ] && watch_cmd="$w" && break
    done
    if [ -n "$watch_cmd" ]; then
        echo "=== at watch: $watch_cmd ==="
        while true; do
            run_cmd "$watch_cmd" || true
            sleep "${TEST_WATCH_INTERVAL:-60}"
        done
    fi
    echo "=== at watch: no watch_command — running once ==="
fi

echo "=== at: running top ${limit} test(s) (sh discovery) ==="
failures=0
i=0
while [ "$i" -lt "$limit" ]; do
    run=$((i + 1))
    echo ""
    echo "── [$run/$limit] ${TEST_IDS[$i]} (priority $((i + 1))) ──"
    echo "    ${TEST_LABELS[$i]}"
    if ! run_cmd "${TEST_CMDS[$i]}"; then
        failures=$((failures + 1))
    fi
    i=$((i + 1))
done

echo ""
if [ "$failures" -eq 0 ]; then
    echo "=== at summary: $limit run, 0 failed ==="
else
    echo "=== at summary: $limit run, $failures failed ==="
fi
exit "$failures"
