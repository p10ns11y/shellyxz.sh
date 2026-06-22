#!/usr/bin/env bash
# Resolve a one-shot or watch test command for the current project root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/parse-project-tests.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/test-allowlist.sh"

# Run a manifest command (allowlist: parse-project-tests.py or sh mirror).
run_manifest_command() {
    local cmd="$1"
    if command -v python >/dev/null 2>&1 && [ -f "${SCRIPT_DIR}/parse-project-tests.py" ]; then
        python "${SCRIPT_DIR}/parse-project-tests.py" --run-cmd "$cmd"
        return $?
    fi
    run_allowlisted_command "$cmd"
}

project_test_cmd() {
    local root="${1:?root}"
    local mode="${2:-once}"
    local runner="${root}/bin/run-project-tests.sh"
    local shell_root="${SHELL_ROOT:-$HOME/.config/shell}"

    if [ ! -x "$runner" ]; then
        # shellcheck source=/dev/null
        . "${shell_root}/core/lib.sh"
        runner="$(verification_script_path run-project-tests.sh 2>/dev/null || true)"
    fi

    if [ -z "$runner" ] || [ ! -x "$runner" ]; then
        printf '%s' "echo 'at: missing run-project-tests.sh'"
        return 0
    fi

    if [ "$mode" = watch ]; then
        printf '%s' "TEST_WATCH_INTERVAL=\${TEST_WATCH_INTERVAL:-60} $(printf '%q' "$runner") --watch"
    else
        printf '%s' "$(printf '%q' "$runner")"
    fi
}
