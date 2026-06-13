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

FORCE_RC=false
for arg in "$@"; do
    case "$arg" in
        --force-rc) FORCE_RC=true ;;
        -h|--help)
            echo "Usage: migrate.sh [--force-rc]"
            echo "  --force-rc  Overwrite ~/.zshrc, ~/.bashrc, and fish config even if hand-edited"
            exit 0
            ;;
    esac
done

MANAGED_MARKER="Managed by ~/.config/shell/bin/migrate.sh"

should_write_rc() {
    local dest="$1"
    [[ ! -f "$dest" ]] && return 0
    [[ "$FORCE_RC" == true ]] && return 0
    grep -qF "$MANAGED_MARKER" "$dest" 2>/dev/null
}

write_rc_or_skip() {
    local dest="$1" label="$2"
    if should_write_rc "$dest"; then
        return 0
    fi
    warn "Keeping existing $label (not managed — use --force-rc to overwrite)"
    return 1
}

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
log "Script will be installed to: $CONFIG_DIR/bin/migrate.sh"
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

# Create revert script (fixed - uses absolute backup paths)
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
# Self-install script into bin/ (so it's git tracked inside ~/.config/shell/)
# =============================================================================
log "Installing script into ~/.config/shell/bin/ for git tracking..."

mkdir -p "$CONFIG_DIR/bin"

SCRIPT_SRC="$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")"
TARGET_SCRIPT="$CONFIG_DIR/bin/migrate.sh"

if [[ "$SCRIPT_SRC" != "$TARGET_SCRIPT" ]]; then
    cp "$SCRIPT_SRC" "$TARGET_SCRIPT"
    chmod +x "$TARGET_SCRIPT"
    log "Script installed to: $TARGET_SCRIPT"
else
    log "Script already located inside target directory"
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
if [[ -f "$CONFIG_DIR/env.sh" ]]; then
    log "Keeping existing env.sh (not overwriting)"
else
log "Generating env.sh (portable environment)..."

cat > "$CONFIG_DIR/env.sh" << 'ENV_EOF'
#!/usr/bin/env sh
# ~/.config/shell/env.sh
# Portable environment variables and PATH setup.
# Sourced by bash, zsh, and (partially) fish.

# PATH helpers (deduplicated). With path_prepend, last call wins (highest priority).
path_prepend() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$1:$PATH" ;;
    esac
}

path_append() {
    case ":$PATH:" in
        *":$1:"*) return ;;
        *) [ -d "$1" ] && export PATH="$PATH:$1" ;;
    esac
}

path_add() { path_prepend "$@"; }

export PNPM_HOME="$HOME/.local/share/pnpm"

# Prepend: lowest priority first → highest priority last
path_prepend "$HOME/.local/share/solana/install/active_release/bin"
path_prepend "$HOME/.opencode/bin"
path_prepend "$HOME/.bun/bin"
path_prepend "$PNPM_HOME"
path_prepend "$HOME/.cargo/bin"
path_prepend "$HOME/.risc0/bin"
path_prepend "$HOME/.grok/bin"
path_prepend "$HOME/.vector/bin"
path_prepend "$HOME/mamba/bin"
path_prepend "$HOME/.local/share/mise/shims"
path_prepend "$HOME/bin"
path_prepend "$HOME/.local/bin"

# Append: fallbacks only (won't shadow bins above)
path_append "$HOME/miniconda/condabin"
path_append "/opt/rocm/bin"

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
fi

# =============================================================================
# 5. Generate aliases.sh (Additions on top of Omarchy)
# =============================================================================
if [[ -f "$CONFIG_DIR/aliases.sh" ]]; then
    log "Keeping existing aliases.sh (not overwriting)"
else
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

# Git shortcuts (ga is Omarchy's worktree helper — do not alias here)
alias gs='git status'
alias gc='git commit'

# Source personal/work-specific aliases last (so they can override if needed)
if [ -f "$HOME/.config/shell/personal.sh" ]; then
    . "$HOME/.config/shell/personal.sh"
fi
ALIASES_EOF
fi

# =============================================================================
# 6. Generate functions.sh (optional extensions)
# =============================================================================
if [[ -f "$CONFIG_DIR/functions.sh" ]]; then
    log "Keeping existing functions.sh (not overwriting)"
else
log "Generating functions.sh..."

cat > "$CONFIG_DIR/functions.sh" << 'FUNCS_EOF'
#!/usr/bin/env sh
# ~/.config/shell/functions.sh
# Extra functions. Currently minimal because Omarchy covers most needs.

# Print PATH entries one per line (handy when debugging precedence)
path_debug() {
    echo "$PATH" | tr ':' '\n' | nl -ba
}
FUNCS_EOF
fi

# =============================================================================
# 7. Generate ~/.zshrc
# =============================================================================
if write_rc_or_skip "$HOME/.zshrc" "~/.zshrc"; then
log "Generating ~/.zshrc..."

cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
#!/usr/bin/env zsh
# Managed by ~/.config/shell/bin/migrate.sh
# ~/.zshrc - Clean zsh config (pure zsh + starship)
# Omarchy is treated as the personal alias/function layer.
# This file focuses on shell-native inits + portable env.

# 1. Portable environment (PATH, exports; includes Omarchy envs)
source "$HOME/.config/shell/env.sh"

# 2. Direnv (must come early)
eval "$(direnv hook zsh)"

# 3. Omarchy base layer (aliases + functions; envs already loaded via env.sh)
if [[ -f "$HOME/.local/share/omarchy/default/bash/aliases" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/aliases"
fi
if [[ -f "$HOME/.local/share/omarchy/default/bash/functions" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/functions"
fi

# 4. Custom functions, then additional aliases (non-conflicting additions)
if [[ -f "$HOME/.config/shell/functions.sh" ]]; then
    source "$HOME/.config/shell/functions.sh"
fi
source "$HOME/.config/shell/aliases.sh"

# 5. Modern tool initialization (these come AFTER Omarchy)
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

# 6. Zsh-specific settings
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt AUTO_CD
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

autoload -Uz compinit
compinit -C

# 7. Completions
if [[ -r "$HOME/.grok/completions/zsh/grok.zsh" ]]; then
    source "$HOME/.grok/completions/zsh/grok.zsh"
fi

# 8. Final customizations
alias zshconfig='$EDITOR ~/.zshrc'
alias reload='source ~/.zshrc && echo "zshrc reloaded"'
ZSHRC_EOF
fi

# =============================================================================
# 8. Minimal ~/.bashrc
# =============================================================================
if write_rc_or_skip "$HOME/.bashrc" "~/.bashrc"; then
log "Generating minimal ~/.bashrc..."

cat > "$HOME/.bashrc" << 'BASHRC_EOF'
#!/usr/bin/env bash
# Managed by ~/.config/shell/bin/migrate.sh
# ~/.bashrc - Minimal after migration
# Most logic moved to ~/.config/shell/ for multi-shell consistency

[[ $- != *i* ]] && return

source "$HOME/.config/shell/env.sh"
eval "$(direnv hook bash)"

# Omarchy before aliases.sh (ga is a worktree function; aliasing it first breaks bash)
if [[ -f "$HOME/.local/share/omarchy/default/bash/rc" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/rc"
fi

if [[ -f "$HOME/.config/shell/functions.sh" ]]; then
    source "$HOME/.config/shell/functions.sh"
fi

source "$HOME/.config/shell/aliases.sh"

# Bash-specific settings only
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=50000
HISTFILESIZE=100000
BASHRC_EOF
fi

# =============================================================================
# 9. Basic Fish config (decent parity)
# =============================================================================
FISH_CONFIG="$HOME/.config/fish/config.fish"
mkdir -p "$HOME/.config/fish"

if write_rc_or_skip "$FISH_CONFIG" "fish config"; then
log "Generating fish config..."

cat > "$FISH_CONFIG" << 'FISH_EOF'
# Managed by ~/.config/shell/bin/migrate.sh
# ~/.config/fish/config.fish
# Decent parity with bash/zsh setup

# Source portable env where possible (fish syntax is different)
if test -f "$HOME/.config/shell/env.sh"
    bass source "$HOME/.config/shell/env.sh" 2>/dev/null; or true
end

# Direnv (must come early)
if type -q direnv
    direnv hook fish | source
end

# Omarchy integration (best effort)
if test -f "$HOME/.local/share/omarchy/default/bash/aliases"
    bass source "$HOME/.local/share/omarchy/default/bash/aliases" 2>/dev/null; or true
end

# Custom functions before aliases
if test -f "$HOME/.config/shell/functions.sh"
    bass source "$HOME/.config/shell/functions.sh" 2>/dev/null; or true
end

# Shared aliases + personal.sh chain (loads after Omarchy so ff etc. match zsh/bash)
if test -f "$HOME/.config/shell/aliases.sh"
    bass source "$HOME/.config/shell/aliases.sh" 2>/dev/null; or true
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

# fzf key bindings
if type -q fzf
    fzf --fish | source
end

# thefuck (native fish — must not use bass)
if type -q thefuck
    thefuck --alias | source
end

FISH_EOF
fi

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
echo "  - $CONFIG_DIR/bin/migrate.sh   ← Master script (git tracked)"
echo "  - ~/.zshrc (clean, pure zsh + starship)"
echo "  - ~/.bashrc (minimal)"
echo "  - ~/.config/fish/config.fish"
echo ""
echo "Omarchy is respected and sourced early. Modern tools are layered on top."
echo ""
echo "Future runs: ~/.config/shell/bin/migrate.sh"
echo "Force rc regen: ~/.config/shell/bin/migrate.sh --force-rc"
echo "==================================================================="
