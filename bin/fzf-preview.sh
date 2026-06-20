#!/usr/bin/env sh
# fzf --preview helper: bat for files, highlighted shell for history lines.
preview_input_line="${*:-}"

# Existing file → bat with line numbers
if [ $# -eq 1 ] && [ -f "$1" ]; then
    exec bat --style=numbers --color=always --line-range :300 "$1"
fi

# History lines (e.g. "363  source ~/.zshrc") → strip index, show as shell
preview_input_line=$(printf '%s\n' "$preview_input_line" | sed 's/^[[:space:]]*[0-9]\+[[:space:]]\+//')
printf '%s\n' "$preview_input_line" | bat --style=numbers --color=always --language=sh 2>/dev/null \
    || printf '%s\n' "$preview_input_line"
