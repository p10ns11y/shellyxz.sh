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

# Remote bootstrap (curl | bash, or missing repo files). Override for forks/branches:
#   SHELL_CONFIG_RAW=https://raw.githubusercontent.com/you/shellyxz.sh/refs/heads/master
SHELL_CONFIG_RAW="${SHELL_CONFIG_RAW:-https://raw.githubusercontent.com/p10ns11y/shellyxz.sh/refs/heads/master}"

FORCE_RC=false
BOOTSTRAP=false
for arg in "$@"; do
    case "$arg" in
        --force-rc) FORCE_RC=true ;;
        --bootstrap) BOOTSTRAP=true ;;
        -h|--help)
            echo "Usage: migrate.sh [--force-rc] [--bootstrap]"
            echo "  --force-rc   Overwrite managed dotfiles (~/.zshrc, login files, fish) even if hand-edited"
            echo "  --bootstrap  Fetch missing repo files from SHELL_CONFIG_RAW (default: GitHub master)"
            echo ""
            echo "Also scaffolds (when example files exist): tmux/yazi/git verification,"
            echo "starship.toml, backups with revert.sh. See bin/README.md."
            echo "One-liner install (pipe bootstrap — fetches full config from GitHub):"
            echo "  curl -fsSL ${SHELL_CONFIG_RAW}/bin/migrate.sh | bash"
            echo ""
            echo "Or clone + run:"
            echo "  git clone git@github.com:p10ns11y/shellyxz.sh.git ~/.config/shell"
            echo "  ~/.config/shell/bin/migrate.sh"
            exit 0
            ;;
    esac
done

CONFIG_DIR="${HOME}/.config/shell"

# Colors + logging (needed before remote bootstrap)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# True when executed as: curl .../migrate.sh | bash
is_piped_install() {
    local base
    base="$(basename "${0:-}")"
    [[ "$base" == "bash" || "$base" == "sh" || "$base" == "dash" ]]
}

config_needs_bootstrap() {
    local f
    for f in lib.sh bin/check-shell.sh bin/recover-shell.sh; do
        [[ -f "$CONFIG_DIR/$f" ]] || return 0
    done
    return 1
}

bootstrap_from_remote() {
    local rel dest dir url
    local files=(
        lib.sh env.sh aliases.sh functions.sh personal.sh
        bin/migrate.sh bin/check-shell.sh bin/recover-shell.sh bin/README.md
        bin/agent-verify-layout.sh bin/fzf-preview.sh
        README.md shell.md SHELL-env-var-behavior.md VERIFICATION.md
        starship.ex.toml tmux.verify.conf.ex yazi.ex.toml git.ex.config .gitignore
    )

    if ! command -v curl &>/dev/null; then
        warn "curl not found — cannot bootstrap from $SHELL_CONFIG_RAW"
        return 1
    fi

    log "Bootstrapping ~/.config/shell from $SHELL_CONFIG_RAW"
    mkdir -p "$CONFIG_DIR/bin"

    for rel in "${files[@]}"; do
        dest="$CONFIG_DIR/$rel"
        if [[ -f "$dest" ]]; then
            log "Keeping existing $rel"
            continue
        fi
        dir="$(dirname "$dest")"
        mkdir -p "$dir"
        url="$SHELL_CONFIG_RAW/$rel"
        if curl -fsSL "$url" -o "$dest"; then
            log "Fetched: $rel"
        else
            warn "Failed to fetch $url"
        fi
    done

    chmod +x "$CONFIG_DIR/bin/"*.sh 2>/dev/null || true
    success "Remote bootstrap complete"
}

if [[ "$BOOTSTRAP" == true ]] || is_piped_install || config_needs_bootstrap; then
    bootstrap_from_remote || true
fi

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

BACKUP_DIR="$HOME/.config/shell/backups/$(date +%Y%m%d-%H%M%S)"
OMARCHY_PATH="$HOME/.local/share/omarchy"

