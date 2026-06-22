#!/usr/bin/env bash
# Scaffold starship, tmux, yazi, git verification configs.

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"

STARSHIP_DEST="$HOME/.config/starship.toml"
mkdir -p "$HOME/.config"
if [[ ! -f "$STARSHIP_DEST" ]] && [[ -f "$CONFIG_DIR/starship.ex.toml" ]]; then
    cp "$CONFIG_DIR/starship.ex.toml" "$STARSHIP_DEST"
    log "Installed ~/.config/starship.toml from starship.ex.toml"
fi

TMUX_DIR="$HOME/.config/tmux"
OMARCHY_TMUX="$OMARCHY_PATH/config/tmux/tmux.conf"
mkdir -p "$TMUX_DIR"

if [[ ! -f "$TMUX_DIR/tmux.conf" ]] && [[ -f "$OMARCHY_TMUX" ]]; then
    cp "$OMARCHY_TMUX" "$TMUX_DIR/tmux.conf"
    log "Installed ~/.config/tmux/tmux.conf from Omarchy"
fi

if [[ -f "$TMUX_DIR/tmux.conf" ]] && ! grep -qF "$MANAGED_MARKER" "$TMUX_DIR/tmux.conf" 2>/dev/null; then
    cat >> "$TMUX_DIR/tmux.conf" << 'TMUXINCLUDE'

# Managed by ~/.config/shell/bin/migrate.sh
source-file ~/.config/tmux/verify.conf
TMUXINCLUDE
    log "Appended verify.conf include to tmux.conf"
fi

for tmux_template in tmux.verify.conf.ex tmux.verify-soc-theme.conf.ex tmux.status-mode.conf.ex; do
    if [[ ! -f "$CONFIG_DIR/$tmux_template" ]]; then
        if [[ -f "$CONFIG_DIR/plugins/verification/conf/$tmux_template" ]]; then
            cp "$CONFIG_DIR/plugins/verification/conf/$tmux_template" "$CONFIG_DIR/$tmux_template"
            log "Installed $CONFIG_DIR/$tmux_template from plugins/verification"
        elif [[ -f "$CONFIG_DIR/$tmux_template" ]]; then
            :
        fi
    fi
done

if [[ ! -f "$TMUX_DIR/verify.conf" ]]; then
    if [[ -f "$CONFIG_DIR/tmux.verify.conf.ex" ]]; then
        cp "$CONFIG_DIR/tmux.verify.conf.ex" "$TMUX_DIR/verify.conf"
        log "Installed ~/.config/tmux/verify.conf"
    elif [[ -f "$CONFIG_DIR/plugins/verification/conf/tmux.verify.conf.ex" ]]; then
        cp "$CONFIG_DIR/plugins/verification/conf/tmux.verify.conf.ex" "$TMUX_DIR/verify.conf"
        log "Installed ~/.config/tmux/verify.conf from plugins/verification"
    fi
fi

YAZI_DEST="$HOME/.config/yazi/yazi.toml"
mkdir -p "$(dirname "$YAZI_DEST")"
if [[ ! -f "$YAZI_DEST" ]] && [[ -f "$CONFIG_DIR/yazi.ex.toml" ]]; then
    cp "$CONFIG_DIR/yazi.ex.toml" "$YAZI_DEST"
    log "Installed ~/.config/yazi/yazi.toml"
fi

GIT_VERIF="$HOME/.config/git/verification"
mkdir -p "$(dirname "$GIT_VERIF")"
if [[ ! -f "$GIT_VERIF" ]] && [[ -f "$CONFIG_DIR/git.ex.config" ]]; then
    cp "$CONFIG_DIR/git.ex.config" "$GIT_VERIF"
    log "Installed ~/.config/git/verification"
fi

if [[ -f "$GIT_VERIF" ]] && command -v git &>/dev/null; then
    if ! git config --global --get-all include.path 2>/dev/null | grep -qF "$GIT_VERIF"; then
        git config --global include.path "$GIT_VERIF"
        log "Set git config include.path for delta"
    fi
fi

chmod +x "$CONFIG_DIR/plugins/verification/bin/"*.sh 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/agent-verify-layout.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/agent-build-layout.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/fzf-preview.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/tmux-keymap-menu.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/tmux-mode-sync.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/tmux-cycle-layout.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/sync-tmux-verify.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/check-shell-watch.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/verify-workflow-root.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/test/verify-workflow-root.test.sh" 2>/dev/null || true

if write_rc_or_skip "$TMUX_DIR/verify.conf" "tmux verify.conf"; then
    "$CONFIG_DIR/bin/sync-tmux-verify.sh" || true
fi
