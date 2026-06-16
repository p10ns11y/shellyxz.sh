#!/usr/bin/env bash
# In-pane launcher with confirm gates for verification cockpit panes.
# Usage: verify-pane-launch.sh TIER COMMAND
set -euo pipefail

TIER="${1:?tier}"
CMD="${2:?command}"

case "$TIER" in
    monitor | watch)
        eval "$CMD"
        ;;
    verify)
        printf '\033[38;5;214m[CONFIRM]\033[0m %s\n' "$CMD"
        printf 'Run? [y/N] '
        read -r ans
        case "$ans" in
            y | Y | yes | YES) eval "$CMD" ;;
            *) echo 'Skipped.' ;;
        esac
        ;;
    mutate)
        if [ "${AGENT_VERIFY_LAUNCH_MUTATE:-0}" != "1" ]; then
            echo '[BLOCKED] mutate tier — use: av --launch-mutate'
            exit 1
        fi
        printf '\033[38;5;196m[MUTATE — HIGH RISK]\033[0m %s\n' "$CMD"
        printf 'Type YES to run: '
        read -r ans
        if [ "$ans" = "YES" ]; then
            eval "$CMD"
        else
            echo 'Skipped.'
        fi
        ;;
    *)
        echo "verify-pane-launch: unknown tier: $TIER" >&2
        exit 1
        ;;
esac