echo "==================================================================="
echo "  Master Shell Migration - Clean Multi-Shell Setup"
echo "==================================================================="
echo ""
log "Backup location: $BACKUP_DIR"
log "Config dir     : $CONFIG_DIR"
log "Omarchy path   : $OMARCHY_PATH"
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

SCRIPT_SRC="$(realpath "${BASH_SOURCE[0]:-$0}" 2>/dev/null || readlink -f "${BASH_SOURCE[0]:-$0}" 2>/dev/null || echo "${BASH_SOURCE[0]:-$0}")"
TARGET_SCRIPT="$CONFIG_DIR/bin/migrate.sh"

if [[ -f "$TARGET_SCRIPT" ]] && [[ "$SCRIPT_SRC" != "$TARGET_SCRIPT" ]]; then
    # Piped install (curl | bash): bootstrap already fetched migrate.sh — skip redundant copy
    if is_piped_install; then
        log "Using bootstrapped migrate.sh at $TARGET_SCRIPT"
    else
        cp "$SCRIPT_SRC" "$TARGET_SCRIPT"
        chmod +x "$TARGET_SCRIPT"
        log "Script installed to: $TARGET_SCRIPT"
    fi
elif [[ "$SCRIPT_SRC" == "$TARGET_SCRIPT" ]]; then
    log "Script already located inside target directory"
else
    cp "$SCRIPT_SRC" "$TARGET_SCRIPT" 2>/dev/null || \
        curl -fsSL "$SHELL_CONFIG_RAW/bin/migrate.sh" -o "$TARGET_SCRIPT" || \
        warn "Could not install migrate.sh to $TARGET_SCRIPT"
    chmod +x "$TARGET_SCRIPT" 2>/dev/null || true
fi

# =============================================================================
# 3. Install missing tools (Arch: paru — other distros: install manually)
# Currently optimized for Arch via paru. Other distros: install procs,
# difftastic, git-delta, yazi, and thefuck manually, then source ~/.zshrc.
# =============================================================================
log "Checking for missing tools..."

if command -v paru &>/dev/null; then
    if ! command -v yazi &>/dev/null; then
        log "Installing yazi via paru..."
        paru -S --needed --noconfirm yazi || warn "Failed to install yazi. Please install manually."
    fi

    if ! command -v thefuck &>/dev/null; then
        log "Installing thefuck via paru..."
        paru -S --needed --noconfirm thefuck || warn "Failed to install thefuck. Please install manually."
    fi

    if ! command -v procs &>/dev/null; then
        log "Installing procs via paru..."
        paru -S --needed --noconfirm procs || warn "Failed to install procs. Please install manually."
    fi

    if ! command -v difft &>/dev/null; then
        log "Installing difftastic via paru..."
        paru -S --needed --noconfirm difftastic || warn "Failed to install difftastic. Please install manually."
    fi
else
    warn "paru not found — skip auto-install (yazi, thefuck, procs, difftastic). Install manually on non-Arch."
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

# Shared safe loaders (Omarchy paths, permission checks, secrets helper)
if [ -f "$HOME/.config/shell/lib.sh" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.config/shell/lib.sh"
fi

# Optional: set SHELL_TRUTH_SEEKER=0 before sourcing to keep inherited $SHELL.
shell_truth_seeker 2>/dev/null || true

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

# Mamba/conda: let Starship show env; avoid duplicate (xai_exp) prefix on its own line
export CONDA_CHANGEPS1=false

# fzf — bat preview for verification sweeps (skip heavy preview in editor terminals)
if command -v fzf >/dev/null 2>&1; then
    detect_editor_terminal 2>/dev/null || true
    if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = no ] && command -v bat >/dev/null 2>&1; then
        # shellcheck disable=SC2089,SC2090
        export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border rounded --preview-window=right:60%:wrap --preview '${HOME}/.config/shell/bin/fzf-preview.sh {}'"
        export FZF_CTRL_T_OPTS='--preview-window=right:60%:wrap'
    else
        # shellcheck disable=SC2090
        export FZF_DEFAULT_OPTS='--height 50% --layout=reverse --border rounded'
    fi
    if command -v fd >/dev/null 2>&1; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    fi
