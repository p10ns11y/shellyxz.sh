#!/usr/bin/env bash
# Resolve a one-shot or watch test command for the current project root.
set -euo pipefail

project_test_cmd() {
    local root="${1:?root}"
    local mode="${2:-once}"

    if [ -f "$root/package.json" ] && command -v pnpm >/dev/null 2>&1; then
        if [ "$mode" = watch ]; then
            printf '%s' 'pnpm test --watch'
        else
            printf '%s' 'pnpm test'
        fi
        return 0
    fi

    if [ -f "$root/Cargo.toml" ] && command -v cargo >/dev/null 2>&1; then
        if [ "$mode" = watch ] && command -v cargo-watch >/dev/null 2>&1; then
            printf '%s' 'cargo watch -x test'
        else
            printf '%s' 'cargo test'
        fi
        return 0
    fi

    if [ -x "$root/bin/check-shell.sh" ]; then
        if [ "$mode" = watch ]; then
            printf '%s' "TEST_WATCH_INTERVAL=\${TEST_WATCH_INTERVAL:-60} $root/bin/project-test-watch.sh"
        else
            printf '%s' "$root/bin/check-shell.sh"
        fi
        return 0
    fi

    printf '%s' "echo 'tt: no test runner — add package.json, Cargo.toml, or bin/check-shell.sh'"
}
