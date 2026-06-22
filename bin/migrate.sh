#!/usr/bin/env bash
# Master Shell Migration — orchestrator (templates are source of truth).
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FORCE_RC=false
SYNC_RC=false
BOOTSTRAP=false
for arg in "$@"; do
    case "$arg" in
        --force-rc) FORCE_RC=true ;;
        --sync-rc) SYNC_RC=true; FORCE_RC=false ;;
        --bootstrap) BOOTSTRAP=true ;;
        -h|--help)
            cat <<EOF
Usage: migrate.sh [--force-rc] [--sync-rc] [--bootstrap]

  --force-rc   Overwrite all managed dotfiles (even hand-edited)
  --sync-rc    Refresh managed dotfiles that already have the migrate marker
  --bootstrap  Fetch missing repo files from SHELL_CONFIG_RAW

One-liner: curl -fsSL \${SHELL_CONFIG_RAW}/bin/migrate.sh | bash
EOF
            exit 0
            ;;
    esac
done

export CONFIG_DIR FORCE_RC SYNC_RC
# shellcheck disable=SC1091
source "$SCRIPT_DIR/lib/migrate-common.sh"

if [[ "$BOOTSTRAP" == true ]] || is_piped_install || config_needs_bootstrap; then
    bootstrap_from_remote || true
fi

echo "==================================================================="
echo "  Shell Migration — modular core + environments"
echo "==================================================================="
log "Config dir: $CONFIG_DIR"
echo ""

# Self-install migrate.sh into repo
TARGET_SCRIPT="$CONFIG_DIR/bin/migrate.sh"
SCRIPT_SRC="$(realpath "${BASH_SOURCE[0]}" 2>/dev/null || echo "$SCRIPT_DIR/migrate.sh")"
if [[ "$SCRIPT_SRC" != "$TARGET_SCRIPT" ]] && [[ -f "$SCRIPT_SRC" ]]; then
    mkdir -p "$CONFIG_DIR/bin/lib" "$CONFIG_DIR/bin/tasks"
    cp "$SCRIPT_SRC" "$TARGET_SCRIPT" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/lib" "$SCRIPT_DIR/tasks" "$CONFIG_DIR/bin/" 2>/dev/null || true
    chmod +x "$CONFIG_DIR/bin/migrate.sh" "$CONFIG_DIR/bin/tasks/"*.sh 2>/dev/null || true
fi

PLUGIN_SRC="$(cd "$SCRIPT_DIR/../plugins/verification" 2>/dev/null && pwd || true)"
if [[ -n "$PLUGIN_SRC" ]] && [[ -d "$PLUGIN_SRC" ]]; then
    mkdir -p "$CONFIG_DIR/plugins"
    cp -a "$PLUGIN_SRC" "$CONFIG_DIR/plugins/verification" 2>/dev/null || true
    chmod +x "$CONFIG_DIR/plugins/verification/bin/"*.sh 2>/dev/null || true
    chmod +x "$CONFIG_DIR/bin/agent-"*.sh "$CONFIG_DIR/bin/cockpit-mcp.sh" 2>/dev/null || true
fi

export BACKUP_DIR
BACKUP_DIR="$CONFIG_DIR/backups/$(date +%Y%m%d-%H%M%S)"
# shellcheck disable=SC1091
source "$CONFIG_DIR/bin/tasks/backup.sh"
# shellcheck disable=SC1091
source "$CONFIG_DIR/bin/tasks/install-tools.sh"
# shellcheck disable=SC1091
source "$CONFIG_DIR/bin/tasks/install-modules.sh"
# shellcheck disable=SC1091
source "$CONFIG_DIR/bin/tasks/install-rc.sh"
# shellcheck disable=SC1091
source "$CONFIG_DIR/bin/tasks/scaffold.sh"
# shellcheck disable=SC1091
source "$CONFIG_DIR/bin/tasks/git-commit.sh"

echo ""
success "Migration complete!"
echo ""
echo "Next steps:"
echo "  1. Optional pin: cp ~/.config/shell/environment.example ~/.config/shell/environment"
echo "  2. Reload: source ~/.zshrc"
echo "  3. Verify: ~/.config/shell/bin/check-shell.sh"
echo "  4. Revert: $BACKUP_DIR/revert.sh"
echo ""
echo "Presets: generic (containers/VPS/CI) | omarchy (auto-detected desktop)"
echo "Force rc: ~/.config/shell/bin/migrate.sh --force-rc"
echo "==================================================================="
