#!/usr/bin/env bash
# =============================================================================
# Master Shell Migration Script
# Creates clean, multi-shell (bash/zsh/fish) setup while respecting Omarchy
# - Timestamped backup
# - Git-tracked ~/.config/shell/
# - Pure zsh + starship (no Oh My Zsh)
# - Smart integration with Omarchy
# - Idempotent + revert capable
# =============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

BACKUP_DIR="$HOME/.config/shell/backups/$(date +%Y%m%d-%H%M%S)"
CONFIG_DIR="$HOME/.config/shell"
OMARCHY_PATH="$HOME/.local/share/omarchy"

echo "==================================================================="
echo "  Master Shell Migration - Clean Multi-Shell Setup"
echo "==================================================================="
echo ""
log "Backup location: $BACKUP_DIR"
log "Config dir     : $CONFIG_DIR"
echo ""

# =============================================================================
# 1. Safety & Backup
# =============================================================================
log "Creating backup of existing dotfiles..."

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

# Create revert script
cat > "$BACKUP_DIR/revert.sh" << 'REVERT_EOF'
#!/usr/bin/env bash
echo "Reverting dotfiles from this backup..."
cp -a .bashrc "$HOME/.bashrc" 2>/dev/null || true
cp -a .zshrc "$HOME/.zshrc" 2>/dev/null || true
cp -a .zprofile "$HOME/.zprofile" 2>/dev/null || true
cp -a .zshenv "$HOME/.zshenv" 2>/dev/null || true
cp -a starship.toml "$HOME/.config/starship.toml" 2>/dev/null || true
echo "Revert complete. You may need to restart your shell."
REVERT_EOF
chmod +x "$BACKUP_DIR/revert.sh"

success "Backup created at: $BACKUP_DIR"
echo ""

# =============================================================================
# 2. Create directory structure + Git
# =============================================================================
log "Setting up ~/.config/shell/ structure..."

mkdir -p "$CONFIG_DIR"/{backups,completions}

if [[ ! -d "$CONFIG_DIR/.git" ]]; then
    (cd "$CONFIG_DIR" && git init -q)
    log "Initialized git repo in $CONFIG_DIR"
fi

# =============================================================================
# 3. Install missing tools (yazi + thefuck)
# =============================================================================
log "Checking for missing tools..."

if ! command -v yazi &>/dev/null; then
    log "Installing yazi via paru..."
    paru -S --needed --noconfirm yazi || warn "Failed to install yazi. Please install manually."
fi

if ! command -v thefuck &>/dev/null; then
    log "Installing thefuck via paru..."
    paru -S --needed --noconfirm thefuck || warn "Failed to install thefuck. Please install manually."
fi

# =============================================================================
# 4. Generate env.sh (Portable environment + PATH)
# =============================================================================
log "Generating env.sh (portable environment)..."

cat > "$CONFIG_DIR/env.sh" << 'ENV_EOF'
#!/usr/bin/env sh
# ~/.config/shell/env.sh
# Portable environment variables and PATH setup.
# Sourced by bash, zsh, and (partially) fish.

# Safely add to PATH (deduplicated)
path_add() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
    esac
}

# Highest priority personal bins
path_add "$HOME/.local/bin"
path_add "$HOME/bin"
path_add "$HOME/.local/share/mise/shims"

# Language/tool managers and runtimes
path_add "$HOME/.bun/bin"
path_add "$HOME/.opencode/bin"
path_add "$HOME/.local/share/solana/install/active_release/bin"
path_add "$HOME/.local/share/pnpm"
path_add "$HOME/.cargo/bin"
path_add "$HOME/.risc0/bin"
path_add "$HOME/.grok/bin"

# Mamba (keep later)
path_add "$HOME/mamba/bin"

# pnpm official handling
export PNPM_HOME="$HOME/.local/share/pnpm"
path_add "$PNPM_HOME"

# Performance & misc
export PIP_CACHE_DIR="$HOME/pip-cache"
export TMPDIR="$HOME/tmp"
export OMP_NUM_THREADS=12
export MKL_NUM_THREADS=12
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# Fix clear if mamba interferes
alias clear='/usr/bin/clear' 2>/dev/null || true

# SSH & GPG
export SSH_AUTH_SOCK="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
export GPG_TTY="$(tty)"

# Source Omarchy envs early (if available)
if [ -f "$HOME/.local/share/omarchy/default/bash/envs" ]; then
    . "$HOME/.local/share/omarchy/default/bash/envs"
fi

# Your custom loaders (keep if they exist)
[ -f "$HOME/.local/share/../bin/env" ] && . "$HOME/.local/share/../bin/env"
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
ENV_EOF

# =============================================================================
# 5. Generate aliases.sh (Additions on top of Omarchy)
# =============================================================================
log "Generating aliases.sh..."

cat > "$CONFIG_DIR/aliases.sh" << 'ALIASES_EOF'
#!/usr/bin/env sh
# ~/.config/shell/aliases.sh
# Additional aliases that complement (not duplicate) Omarchy.

# Only add things Omarchy doesn't already handle well

# Better yazi wrapper (cd on exit)
if command -v yazi &>/dev/null; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
    }
fi

# Monitoring & system
if command -v btop &>/dev/null; then
    alias top='btop'
fi
if command -v duf &>/dev/null; then
    alias df='duf'
