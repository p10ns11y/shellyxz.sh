#!/usr/bin/env bash
# Resolve test plan JSON via parse-project-tests.py (python required).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PY="${SCRIPT_DIR}/parse-project-tests.py"

parse_project_tests_json() {
    local root="${1:?root}"

    if ! command -v python >/dev/null 2>&1; then
        echo "parse-project-tests: python is required for cockpit.yaml / tests.yaml" >&2
        printf '{"max_run":0,"tests":[{"id":"none","priority":1,"command":"echo at: install python for test discovery","label":"python required"}]}\n'
        return 1
    fi

    if [ ! -f "$PARSER_PY" ]; then
        echo "parse-project-tests: missing $PARSER_PY" >&2
        return 1
    fi

    local cockpit="${root}/.agents/verification/cockpit.yaml"
    local tests="${root}/.agents/verification/tests.yaml"

    if [ -f "$cockpit" ] || [ -f "$tests" ]; then
        python "$PARSER_PY" --root "$root"
    else
        python "$PARSER_PY" --discover "$root"
    fi
}
