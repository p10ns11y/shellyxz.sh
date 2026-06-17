#!/usr/bin/env bash
# Resolve a one-shot or watch test command for the current project root.
set -euo pipefail

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