fi
if command -v dust &>/dev/null; then
    alias du='dust'
fi

# Quality of life
alias cls='clear'
alias ff='fastfetch'
alias lg='lazygit'
alias n='nvim'

# Git shortcuts (if Omarchy doesn't have them)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
ALIASES_EOF

# =============================================================================
# 6. Generate functions.sh (optional extensions)
# =============================================================================
log "Generating functions.sh..."

cat > "$CONFIG_DIR/functions.sh" << 'FUNCS_EOF'
#!/usr/bin/env sh
# ~/.config/shell/functions.sh
# Extra functions. Currently minimal because Omarchy covers most needs.
FUNCS_EOF

# =============================================================================
# 7. Generate ~/.zshrc
# =============================================================================
log "Generating ~/.zshrc..."

cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
#!/usr/bin/env zsh
# ~/.zshrc - Clean zsh config (pure zsh + starship)
# Omarchy is treated as the personal alias/function layer.
# This file focuses on shell-native inits + portable env.

# 1. Portable environment (PATH, exports)
source "$HOME/.config/shell/env.sh"

# 2. Omarchy base layer (your personal aliases + functions)
# We source the modular parts directly for better control
if [[ -f "$HOME/.local/share/omarchy/default/bash/envs" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/envs"
fi
if [[ -f "$HOME/.local/share/omarchy/default/bash/aliases" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/aliases"
fi
if [[ -f "$HOME/.local/share/omarchy/default/bash/functions" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/functions"
fi

# 3. Additional aliases from our layer (non-conflicting additions)
source "$HOME/.config/shell/aliases.sh"

# 4. Modern tool initialization (these come AFTER Omarchy)
# mise (version manager)
if command -v mise &>/dev/null; then
    eval "$(mise activate zsh)"
fi

# Starship prompt (pure zsh, no Oh My Zsh)
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# zoxide (smart cd) - Omarchy may already wrap cd, we still init for `z` command
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# fzf
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi

# thefuck
if command -v thefuck &>/dev/null; then
    eval "$(thefuck --alias)"
fi

# 5. Zsh-specific settings
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

autoload -Uz compinit
compinit -C

# 6. Completions
if [[ -r "$HOME/.grok/completions/zsh/grok.zsh" ]]; then
    source "$HOME/.grok/completions/zsh/grok.zsh"
fi

# 7. Final customizations
alias zshconfig='$EDITOR ~/.zshrc'
alias reload='source ~/.zshrc && echo "zshrc reloaded"'
ZSHRC_EOF

# =============================================================================
# 8. Minimal ~/.bashrc
# =============================================================================
log "Generating minimal ~/.bashrc..."

cat > "$HOME/.bashrc" << 'BASHRC_EOF'
#!/usr/bin/env bash
# ~/.bashrc - Minimal after migration
# Most logic moved to ~/.config/shell/ for multi-shell consistency

[[ $- != *i* ]] && return

source "$HOME/.config/shell/env.sh"
source "$HOME/.config/shell/aliases.sh"

# Keep sourcing Omarchy for bash too (full compatibility)
if [[ -f "$HOME/.local/share/omarchy/default/bash/rc" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/rc"
fi

# Bash-specific settings only
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=50000
HISTFILESIZE=100000
BASHRC_EOF

# =============================================================================
# 9. Basic Fish config (decent parity)
# =============================================================================
log "Generating fish config..."

mkdir -p "$HOME/.config/fish"

cat > "$HOME/.config/fish/config.fish" << 'FISH_EOF'
# ~/.config/fish/config.fish
# Decent parity with bash/zsh setup

# Source portable env where possible (fish syntax is different)
if test -f "$HOME/.config/shell/env.sh"
    bass source "$HOME/.config/shell/env.sh" 2>/dev/null; or true
end

# Omarchy integration (best effort)
if test -f "$HOME/.local/share/omarchy/default/bash/aliases"
    bass source "$HOME/.local/share/omarchy/default/bash/aliases" 2>/dev/null; or true
end

# Starship
if type -q starship
    starship init fish | source
end

# zoxide
if type -q zoxide
    zoxide init fish | source
end

# mise
if type -q mise
    mise activate fish | source
end

# Useful abbreviations
abbr -a n nvim
abbr -a lg lazygit
abbr -a ff fastfetch
abbr -a cls clear
FISH_EOF

# =============================================================================
# 10. Git commit the new structure
# =============================================================================
log "Committing initial setup to git..."

(
    cd "$CONFIG_DIR"
    git add -A
    git commit -m "Initial clean multi-shell setup (bash/zsh/fish) with Omarchy integration" --quiet 2>/dev/null || true
)

# =============================================================================
# Final summary
# =============================================================================
echo ""
success "Migration complete!"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc"
echo "  2. Test in zsh: zsh -l"
echo "  3. Test in bash: bash -l"
echo "  4. Revert if needed: $BACKUP_DIR/revert.sh"
echo ""
echo "Key files created:"
echo "  - $CONFIG_DIR/env.sh"
echo "  - $CONFIG_DIR/aliases.sh"
echo "  - ~/.zshrc (clean, pure zsh + starship)"
echo "  - ~/.bashrc (minimal)"
echo "  - ~/.config/fish/config.fish"
echo ""
echo "Omarchy is respected and sourced early. Modern tools are layered on top."
echo "==================================================================="
