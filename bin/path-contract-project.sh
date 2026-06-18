#!/usr/bin/env sh
# Apply repo .path.contract (phase:project) from direnv — append project bins only.
# Usage in project .envrc: source ~/.config/shell/bin/path-contract-project.sh
# Global machine PATH (core + local contracts) is unchanged; direnv loads this on cd.

SHELL_ROOT="${SHELL_ROOT:-$HOME/.config/shell}"

# shellcheck disable=SC1091
. "$SHELL_ROOT/core/path.sh"

path_contract_apply_project "${PATH_CONTRACT_PROJECT:-$PWD/.path.contract}"
