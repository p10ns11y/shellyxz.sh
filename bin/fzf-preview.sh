#!/usr/bin/env sh
# fzf --preview helper (bat with line numbers). Keeps FZF_DEFAULT_OPTS shellcheck-clean.
exec bat --style=numbers --color=always --line-range :300 "$@"
