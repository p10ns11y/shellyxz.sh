#!/usr/bin/env bash
# Arch-only optional tool install via paru.

if command -v paru &>/dev/null; then
    if ! command -v yazi &>/dev/null; then
        log "Installing yazi via paru..."
        paru -S --needed --noconfirm yazi || warn "Failed to install yazi"
    fi
    if ! command -v thefuck &>/dev/null; then
        log "Installing thefuck via paru..."
        paru -S --needed --noconfirm thefuck || warn "Failed to install thefuck"
    fi
    if ! command -v procs &>/dev/null; then
        log "Installing procs via paru..."
        paru -S --needed --noconfirm procs || warn "Failed to install procs"
    fi
    if ! command -v difft &>/dev/null; then
        log "Installing difftastic via paru..."
        paru -S --needed --noconfirm difftastic || warn "Failed to install difftastic"
    fi
else
    warn "paru not found — skip auto-install (yazi, thefuck, procs, difftastic). Install manually on non-Arch."
fi