fi

# Performance & misc
export PIP_CACHE_DIR="$HOME/pip-cache"
export TMPDIR="$HOME/tmp"
export OMP_NUM_THREADS=12
export MKL_NUM_THREADS=12
export HSA_OVERRIDE_GFX_VERSION=11.0.0

# Fix clear if mamba interferes
alias clear='/usr/bin/clear' 2>/dev/null || true

# SSH & GPG — interactive only (avoid tty/socket noise in scripts and CI)
if _is_interactive_session 2>/dev/null; then
    _sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/ssh-agent.socket"
    [ -S "$_sock" ] && export SSH_AUTH_SOCK="$_sock"
    _tty=$(tty 2>/dev/null) && [ -n "$_tty" ] && export GPG_TTY="$_tty"
    unset _sock _tty
fi

# Omarchy envs (optional — missing install is fine)
if command -v source_omarchy >/dev/null 2>&1; then
    source_omarchy envs 2>/dev/null || true
elif [ -f "$HOME/.local/share/omarchy/default/bash/envs" ]; then
    # shellcheck disable=SC1091
    . "$HOME/.local/share/omarchy/default/bash/envs"
fi

# External loaders — explicit paths, permission-checked when lib.sh is present
if command -v source_if_safe >/dev/null 2>&1; then
    source_if_safe "$HOME/.local/bin/env" 2>/dev/null || true
    source_if_safe "$HOME/.vite-plus/env" 2>/dev/null || true
    source_if_safe "$HOME/.cargo/env" 2>/dev/null || true
