#!/usr/bin/env bash
# Resolve project build agent command from .agents/verification/cockpit.yaml
# (cockpits.build). Sourced by agent-build-layout.sh.
#
# Priority for launch: CLI args > cockpit.yaml build.command > SHELL_AGENT_BUILD_CMD
# Priority for continue: cockpit.yaml build.continue_command > SHELL_AGENT_BUILD_CONTINUE_CMD
#                        > single-word build cmd + " -c"
#
# YAML subset (under cockpits:):
#   build:
#     command: nvim .
#     continue_command: nvim .    # optional

# Print field value from cockpits.build (command | continue_command). Empty if absent.
project_build_field() {
    local root="${1:?root}"
    local field="${2:?field}" # command | continue_command
    local cockpit="${root}/.agents/verification/cockpit.yaml"
    local in_cockpits=0 in_build=0 line stripped indent

    [ -f "$cockpit" ] || return 0

    while IFS= read -r line || [ -n "$line" ]; do
        stripped="${line#"${line%%[![:space:]]*}"}"
        [ -z "$stripped" ] && continue
        case "$stripped" in
            \#*) continue ;;
        esac
        indent=$((${#line} - ${#stripped}))

        if [ "$stripped" = "cockpits:" ] || [ "$stripped" = "cockpits: " ]; then
            in_cockpits=1
            in_build=0
            continue
        fi

        if [ "$in_cockpits" = 1 ]; then
            # Leave cockpits when a top-level key appears (indent 0, not a list item)
            if [ "$indent" -eq 0 ] && [[ "$stripped" != cockpits:* ]]; then
                break
            fi
            if [ "$stripped" = "build:" ] || [[ "$stripped" == build:* ]]; then
                in_build=1
                continue
            fi
            if [ "$in_build" = 1 ]; then
                # Sibling under cockpits (verify:/test:) ends build block
                if [ "$indent" -le 2 ] && [[ "$stripped" == *: ]] && [[ "$stripped" != ${field}:* ]] \
                    && [ "$stripped" != "build:" ]; then
                    case "$stripped" in
                        verify: | test: | verify:* | test:*)
                            break
                            ;;
                    esac
                fi
                if [[ "$stripped" == "${field}:"* ]]; then
                    printf '%s' "${stripped#"${field}":}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'\'']//;s/["'\'']$//'
                    return 0
                fi
            fi
        fi
    done <"$cockpit"
    return 0
}

# Resolve default build command for workflow root. Prints command; exit 1 if none.
project_resolve_build_cmd() {
    local root="${1:?root}"
    local from_project

    from_project="$(project_build_field "$root" command)"
    if [ -n "$from_project" ]; then
        printf '%s' "$from_project"
        return 0
    fi
    if [ -n "${SHELL_AGENT_BUILD_CMD:-}" ]; then
        printf '%s' "$SHELL_AGENT_BUILD_CMD"
        return 0
    fi
    echo "project_resolve_build_cmd: set cockpits.build.command in .agents/verification/cockpit.yaml or SHELL_AGENT_BUILD_CMD" >&2
    return 1
}

# Resolve continue command for workflow root.
project_resolve_build_continue_cmd() {
    local root="${1:?root}"
    local from_project build_cmd

    from_project="$(project_build_field "$root" continue_command)"
    if [ -n "$from_project" ]; then
        printf '%s' "$from_project"
        return 0
    fi
    if [ -n "${SHELL_AGENT_BUILD_CONTINUE_CMD:-}" ]; then
        printf '%s' "$SHELL_AGENT_BUILD_CONTINUE_CMD"
        return 0
    fi

    build_cmd="$(project_resolve_build_cmd "$root")" || return 1
    case "$build_cmd" in
        *' '*)
            echo "project_resolve_build_continue_cmd: set cockpits.build.continue_command or SHELL_AGENT_BUILD_CONTINUE_CMD for multi-word build command: $build_cmd" >&2
            return 1
            ;;
    esac
    printf '%s -c' "$build_cmd"
    return 0
}
