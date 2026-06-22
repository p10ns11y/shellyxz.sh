#!/usr/bin/env bash
# Resolve test plan JSON — python for manifests, sh for auto-discovery.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PY="${SCRIPT_DIR}/parse-project-tests.py"

parse_project_tests_json() {
    local root="${1:?root}"
    local cockpit="${root}/.agents/verification/cockpit.yaml"
    local tests="${root}/.agents/verification/tests.yaml"

    if command -v python >/dev/null 2>&1 && [ -f "$PARSER_PY" ]; then
        if [ -f "$cockpit" ] || [ -f "$tests" ]; then
            python "$PARSER_PY" --root "$root"
            return $?
        fi
        python "$PARSER_PY" --discover "$root"
        return $?
    fi

    if [ -f "$cockpit" ] || [ -f "$tests" ]; then
        echo "parse-project-tests: python required for cockpit.yaml/tests.yaml — using sh auto-discovery" >&2
        echo "parse-project-tests: install python for full manifest support, or use bin/check-shell.sh discovery" >&2
    fi

    sh "$SCRIPT_DIR/parse-project-tests-discover.sh" "$root"
}