else
    [ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
    [ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
    [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
fi
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
#!/usr/bin/env bash
# ~/.config/shell/aliases.sh
# Additional aliases that complement (not duplicate) Omarchy.
# Sourced by bash and zsh rc files; fish loads via bass (bash subshell).

# Only add things Omarchy doesn't already handle well

# Better yazi wrapper (cd on exit)
if command -v yazi &>/dev/null; then
    y() {
        local tmp cwd
        tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd" || return 1
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

# Verification speed aliases (guarded — active when binary exists on PATH)
# ps→procs, gdf/gdfs→difftastic; cat/grep/find→bat/rg/fd
if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
fi
if command -v rg &>/dev/null; then
    alias grep='rg'
fi
if command -v fd &>/dev/null; then
    alias find='fd'
fi
if command -v procs &>/dev/null; then
    alias ps='procs'
fi
if command -v tmux &>/dev/null; then
    alias tt='tmux new-window -n test -c "#{pane_current_path}"'
fi

# Quality of life
alias cls='clear'
alias ff='fastfetch'
alias lg='lazygit'
alias av='agent_verify'
# n() is Omarchy's nvim wrapper — do not alias here (breaks zsh reload)

# Git shortcuts (ga is Omarchy's worktree helper — do not alias here)
alias gs='git status'
alias gc='git commit'
if command -v difft &>/dev/null; then
    alias gdf='git -c diff.external=difft diff'
    alias gdfs='git -c diff.external=difft diff --staged'
fi

# Source personal/work-specific aliases last (so they can override if needed)
if [ -f "$HOME/.config/shell/personal.sh" ]; then
    # shellcheck disable=SC1091
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
#!/usr/bin/env bash
# ~/.config/shell/functions.sh
# Extra functions. Sourced by bash and zsh rc files; fish loads via bass.

# Print PATH entries one per line (handy when debugging precedence)
path_debug() {
    echo "$PATH" | tr ':' '\n' | nl -ba
}

# Shell identity diagnostics.
# $SHELL is often stale after chsh + exec or in long-lived terminal sessions.
# It is set by the *initial login/terminal process* and inherited; exec does not always update it.
# Use this (or the check script) instead of trusting `echo $SHELL`.
shell_debug() {
    echo "=== shell identity ==="
    echo "Invoked as (\$0):          $0"
    echo "\$SHELL (env var):        $SHELL"
    echo "SHELL_TRUTH_SEEKER:       ${SHELL_TRUTH_SEEKER:-1} (set 0 in env to keep inherited \$SHELL)"
    local login_sh
    login_sh=$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7 || echo unknown)
    echo "Login shell (passwd):     $login_sh"
    echo "Current process (ps):     $(ps -p $$ -o pid,comm,args 2>/dev/null || echo 'ps unavailable')"
    echo "TERM_PROGRAM:             ${TERM_PROGRAM:-unset}"
    if command -v detect_editor_terminal >/dev/null 2>&1; then
        detect_editor_terminal 2>/dev/null
        case "${SHELL_IN_EDITOR_TERMINAL:-no}" in
            yes) echo "Editor terminal:          yes (mise hook skipped; shims on PATH)" ;;
            no)  echo "Editor terminal:          no" ;;
        esac
    fi
    echo "ZSH_VERSION:              ${ZSH_VERSION:-unset (not zsh)}"
    echo "BASH_VERSION:             ${BASH_VERSION:-unset (not bash)}"
    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "You are running zsh."
    elif [ -n "${BASH_VERSION:-}" ]; then
        echo "You are running bash."
    fi
    echo ""
    echo "Tip: after 'exec /usr/bin/zsh -l' the prompt + ZSH_VERSION + ps will tell the truth."
    echo "     echo \$SHELL frequently lies because it is inherited from the original terminal session."
}

# Fuzzy-open file in $EDITOR (complements Omarchy eff).
vf() {
    command -v fzf >/dev/null 2>&1 || { echo "vf: fzf not found" >&2; return 1; }
    local f preview
    if command -v bat >/dev/null 2>&1; then
        preview="bat --style=numbers --color=always {}"
    else
        preview="cat {}"
    fi
    if command -v fd >/dev/null 2>&1; then
        f="$(fd --type f --hidden --exclude .git 2>/dev/null | fzf --preview "$preview")"
    else
        f="$(find . -type f 2>/dev/null | fzf --preview "$preview")"
    fi
    [ -n "$f" ] && "${EDITOR:-nvim}" "$f"
}

# Quick structured scan after agent output (rg + dust + JSON reports).
agent_scan() {
    local dir="${1:-.}"
    echo "=== rg sweep ==="
    if command -v rg >/dev/null 2>&1; then
        rg -n 'TODO|FIXME|panic!|unwrap\(|ERROR|error:' "$dir" 2>/dev/null | head -30
    else
        echo "rg not found"
    fi
    echo "=== dust ==="
    if command -v dust >/dev/null 2>&1; then
        dust -s "$dir" 2>/dev/null | head -15
    fi
    for f in "$dir/report.json" "$dir/output.json"; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            if command -v jq >/dev/null 2>&1; then
                if command -v bat >/dev/null 2>&1; then
                    jq '.summary // .issues // .' "$f" 2>/dev/null | bat -l json
                else
                    jq '.summary // .issues // .' "$f" 2>/dev/null
                fi
            else
                head -20 "$f"
            fi
        fi
    done
}

# Open verification cockpit layout in tmux (requires native terminal + active tmux).
agent_verify() {
    if command -v detect_editor_terminal >/dev/null 2>&1; then
        detect_editor_terminal 2>/dev/null
        if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = yes ]; then
            echo "Run in Ghostty/tmux (t or Super+Alt+Return), not Cursor integrated terminal." >&2
            return 1
        fi
    fi
    if [ -z "${TMUX:-}" ]; then
        echo "agent_verify: start tmux first (t or Super+Alt+Return)" >&2
        return 1
    fi
    local dir="${1:-.}"
    local script="$HOME/.config/shell/bin/agent-verify-layout.sh"
    if [ ! -x "$script" ]; then
        echo "agent_verify: missing $script" >&2
        return 1
    fi
    "$script" "$dir"
}

