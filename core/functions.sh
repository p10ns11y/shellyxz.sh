#!/usr/bin/env bash
# ~/.config/shell/core/functions.sh
# ~/.config/shell/functions.sh
# Extra functions. Sourced by bash and zsh rc files; fish loads via bass.

# Print PATH entries one per line (handy when debugging precedence)
path_debug() {
    _n=$(printf '%s\n' "$PATH" | tr ':' '\n' | awk 'NF' | wc -l)
    _u=$(printf '%s\n' "$PATH" | tr ':' '\n' | awk 'NF' | sort -u | wc -l)
    _d=$((_n - _u))
    printf '%s entries (%s unique' "$_n" "$_u"
    [ "$_d" -gt 0 ] && printf ', %s duplicate(s)' "$_d"
    printf ')\n'
    echo "$PATH" | tr ':' '\n' | nl -ba
    if command -v path_contract_verify >/dev/null 2>&1; then
        echo ""
        if path_contract_verify --warn-only 2>/dev/null; then
            echo "Contract: OK"
        else
            echo "Contract: mismatch (run path_check for details)"
        fi
    fi
    unset _n _u _d
}

# Verify live PATH against core/path.contract (runtime 1:1 check)
path_check() {
    _login=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --login) _login=1; shift ;;
            *) shift ;;
        esac
    done
    if [ "$_login" -eq 1 ] && command -v zsh >/dev/null 2>&1; then
        exec zsh -lic 'path_contract_verify; path_shadow_report --warn'
    fi
    if command -v path_contract_verify >/dev/null 2>&1; then
        path_contract_verify || return 1
        path_shadow_report --warn || true
        return 0
    fi
    echo "path_contract_verify not available — source env.sh first" >&2
    return 1
}

# Shell identity diagnostics.
# $SHELL is often stale after chsh + exec or in long-lived terminal sessions.
# It is set by the *initial login/terminal process* and inherited; exec does not always update it.
# Use this (or the check script) instead of trusting `echo $SHELL`.
shell_debug() {
    echo "=== shell identity ==="
    echo "Invoked as (\$0):          $0"
    echo "\$SHELL (env var):        $SHELL"
    echo "SHELL_TRUTH_SEEKER:       ${SHELL_TRUTH_SEEKER:-1} (set 0 in env to keep inherited \$SHELL)"
    local login_sh
    login_sh=$(getent passwd "${USER:-$(id -un)}" 2>/dev/null | cut -d: -f7 || echo unknown)
    echo "Login shell (passwd):     $login_sh"
    echo "Current process (ps):     $(ps -p $$ -o pid,comm,args 2>/dev/null || echo 'ps unavailable')"
    echo "SHELL_ENVIRONMENT:        ${SHELL_ENVIRONMENT:-unset}"
    if command -v detect_editor_terminal >/dev/null 2>&1; then
        detect_editor_terminal 2>/dev/null
        case "${SHELL_IN_EDITOR_TERMINAL:-no}" in
            yes) echo "Editor terminal:          yes (mise hook skipped; shims on PATH)" ;;
            no)  echo "Editor terminal:          no" ;;
        esac
    fi
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

# Fuzzy-open file in $EDITOR (complements Omarchy eff).
vf() {
    command -v fzf >/dev/null 2>&1 || { echo "vf: fzf not found" >&2; return 1; }
    local f preview
    if command -v bat >/dev/null 2>&1; then
        preview="bat --style=numbers --color=always {}"
    else
        preview="cat {}"
    fi
    if command -v fd >/dev/null 2>&1; then
        f="$(fd --type f --hidden --exclude .git 2>/dev/null | fzf --preview "$preview")"
    else
        f="$(find . -type f 2>/dev/null | fzf --preview "$preview")"
    fi
    [ -n "$f" ] && "${EDITOR:-nvim}" "$f"
}

# Canonical workflow root (layout walk-up → git toplevel → cwd). Used by ab / av / agent_scan.
_verify_workflow_root() {
    local script="${SHELL_CONFIG_BIN:-$HOME/.config/shell/bin}/verify-workflow-root.sh"
    if [ ! -x "$script" ]; then
        echo "_verify_workflow_root: missing $script" >&2
        return 1
    fi
    "$script" "${1:-.}"
}

# Print canonical workflow root (optional directory; default pwd with walk-up).
verify_workflow_root() {
    _verify_workflow_root "${1:-.}"
}

# Quick structured scan after agent output (rg + dust + JSON reports).
agent_scan() {
    local dir
    dir="$(_verify_workflow_root "${1:-.}")" || return 1
    echo "=== rg sweep ==="
    if command -v rg >/dev/null 2>&1; then
        rg -n 'TODO|FIXME|panic!|unwrap\(|ERROR|error:' "$dir" 2>/dev/null | head -30
    else
        echo "rg not found"
    fi
    echo "=== dust ==="
    if command -v dust >/dev/null 2>&1; then
        dust -s "$dir" 2>/dev/null | head -15
    fi
    for f in "$dir/report.json" "$dir/output.json"; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            if command -v jq >/dev/null 2>&1; then
                if command -v bat >/dev/null 2>&1; then
                    jq '.summary // .issues // .' "$f" 2>/dev/null | bat -l json
                else
                    jq '.summary // .issues // .' "$f" 2>/dev/null
                fi
            else
                head -20 "$f"
            fi
        fi
    done
}

