#!/usr/bin/env bash
# Backup dotfiles and write revert.sh

BACKUP_DIR="${BACKUP_DIR:-$HOME/.config/shell/backups/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$BACKUP_DIR"

backup_file() {
    local file="$1"
    if [[ -f "$file" || -L "$file" ]]; then
        cp -a "$file" "$BACKUP_DIR/" 2>/dev/null || true
        log "Backed up: $file"
    fi
}

backup_file "$HOME/.bashrc"
backup_file "$HOME/.bash_profile"
backup_file "$HOME/.profile"
backup_file "$HOME/.zshrc"
backup_file "$HOME/.zprofile"
backup_file "$HOME/.zshenv"
backup_file "$HOME/.config/starship.toml"

cat > "$BACKUP_DIR/revert.sh" << REVERT_EOF
#!/usr/bin/env bash
BACKUP_DIR="\$(dirname "\$(realpath "\$0")")"
echo "Reverting dotfiles from backup: \$BACKUP_DIR"
cp -a "\$BACKUP_DIR/.bashrc" "$HOME/.bashrc" 2>/dev/null || true
cp -a "\$BACKUP_DIR/.zshrc" "$HOME/.zshrc" 2>/dev/null || true
cp -a "\$BACKUP_DIR/.zprofile" "$HOME/.zprofile" 2>/dev/null || true
cp -a "\$BACKUP_DIR/.zshenv" "$HOME/.zshenv" 2>/dev/null || true
cp -a "\$BACKUP_DIR/.bash_profile" "$HOME/.bash_profile" 2>/dev/null || true
cp -a "\$BACKUP_DIR/.profile" "$HOME/.profile" 2>/dev/null || true
cp -a "\$BACKUP_DIR/starship.toml" "$HOME/.config/starship.toml" 2>/dev/null || true
echo "Revert complete. Restart your terminal to see changes."
REVERT_EOF
chmod +x "$BACKUP_DIR/revert.sh"
success "Backup created at: $BACKUP_DIR"
