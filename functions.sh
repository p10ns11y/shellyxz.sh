#!/usr/bin/env sh
# ~/.config/shell/functions.sh
# Extra functions. Currently minimal because Omarchy covers most needs.

# Print PATH entries one per line (handy when debugging precedence)
path_debug() {
    echo "$PATH" | tr ':' '\n' | nl -ba
}