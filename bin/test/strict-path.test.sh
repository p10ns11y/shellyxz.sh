#!/usr/bin/env bash
# strict-path.test.sh — agent_strict_path_check must leave path_shadow_report callable.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=/dev/null
source "$ROOT/bin/lib/verify-launch.sh"

# Regression: PATH="$(agent_strict_path_apply)" ran in subshell and dropped path_shadow_report.
agent_strict_path_check || true

if ! declare -F path_shadow_report >/dev/null 2>&1; then
    echo "FAIL strict-path: path_shadow_report not defined after agent_strict_path_check" >&2
    exit 1
fi

echo "=== strict-path tests passed ==="