# Refuse cockpit layouts in editor integrated terminals (Cursor phantom-tab UX).
_agent_tmux_guard() {
    if command -v detect_editor_terminal >/dev/null 2>&1; then
        detect_editor_terminal 2>/dev/null
        if [ "${SHELL_IN_EDITOR_TERMINAL:-no}" = yes ]; then
            echo "Run in Ghostty/tmux (t or Super+Alt+Return), not Cursor integrated terminal." >&2
            return 1
        fi
    fi
    if [ -z "${TMUX:-}" ]; then
        echo "Start tmux first (t or Super+Alt+Return)" >&2
        return 1
    fi
}

# Agent build layout — full-pane agent TUI (grok default). Requires native terminal + tmux.
agent_build() {
    _agent_tmux_guard || return 1
    local script="$HOME/.config/shell/bin/agent-build-layout.sh"
    if [ ! -x "$script" ]; then
        echo "agent_build: missing $script" >&2
        return 1
    fi
    local dir="." args=() _dir_set=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -c | --continue)
                args+=(--continue)
                shift
                ;;
            *)
                if [ -z "$_dir_set" ] && { [ "$1" = . ] || [ -d "$1" ]; }; then
                    dir="$1"
                    _dir_set=1
                    shift
                else
                    args+=(-- "$@")
                    break
                fi
                ;;
        esac
    done
    dir="$(_verify_workflow_root "$dir")" || return 1
    "$script" "$dir" "${args[@]}"
}

# Deprecated name — use agent_build
agent_work() {
    agent_build "$@"
}

# Return to build window and continue the agent session (grok -c).
agent_back() {
    agent_build -c
}

# Open verification cockpit layout in tmux (requires native terminal + active tmux).
# --scan: run agent_scan in console pane (opt-in).
# --generic: skip project .agents/verification/tmux-layout.sh
# --launch-mutate: allow mutate-tier panes to prompt for destructive commands
agent_verify() {
    _agent_tmux_guard || return 1
    local dir="." do_scan=0 use_generic=0 launch_mutate=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --scan)
                do_scan=1
                shift
                ;;
            --generic)
                use_generic=1
                shift
                ;;
            --launch-mutate)
                launch_mutate=1
                shift
                ;;
            *)
                if [ "$dir" = . ] && { [ "$1" = . ] || [ -d "$1" ]; }; then
                    dir="$1"
                    shift
                else
                    echo "agent_verify: unknown argument: $1" >&2
                    return 1
                fi
                ;;
        esac
    done
    dir="$(_verify_workflow_root "$dir")" || return 1
    local script="$HOME/.config/shell/bin/agent-verify-layout.sh"
    if [ ! -x "$script" ]; then
        echo "agent_verify: missing $script" >&2
        return 1
    fi
    local args=()
    if [ "$use_generic" = 1 ]; then
        args+=(--generic)
    fi
    if [ "$do_scan" = 1 ]; then
        tmux set-option @workflow_rescan 1
    else
        tmux set-option @workflow_rescan 0
    fi
    local env_args=()
    if [ "$do_scan" = 1 ]; then
        env_args+=(AGENT_VERIFY_RESCAN=1)
    fi
    if [ "$launch_mutate" = 1 ]; then
        env_args+=(AGENT_VERIFY_LAUNCH_MUTATE=1)
    fi
    if [ "${#env_args[@]}" -gt 0 ]; then
        env "${env_args[@]}" "$script" "$dir" "${args[@]}"
    else
        "$script" "$dir" "${args[@]}"
    fi
}

# Test cockpit — btop left + project tests right (at / agent_test). Requires native terminal + tmux.
agent_test() {
    _agent_tmux_guard || return 1
    local script="$HOME/.config/shell/bin/agent-test-layout.sh"
    if [ ! -x "$script" ]; then
        echo "agent_test: missing $script" >&2
        return 1
    fi
    local dir="." args=() _dir_set=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --watch)
                args+=(--watch)
                shift
                ;;
            *)
                if [ -z "$_dir_set" ] && { [ "$1" = . ] || [ -d "$1" ]; }; then
                    dir="$1"
                    _dir_set=1
                    shift
                else
                    echo "agent_test: unknown argument: $1" >&2
                    return 1
                fi
                ;;
        esac
    done
    dir="$(_verify_workflow_root "$dir")" || return 1
    "$script" "$dir" "${args[@]}"
}

# Portable reload helper for the current shell.
# Works in bash and zsh. In zsh, ~/.zshrc overrides this with an enhanced
# version that pre-clears 'n'/'ga'/'gd'/'reload' (and runs unfunction) before
# re-sourcing, to prevent "defining function based on alias" errors on reload.
reload() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.zshrc" && echo "zshrc reloaded"
    elif [ -n "${BASH_VERSION:-}" ]; then
        # shellcheck disable=SC1091
        source "$HOME/.bashrc" && echo "bashrc reloaded"
        # Help people who are in the wrong shell after chsh and keep typing "reload"
        local u login_sh
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
