#!/usr/bin/env bash
# Nuclear recovery when rc files are broken or source loops fail.
# Works from a graphical terminal, SSH, or TTY without loading ~/.zshrc.
#
# Usage:
#   bash ~/.config/shell/bin/recover-shell.sh
#   bash --norc ~/.config/shell/bin/recover-shell.sh   # if ~/.bashrc is also broken
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${HOME}/.local/bin:${HOME}/bin"

echo "=== shell nuclear recovery ==="
echo ""
echo "Minimal PATH is set. You are NOT in your normal shell config."
echo ""

latest_backup=""
if [ -d "$CONFIG_DIR/backups" ]; then
    latest_backup=$(find "$CONFIG_DIR/backups" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)
fi

echo "Options:"
echo "  1. Restore dotfiles from latest backup"
if [ -n "$latest_backup" ] && [ -x "$latest_backup/revert.sh" ]; then
    echo "       $latest_backup/revert.sh"
else
    echo "       (no backups found under $CONFIG_DIR/backups/)"
fi
echo ""
echo "  2. Start a clean shell (no rc files)"
echo "       exec zsh -f"
echo "       exec bash --norc"
echo ""
echo "  3. Edit portable modules directly (no rc required)"
echo "       \$EDITOR $CONFIG_DIR/env.sh"
echo "       \$EDITOR $CONFIG_DIR/aliases.sh"
echo ""
echo "  4. Regenerate managed rc files after fixing modules"
echo "       $CONFIG_DIR/bin/migrate.sh --force-rc"
echo ""
echo "  5. Verify when stable"
echo "       $CONFIG_DIR/bin/check-shell.sh"
echo ""
echo "Tip: if even bash is broken, run:  /usr/bin/bash --norc"
echo "     then point it at this script with the full path above."
