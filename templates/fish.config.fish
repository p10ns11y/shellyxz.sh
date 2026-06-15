# Managed by ~/.config/shell/bin/migrate.sh
# ~/.config/fish/config.fish

set -gx SHELL (command -v fish 2>/dev/null; or echo /usr/bin/fish)

if test -f "$HOME/.config/shell/env.sh"
    bass source "$HOME/.config/shell/env.sh" 2>/dev/null; or true
end

if type -q direnv
    direnv hook fish | source
end

# Environment hooks (bash-syntax preset files via bass)
if test -n "$SHELL_ENVIRONMENT"
    for _preset in (string split " " $SHELL_ENVIRONMENT)
        set -l _ef "$HOME/.config/shell/environments/$_preset/fish.sh"
        if test -f "$_ef"
            bass source "$_ef" 2>/dev/null; or true
        end
    end
end

if test -f "$HOME/.config/shell/functions.sh"
    bass source "$HOME/.config/shell/functions.sh" 2>/dev/null; or true
end

if test -f "$HOME/.config/shell/aliases.sh"
    bass source "$HOME/.config/shell/aliases.sh" 2>/dev/null; or true
end

if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init fish | source
end

if type -q mamba
    mamba shell hook --shell fish | source
end

if type -q mise
    mise activate fish | source
end

if type -q fzf
    fzf --fish | source
end

if type -q thefuck
    thefuck --alias | source
end
