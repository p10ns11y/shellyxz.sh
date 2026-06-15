#!/usr/bin/env bash
# Install core modules, environment presets, shims from templates.

T="$CONFIG_DIR/templates"

# Core modules
for f in lib.sh path.sh env.sh aliases.sh functions.sh; do
    install_if_missing "$T/core/$f" "$CONFIG_DIR/core/$f"
done

# Root shims (install from repo when missing after bootstrap)
for f in env.sh lib.sh aliases.sh functions.sh personal.sh; do
    install_if_missing "$CONFIG_DIR/$f" "$CONFIG_DIR/$f"
done

install_if_missing "$CONFIG_DIR/environment.example" "$CONFIG_DIR/environment.example"
install_if_missing "$CONFIG_DIR/local/personal.sh" "$CONFIG_DIR/local/personal.sh"

mkdir -p "$CONFIG_DIR"/{backups,completions,local,core,environments/generic,environments/omarchy,templates/login,templates/core}

if [[ ! -d "$CONFIG_DIR/.git" ]]; then
    (cd "$CONFIG_DIR" && git init -q)
    log "Initialized git repo in $CONFIG_DIR"
fi
