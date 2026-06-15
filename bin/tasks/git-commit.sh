#!/usr/bin/env bash
# Best-effort git commit in config repo.

(
    cd "$CONFIG_DIR" || exit 0
    git add -A
    git rm -r --cached backups/ 2>/dev/null || true
    git commit -m "Shell config: modular core + environments" --quiet 2>/dev/null || true
)