# Portable reload helper for the current shell.
# Works in bash and zsh. In zsh, ~/.zshrc overrides this with an enhanced
# version that pre-clears 'n'/'ga'/'gd'/'reload' (and runs unfunction) before
# re-sourcing, to prevent "defining function based on alias" errors on reload.
reload() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.zshrc" && echo "zshrc reloaded"
    elif [ -n "${BASH_VERSION:-}" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.bashrc" && echo "bashrc reloaded"
        # Help people who are in the wrong shell after chsh and keep typing "reload"
        local u login_sh
        u="${USER:-$(id -un 2>/dev/null || whoami)}"
        login_sh="$(getent passwd "$u" 2>/dev/null | cut -d: -f7 || echo /usr/bin/zsh)"
        if [ "$SHELL" != "$login_sh" ]; then
            echo "Note: you are still in $SHELL. To switch this terminal to the default ($login_sh): exec $login_sh -l"
        fi
    else
        echo "reload: unknown shell (no \$ZSH_VERSION or \$BASH_VERSION)"
        return 1
    fi
}
FUNCS_EOF
fi

# =============================================================================
# 7. Generate ~/.zshrc
# =============================================================================
if write_rc_or_skip "$HOME/.zshrc" "$HOME/.zshrc"; then
log "Generating ~/.zshrc..."

cat > "$HOME/.zshrc" << 'ZSHRC_EOF'
#!/usr/bin/env zsh
# Managed by ~/.config/shell/bin/migrate.sh
# ~/.zshrc - Clean zsh config (pure zsh + starship)
# Omarchy is treated as the personal alias/function layer.
# This file focuses on shell-native inits + portable env.

# 1. Portable environment (PATH, exports; includes Omarchy envs)
source "$HOME/.config/shell/env.sh"

# 2. Direnv (must come early; use the right hook if .zshrc is sourced from bash)
if command -v direnv &>/dev/null; then
    if [ -n "${ZSH_VERSION:-}" ]; then
        eval "$(direnv hook zsh)"
    elif [ -n "${BASH_VERSION:-}" ]; then
        eval "$(direnv hook bash)"
    fi
fi

# 3. Omarchy base layer (aliases + functions; envs already loaded via env.sh)
# Defensively clear aliases for names that Omarchy defines as functions (n, ga, gd).
# Omarchy's n() is defined inside its "aliases" file. If an `alias n=...` exists
# (from interactive use, tool inits, direnv, old scripts, or a prior `source` that
# reached the bottom of this file), zsh will refuse to define the function on reload:
#   "defining function based on alias `n'"
# This guard makes `source ~/.zshrc` (and the `reload` alias) robust.
for _name in n ga gd reload; do
    unalias "$_name" 2>/dev/null || true
    unfunction "$_name" 2>/dev/null || true
done
if typeset -f source_omarchy >/dev/null 2>&1; then
    source_omarchy aliases 2>/dev/null || true
    source_omarchy functions 2>/dev/null || true
else
    if [[ -f "$HOME/.local/share/omarchy/default/bash/aliases" ]]; then
        source "$HOME/.local/share/omarchy/default/bash/aliases"
    fi
    if [[ -f "$HOME/.local/share/omarchy/default/bash/functions" ]]; then
        source "$HOME/.local/share/omarchy/default/bash/functions"
    fi
fi

# 4. Custom functions, then additional aliases (non-conflicting additions)
if [[ -f "$HOME/.config/shell/functions.sh" ]]; then
    source "$HOME/.config/shell/functions.sh"
fi
source "$HOME/.config/shell/aliases.sh"

