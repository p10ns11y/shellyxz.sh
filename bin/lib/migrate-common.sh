#!/usr/bin/env bash
# Shared helpers for migrate.sh and task scripts.

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/shell}"
MANAGED_MARKER="${MANAGED_MARKER:-Managed by ~/.config/shell/bin/migrate.sh}"
SHELL_CONFIG_RAW="${SHELL_CONFIG_RAW:-https://raw.githubusercontent.com/p10ns11y/shellyxz.sh/refs/heads/master}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

is_piped_install() {
    local base
    base="$(basename "${0:-}")"
    [[ "$base" == "bash" || "$base" == "sh" || "$base" == "dash" ]]
}

should_write_rc() {
    local dest="$1"
    [[ ! -f "$dest" ]] && return 0
    [[ "${FORCE_RC:-false}" == true ]] && return 0
    [[ "${SYNC_RC:-false}" == true ]] && grep -qF "$MANAGED_MARKER" "$dest" 2>/dev/null
}

write_rc_or_skip() {
    local dest="$1" label="$2"
    if should_write_rc "$dest"; then
        return 0
    fi
    warn "Keeping existing $label (not managed — use --force-rc or --sync-rc)"
    return 1
}

install_if_missing() {
    local src="$1" dest="$2"
    if [[ -f "$dest" ]]; then
        log "Keeping existing $(basename "$dest")"
        return 0
    fi
    if [[ ! -f "$src" ]]; then
        warn "Template missing: $src"
        return 1
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    log "Installed: $dest"
}

install_managed_rc() {
    local src="$1"
    local dest="$2"
    local label="${3:-$dest}"
    if write_rc_or_skip "$dest" "$label"; then
        mkdir -p "$(dirname "$dest")"
        cp "$src" "$dest"
        log "Installed managed: $dest"
    fi
}

bootstrap_from_remote() {
    local rel dest dir url
    local files=(
        lib.sh env.sh aliases.sh functions.sh personal.sh
        core/lib.sh core/path.sh core/path.contract core/env.sh core/aliases.sh core/functions.sh
        environments/generic/env.sh environments/generic/bash.sh environments/generic/zsh.sh environments/generic/fish.sh
        environments/omarchy/env.sh environments/omarchy/bash.sh environments/omarchy/zsh.sh environments/omarchy/fish.sh
        environment.example
        local/personal.sh
        templates/zshrc templates/bashrc templates/fish.config.fish
        templates/login/zprofile templates/login/zshenv templates/login/profile templates/login/bash_profile
        templates/core/lib.sh templates/core/path.sh templates/core/path.contract templates/core/env.sh templates/core/aliases.sh templates/core/functions.sh
        bin/migrate.sh bin/lib/migrate-common.sh
        bin/tasks/backup.sh bin/tasks/install-tools.sh bin/tasks/install-modules.sh
        bin/tasks/install-rc.sh bin/tasks/scaffold.sh bin/tasks/git-commit.sh
        bin/check-shell.sh bin/check-template-sync.sh bin/scaffold-environment.sh
        bin/recover-shell.sh bin/README.md
        bin/agent-verify-layout.sh bin/fzf-preview.sh
        environments/README.md
        README.md shell.md SHELL-env-var-behavior.md VERIFICATION.md
        starship.ex.toml tmux.verify.conf.ex yazi.ex.toml git.ex.config .gitignore
    )

    if ! command -v curl &>/dev/null; then
        warn "curl not found — cannot bootstrap from $SHELL_CONFIG_RAW"
        return 1
    fi

    log "Bootstrapping ~/.config/shell from $SHELL_CONFIG_RAW"
    mkdir -p "$CONFIG_DIR/bin" "$CONFIG_DIR/core" "$CONFIG_DIR/environments/generic" "$CONFIG_DIR/environments/omarchy"
    mkdir -p "$CONFIG_DIR/templates/login" "$CONFIG_DIR/templates/core" "$CONFIG_DIR/local"
    mkdir -p "$CONFIG_DIR/bin/lib" "$CONFIG_DIR/bin/tasks"

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

    chmod +x "$CONFIG_DIR/bin/"*.sh "$CONFIG_DIR/bin/tasks/"*.sh 2>/dev/null || true
    success "Remote bootstrap complete"
}

config_needs_bootstrap() {
    local f
    for f in core/lib.sh core/env.sh bin/check-shell.sh; do
        [[ -f "$CONFIG_DIR/$f" ]] || return 0
    done
    return 1
}
