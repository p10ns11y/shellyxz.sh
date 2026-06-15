#!/usr/bin/env bash
# Scaffold a new shell environment preset from the generic stub.
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
name="${1:-}"

if [[ -z "$name" || "$name" == "-h" || "$name" == "--help" ]]; then
    echo "Usage: scaffold-environment.sh <preset-name>"
    echo "Creates environments/<name>/{env,bash,zsh,fish}.sh from generic stubs."
    exit 0
fi

case "$name" in
    generic|omarchy|core|templates|bin|local|environments)
        echo "ERROR: reserved name: $name" >&2
        exit 1
        ;;
esac

dest="$CONFIG_DIR/environments/$name"
if [[ -d "$dest" ]]; then
    echo "ERROR: environment already exists: $dest" >&2
    exit 1
fi

mkdir -p "$dest"
for f in env.sh bash.sh zsh.sh fish.sh; do
    cp "$CONFIG_DIR/environments/generic/$f" "$dest/$f"
done

cat > "$dest/README.preset" << EOF
# Environment preset: $name
# Edit env.sh for PATH/exports; bash.sh, zsh.sh, fish.sh for interactive hooks.
# Enable: SHELL_ENVIRONMENT="$name" in ~/.config/shell/environment
EOF

echo "Created environment preset: $dest"
echo "Next: edit files in $dest, then set SHELL_ENVIRONMENT=\"$name\" in environment"
