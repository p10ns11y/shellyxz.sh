#!/usr/bin/env sh
# Single allowlist for sh test runners — keep in sync with parse-project-tests.py ALLOWED_RUNNERS.
# Contract: bin/test/parse-project-tests.test.sh

# shellcheck disable=SC2034
TEST_ALLOWLIST_RUNNERS='pnpm npm cargo pytest python python3 bash sh echo'

command_allowed() {
    local cmd="$1" first
    cmd="${cmd#"${cmd%%[![:space:]]*}"}"
    [ -n "$cmd" ] || return 1
    case "$cmd" in
        *';'*|*'|'*|*'`'*|*'$('*|*'>'*|*'<'*) return 1 ;;
    esac
    first="${cmd%% *}"
    case "$first" in
        bin/*|./*|/*) return 0 ;;
    esac
    for runner in $TEST_ALLOWLIST_RUNNERS; do
        [ "$first" = "$runner" ] && return 0
    done
    return 1
}

run_allowlisted_command() {
    local cmd="$1"
    if ! command_allowed "$cmd"; then
        if [ -z "${cmd//[[:space:]]/}" ]; then
            echo "run-project-tests: rejected command: $cmd" >&2
        else
            echo "run-project-tests: command not allowlisted: ${cmd%% *}" >&2
        fi
        return 1
    fi
    bash -c "$cmd"
}
