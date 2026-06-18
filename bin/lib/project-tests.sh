#!/usr/bin/env bash
# Resolve a one-shot or watch test command for the current project root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/parse-project-tests.sh"

# Run a manifest command (allowlist: parse-project-tests.py or sh mirror).
run_manifest_command() {
    local cmd="$1" first
    if command -v python >/dev/null 2>&1 && [ -f "${SCRIPT_DIR}/parse-project-tests.py" ]; then
        python "${SCRIPT_DIR}/parse-project-tests.py" --run-cmd "$cmd"
        return $?
    fi
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    case "$cmd" in
        *';'*|*'|'*|*'`'*|*'$('*|*'>'*|*'<'*)
            echo "run-project-tests: rejected command: $cmd" >&2
            return 1
            ;;
    esac
    first="${cmd%% *}"
    case "$first" in
        bin/*|./*|/*|pnpm|npm|cargo|pytest|python|python3|bash|sh|echo) ;;
        *)
            echo "run-project-tests: command not allowlisted: $first" >&2
            return 1
            ;;
    esac
    bash -c "$cmd"
}

project_test_cmd() {
    local root="${1:?root}"
    local mode="${2:-once}"
    local runner="${root}/bin/run-project-tests.sh"

    if [ ! -x "$runner" ]; then
        runner="$HOME/.config/shell/bin/run-project-tests.sh"
    fi

    if [ ! -x "$runner" ]; then
        printf '%s' "echo 'at: missing run-project-tests.sh'"
        return 0
    fi

    if [ "$mode" = watch ]; then
        printf '%s' "TEST_WATCH_INTERVAL=\${TEST_WATCH_INTERVAL:-60} $(printf '%q' "$runner") --watch"
    else
        printf '%s' "$(printf '%q' "$runner")"
    fi
}