# If sourced from a non-zsh shell (very common while debugging after chsh,
# one-liners, or check-shell.sh from bash), stop here.
# - Portable bits (env, Omarchy via guarded load, functions, aliases) have run.
# - The early unalias guard already protected Omarchy's n()/ga() definitions.
# - We deliberately skip zsh-only inits (mise/starship/fzf --zsh etc.),
#   zsh setopts, compinit, grok zsh completions, and the zsh-specific reload()
#   definition. This prevents defining a "reload" that claims "zshrc reloaded"
#   while the actual process remains bash.
if [ -z "${ZSH_VERSION:-}" ]; then
    return 0 2>/dev/null || true
fi

# 5. Modern tool initialization (these come AFTER Omarchy)
# Mamba (conda-compatible env manager)
if command -v mamba &>/dev/null; then
    eval "$(mamba shell hook --shell zsh)"
fi

# mise (version manager) — shims on PATH via env.sh; skip hook in editor terminals (phantom tabs)
detect_editor_terminal 2>/dev/null
if command -v mise &>/dev/null && [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = no ]; then
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

# reload is a function (not alias) so it can pre-clear reserved names before re-sourcing.
# This + the early + late guards in this file make repeated `reload` or `source ~/.zshrc` safe.
# Unalias first in case a previous load left `alias reload=...` (the old definition).
unalias reload 2>/dev/null || true
reload() {
    for _name in n ga gd reload; do
        unalias "$_name" 2>/dev/null || true
        unfunction "$_name" 2>/dev/null || true
    done
    source ~/.zshrc && echo "zshrc reloaded"
}

# Final safeguard after all inits: keep Omarchy function names (n/ga/gd) free of aliases.
# Some tool inits, completions, or direnv-loaded envs can introduce aliases at runtime.
for _name in n ga gd reload; do
    unalias "$_name" 2>/dev/null || true
done
ZSHRC_EOF
fi

# =============================================================================
# 8. Minimal ~/.bashrc
# =============================================================================
if write_rc_or_skip "$HOME/.bashrc" "$HOME/.bashrc"; then
log "Generating minimal ~/.bashrc..."

cat > "$HOME/.bashrc" << 'BASHRC_EOF'
#!/usr/bin/env bash
# Managed by ~/.config/shell/bin/migrate.sh
# ~/.bashrc - Minimal after migration
# Most logic moved to ~/.config/shell/ for multi-shell consistency

[[ $- != *i* ]] && return

source "$HOME/.config/shell/env.sh"
if command -v direnv &>/dev/null; then
    eval "$(direnv hook bash)"
fi

# Omarchy — skip rc/init in editor terminals (mise hook → phantom activate/zsh tabs)
detect_editor_terminal 2>/dev/null
if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = yes ]; then
    if typeset -f source_omarchy >/dev/null 2>&1; then
        source_omarchy aliases 2>/dev/null || true
        source_omarchy functions 2>/dev/null || true
    else
        if [[ -f "$HOME/.local/share/omarchy/default/bash/aliases" ]]; then
            source "$HOME/.local/share/omarchy/default/bash/aliases"
        fi
        if [[ -f "$HOME/.local/share/omarchy/default/bash/functions" ]]; then
            source "$HOME/.local/share/omarchy/default/bash/functions"
        fi
    fi
elif typeset -f source_omarchy >/dev/null 2>&1; then
    source_omarchy rc 2>/dev/null || true
elif [[ -f "$HOME/.local/share/omarchy/default/bash/rc" ]]; then
    source "$HOME/.local/share/omarchy/default/bash/rc"
fi

if [[ -f "$HOME/.config/shell/functions.sh" ]]; then
    source "$HOME/.config/shell/functions.sh"
fi

source "$HOME/.config/shell/aliases.sh"

# Mamba (conda-compatible env manager)
if command -v mamba &>/dev/null; then
    eval "$(mamba shell hook --shell bash)"
fi

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

# Truth-seeking SHELL for fish
set -gx SHELL (command -v fish 2>/dev/null; or echo /usr/bin/fish)

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

