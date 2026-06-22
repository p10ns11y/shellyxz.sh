#!/usr/bin/env bash
# Run auto-discovered tests without python — consumes discover_tests JSON + shared allowlist.
# Usage: parse-project-tests-run.sh --root DIR [--watch] [--all]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/test-allowlist.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/discover-tests.sh"

ROOT="."
WATCH=0
RUN_ALL=0

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
discover_tests_collect "$ROOT"

declare -a TEST_IDS=() TEST_CMDS=() TEST_LABELS=() TEST_WATCH=()
if [ -n "${DISCOVER_TEST_IDS:-}" ]; then
    IFS='|' read -r -a TEST_IDS <<< "$DISCOVER_TEST_IDS"
    IFS='|' read -r -a TEST_CMDS <<< "$DISCOVER_TEST_CMDS"
    IFS='|' read -r -a TEST_LABELS <<< "$DISCOVER_TEST_LABELS"
    IFS='|' read -r -a TEST_WATCH <<< "$DISCOVER_TEST_WATCH"
fi
MAX_RUN="$DISCOVER_MAX_RUN"

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
            run_allowlisted_command "$watch_cmd" || true
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
    if ! run_allowlisted_command "${TEST_CMDS[$i]}"; then
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
