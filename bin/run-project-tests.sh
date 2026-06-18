#!/usr/bin/env bash
# Priority-ordered test runner for at — delegates to parse-project-tests.py --run.
# Usage: run-project-tests.sh [directory] [--watch] [--all]
# Requires python3 for cockpit.yaml / tests.yaml manifests.
set -euo pipefail

DIR="."
WATCH=0
RUN_ALL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PY="${SCRIPT_DIR}/lib/parse-project-tests.py"

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
            echo "  Requires python3 for manifest parsing and test execution."
            echo "  Falls back to auto-discovery when no manifest exists."
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

if ! command -v python3 >/dev/null 2>&1; then
    echo "run-project-tests: python3 is required (install python3 or use a project with bin/check-shell.sh only)" >&2
    exit 1
fi

DIR="$(cd "$DIR" && pwd)"

args=(--run --root "$DIR")
if [ "$WATCH" = 1 ]; then
    args+=(--watch)
fi
if [ "$RUN_ALL" = 1 ]; then
    args+=(--all)
fi

exec python3 "$PARSER_PY" "${args[@]}"
