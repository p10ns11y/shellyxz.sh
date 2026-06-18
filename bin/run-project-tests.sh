#!/usr/bin/env bash
# Priority-ordered test runner for at — python for manifests, sh fallback for discovery.
# Usage: run-project-tests.sh [directory] [--watch] [--all]
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
            echo "  Reads .agents/verification/cockpit.yaml (or tests.yaml) when python is available."
            echo "  Without python: sh auto-discovery (package.json, Cargo.toml, bin/test/*.sh, check-shell.sh)."
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
cockpit="${DIR}/.agents/verification/cockpit.yaml"
tests_yaml="${DIR}/.agents/verification/tests.yaml"

if command -v python >/dev/null 2>&1 && [ -f "$PARSER_PY" ]; then
    args=(--run --root "$DIR")
    [ "$WATCH" = 1 ] && args+=(--watch)
    [ "$RUN_ALL" = 1 ] && args+=(--all)
    exec python "$PARSER_PY" "${args[@]}"
fi

if [ -f "$cockpit" ] || [ -f "$tests_yaml" ]; then
    echo "run-project-tests: python not found — cockpit.yaml/tests.yaml need python; trying sh auto-discovery" >&2
fi

args=(--root "$DIR")
[ "$WATCH" = 1 ] && args+=(--watch)
[ "$RUN_ALL" = 1 ] && args+=(--all)
exec bash "$SCRIPT_DIR/lib/parse-project-tests-run.sh" "${args[@]}"
