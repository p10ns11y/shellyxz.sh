#!/usr/bin/env bash
# Print canonical workflow root for ab / av / agent_scan.
# Usage: verify-workflow-root.sh [directory]
set -euo pipefail

DIR="${1:-.}"
SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"

# shellcheck source=/dev/null
. "${SHELL_ROOT}/core/lib.sh"
verification_lib="$(verification_lib_dir)" || {
    echo "verify-workflow-root: missing plugins/verification/lib/verify-launch.sh" >&2
    exit 1
}

# shellcheck source=/dev/null
source "${verification_lib}/verify-launch.sh"

verify_workflow_root "$DIR"