# Mamba (conda-compatible env manager)
if type -q mamba
    mamba shell hook --shell fish | source
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
# 10. Login dotfiles (zprofile, zshenv, profile, bash_profile)
# =============================================================================
if write_rc_or_skip "$HOME/.zprofile" "zprofile"; then
log "Generating ~/.zprofile..."
cat > "$HOME/.zprofile" << 'ZPROFILE_EOF'
#!/usr/bin/env zsh
# Managed by ~/.config/shell/bin/migrate.sh
# Login PATH — delegate to portable env (~/.config/shell/env.sh)
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
ZPROFILE_EOF
fi

if write_rc_or_skip "$HOME/.zshenv" "zshenv"; then
log "Generating ~/.zshenv..."
cat > "$HOME/.zshenv" << 'ZSHENV_EOF'
#!/usr/bin/env zsh
# Managed by ~/.config/shell/bin/migrate.sh
export SHELL=$(command -v zsh 2>/dev/null || echo /usr/bin/zsh)
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
ZSHENV_EOF
fi

if write_rc_or_skip "$HOME/.profile" "profile"; then
log "Generating ~/.profile..."
cat > "$HOME/.profile" << 'PROFILE_EOF'
# Managed by ~/.config/shell/bin/migrate.sh
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
PROFILE_EOF
fi

if write_rc_or_skip "$HOME/.bash_profile" "bash_profile"; then
log "Generating ~/.bash_profile..."
cat > "$HOME/.bash_profile" << 'BASHPROFILE_EOF'
# Managed by ~/.config/shell/bin/migrate.sh
[[ -f ~/.bashrc ]] && . ~/.bashrc
[ -f "$HOME/.vite-plus/env" ] && . "$HOME/.vite-plus/env"
BASHPROFILE_EOF
fi

# =============================================================================
# 11. Starship config (from starship.ex.toml when absent)
# =============================================================================
STARSHIP_DEST="$HOME/.config/starship.toml"
mkdir -p "$HOME/.config"
if [[ ! -f "$STARSHIP_DEST" ]]; then
    if [[ -f "$CONFIG_DIR/starship.ex.toml" ]]; then
        cp "$CONFIG_DIR/starship.ex.toml" "$STARSHIP_DEST"
        log "Installed ~/.config/starship.toml from starship.ex.toml"
    else
        warn "starship.ex.toml missing — run migrate with --bootstrap or clone the repo"
    fi
else
    log "Keeping existing ~/.config/starship.toml"
fi

# =============================================================================
# 12. tmux / yazi / git verification scaffolds
# =============================================================================
TMUX_DIR="$HOME/.config/tmux"
OMARCHY_TMUX="$OMARCHY_PATH/config/tmux/tmux.conf"
mkdir -p "$TMUX_DIR"

if [[ ! -f "$TMUX_DIR/tmux.conf" ]]; then
    if [[ -f "$OMARCHY_TMUX" ]]; then
        cp "$OMARCHY_TMUX" "$TMUX_DIR/tmux.conf"
        log "Installed ~/.config/tmux/tmux.conf from Omarchy"
    else
        warn "Omarchy tmux.conf missing at $OMARCHY_TMUX"
    fi
else
    log "Keeping existing ~/.config/tmux/tmux.conf"
fi

if [[ -f "$TMUX_DIR/tmux.conf" ]] && ! grep -q 'Managed by ~/.config/shell/bin/migrate.sh' "$TMUX_DIR/tmux.conf" 2>/dev/null; then
    cat >> "$TMUX_DIR/tmux.conf" << 'TMUXINCLUDE'

# Managed by ~/.config/shell/bin/migrate.sh
source-file ~/.config/tmux/verify.conf
TMUXINCLUDE
    log "Appended verify.conf include to tmux.conf"
elif [[ -f "$TMUX_DIR/tmux.conf" ]] && grep -q '%include ~/.config/tmux/verify.conf' "$TMUX_DIR/tmux.conf" 2>/dev/null; then
    sed -i 's|%include ~/.config/tmux/verify.conf|source-file ~/.config/tmux/verify.conf|' "$TMUX_DIR/tmux.conf"
    log "Repaired tmux.conf: %include → source-file for verify.conf"
