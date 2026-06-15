#!/usr/bin/env sh
# fzf --preview helper: bat for files, highlighted shell for history lines.
_line="${*:-}"

# Existing file → bat with line numbers
if [ $# -eq 1 ] && [ -f "$1" ]; then
    exec bat --style=numbers --color=always --line-range :300 "$1"
fi

# History lines (e.g. "363  source ~/.zshrc") → strip index, show as shell
_line=$(printf '%s\n' "$_line" | sed 's/^[[:space:]]*[0-9]\+[[:space:]]\+//')
printf '%s\n' "$_line" | bat --style=numbers --color=always --language=sh 2>/dev/null \
    || printf '%s\n' "$_line"
