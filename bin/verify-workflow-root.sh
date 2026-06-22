#!/usr/bin/env bash
# Print canonical workflow root for ab / av / agent_scan.
# Usage: verify-workflow-root.sh [directory]
set -euo pipefail

DIR="${1:-.}"

# shellcheck source=/dev/null
source "${SHELL_VERIFICATION_LIB:-${SHELL_ROOT:-$HOME/.config/shell}/plugins/verification/lib}/verify-launch.sh"

verify_workflow_root "$DIR"