fi

if [[ ! -f "$TMUX_DIR/verify.conf" ]] && [[ -f "$CONFIG_DIR/tmux.verify.conf.ex" ]]; then
    cp "$CONFIG_DIR/tmux.verify.conf.ex" "$TMUX_DIR/verify.conf"
    log "Installed ~/.config/tmux/verify.conf"
elif [[ -f "$TMUX_DIR/verify.conf" ]]; then
    log "Keeping existing ~/.config/tmux/verify.conf"
fi

YAZI_DEST="$HOME/.config/yazi/yazi.toml"
mkdir -p "$(dirname "$YAZI_DEST")"
if [[ ! -f "$YAZI_DEST" ]] && [[ -f "$CONFIG_DIR/yazi.ex.toml" ]]; then
    cp "$CONFIG_DIR/yazi.ex.toml" "$YAZI_DEST"
    log "Installed ~/.config/yazi/yazi.toml from yazi.ex.toml"
elif [[ -f "$YAZI_DEST" ]]; then
    log "Keeping existing ~/.config/yazi/yazi.toml"
fi

GIT_VERIF="$HOME/.config/git/verification"
mkdir -p "$(dirname "$GIT_VERIF")"
if [[ ! -f "$GIT_VERIF" ]] && [[ -f "$CONFIG_DIR/git.ex.config" ]]; then
    cp "$CONFIG_DIR/git.ex.config" "$GIT_VERIF"
    log "Installed ~/.config/git/verification (enable: git config --global include.path ~/.config/git/verification)"
elif [[ -f "$GIT_VERIF" ]]; then
    log "Keeping existing ~/.config/git/verification"
fi

if [[ -f "$GIT_VERIF" ]] && command -v git &>/dev/null; then
    if ! git config --global --get-all include.path 2>/dev/null | grep -qF "$GIT_VERIF"; then
        git config --global include.path "$GIT_VERIF"
        log "Set git config include.path for delta"
    else
        log "git include.path already enables delta"
    fi
fi

chmod +x "$CONFIG_DIR/bin/agent-verify-layout.sh" 2>/dev/null || true
chmod +x "$CONFIG_DIR/bin/fzf-preview.sh" 2>/dev/null || true

# =============================================================================
# 13. Git commit the new structure
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
echo "  5. Git delta: git config --global include.path ~/.config/git/verification"
echo "     (migrate sets this automatically when verification file exists)"
echo ""
echo "Key files created:"
echo "  - $CONFIG_DIR/env.sh"
echo "  - $CONFIG_DIR/aliases.sh"
echo "  - $CONFIG_DIR/bin/README.md        ← Script reference (migrate, check, recover, verify)"
echo "  - $CONFIG_DIR/bin/migrate.sh   ← Master script (git tracked)"
echo "  - ~/.zprofile, ~/.zshenv, ~/.profile, ~/.bash_profile (when missing or managed)"
echo "  - ~/.config/starship.toml (from starship.ex.toml when absent)"
echo "  - ~/.config/tmux/tmux.conf + verify.conf (from Omarchy + overlay when absent)"
echo "  - ~/.config/yazi/yazi.toml (from yazi.ex.toml when absent)"
echo "  - ~/.config/git/verification (from git.ex.config when absent)"
echo "  - ~/.zshrc (clean, pure zsh + starship)"
echo "  - ~/.bashrc (minimal)"
echo "  - ~/.config/fish/config.fish"
echo ""
echo "Omarchy is respected and sourced early. Modern tools are layered on top."
echo ""
echo "Future runs: ~/.config/shell/bin/migrate.sh"
echo "One-liner install: curl -fsSL $SHELL_CONFIG_RAW/bin/migrate.sh | bash"
echo "Force rc regen: ~/.config/shell/bin/migrate.sh --force-rc"
echo "==================================================================="
