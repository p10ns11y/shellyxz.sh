#!/usr/bin/env bash
# Priority-ordered test runner for at — top max_run from cockpit.yaml / tests.yaml.
# Usage: run-project-tests.sh [directory] [--watch] [--all]
set -euo pipefail

DIR="."
WATCH=0
RUN_ALL=0
INTERVAL="${TEST_WATCH_INTERVAL:-60}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/lib/project-tests.sh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --watch)
            WATCH=1
            shift
            ;;
        --all)
            RUN_ALL=1
            shift
            ;;
        -h | --help)
            echo "Usage: run-project-tests.sh [directory] [--watch] [--all]"
            echo "  Reads .agents/verification/cockpit.yaml (or tests.yaml)."
            echo "  Falls back to auto-discovery (package.json, Cargo.toml, bin/test/*.test.sh)."
            echo "  --all   Run every test in the manifest (ignore max_run)."
            exit 0
            ;;
        *)
            if [ "$DIR" = . ] && { [ "$1" = . ] || [ -d "$1" ]; }; then
                DIR="$1"
                shift
            else
                echo "run-project-tests: unknown argument: $1" >&2
                exit 1
            fi
            ;;
    esac
done

DIR="$(cd "$DIR" && pwd)"

load_plan() {
    parse_project_tests_json "$DIR"
}

json_field() {
    local json="$1" py="$2"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$json" | python3 -c "$py"
    else
        case "$py" in
            *max_run*) printf '%s' "$json" | sed -n 's/.*"max_run":\([0-9]*\).*/\1/p' | head -1 ;;
            *len*) printf '%s' "$json" | grep -o '"id"' | wc -l | tr -d ' ' ;;
        esac
    fi
}

first_watch_command() {
    local json="$1"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for t in data.get("tests", []):
    w = t.get("watch_command")
    if w:
        print(w)
        break
'
    fi
}

run_plan() {
    local json="$1"
    local max_run failures=0 run=0 total id label cmd watch_cmd

    max_run="$(json_field "$json" 'import json,sys; print(json.load(sys.stdin)["max_run"])')"
    total="$(json_field "$json" 'import json,sys; print(len(json.load(sys.stdin)["tests"]))')"
    if [ "$RUN_ALL" = 1 ]; then
        max_run="$total"
    fi

    echo "=== at: running top ${max_run} test(s) (max_run=${max_run}) ==="

    while IFS=$'\t' read -r id prio label cmd _watch_cmd; do
        if [ "$run" -ge "$max_run" ]; then
            break
        fi
        run=$((run + 1))
        printf '\n── [%s/%s] %s (priority %s) ──\n' "$run" "$max_run" "$id" "$prio"
        printf '    %s\n' "$label"
        if ! run_manifest_command "$cmd"; then
            failures=$((failures + 1))
        fi
    done < <(
        if command -v python3 >/dev/null 2>&1; then
            printf '%s' "$json" | python3 -c '
import json, sys
for t in json.load(sys.stdin)["tests"]:
    print("\t".join([
        t.get("id", ""),
        str(t.get("priority", "")),
        t.get("label", t.get("id", "")),
        t.get("command", ""),
        t.get("watch_command", ""),
    ]))
'
        else
            printf '%s' "$json" | sed 's/^{//;s/}$//' # minimal: fallback runs one-shot only
        fi
    )

    if [ "$total" -gt "$max_run" ] && [ "$RUN_ALL" != 1 ]; then
        echo ""
        echo "=== at: also available (not run) ==="
        if command -v python3 >/dev/null 2>&1; then
            printf '%s' "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
max_run = data['max_run']
for t in data['tests'][max_run:]:
    prio = t.get('priority', '?')
    tid = t.get('id', '?')
    label = t.get('label', '')
    cmd = t.get('command', '')
    print(f\"  [{prio}] {tid} — {label}\")
    print(f\"      run: {cmd}\")
print('  tip:   bin/run-project-tests.sh --all')
"
        fi
    fi

    echo ""
    if [ "$failures" -eq 0 ]; then
        echo "=== at summary: ${run} run, 0 failed ==="
    else
        echo "=== at summary: ${run} run, ${failures} failed ==="
    fi
    return "$failures"
}

run_once() {
    local json failures
    json="$(load_plan)"
    run_plan "$json"
    failures=$?
    return "$failures"
}

if [ "$WATCH" = 1 ]; then
    json="$(load_plan)"
    watch_cmd="$(first_watch_command "$json")"
    if [ -n "$watch_cmd" ]; then
        echo "=== at watch: ${watch_cmd} ==="
        exec bash -c "$watch_cmd"
    fi
    run_once || true
    while true; do
        sleep "$INTERVAL"
        printf '\n── at watch %s ──\n' "$(date '+%Y-%m-%d %H:%M:%S')"
        run_once || true
    done
else
    run_once
fi
