#!/usr/bin/env sh
# ~/.config/shell/functions.sh
# Extra functions. Currently minimal because Omarchy covers most needs.

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
    local login_sh
    login_sh=$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7 || echo unknown)
    echo "Login shell (passwd):     $login_sh"
    echo "Current process (ps):     $(ps -p $$ -o pid,comm,args 2>/dev/null || echo 'ps unavailable')"
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

# Portable reload helper for the current shell.
# Works in bash and zsh. In zsh, ~/.zshrc overrides this with an enhanced
# version that pre-clears 'n'/'ga'/'gd'/'reload' (and runs unfunction) before
# re-sourcing, to prevent "defining function based on alias" errors on reload.
reload() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        source "$HOME/.zshrc" && echo "zshrc reloaded"
    elif [ -n "${BASH_VERSION:-}" ]; then
        source "$HOME/.bashrc" && echo "bashrc reloaded"
        # Help people who are in the wrong shell after chsh and keep typing "reload"
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