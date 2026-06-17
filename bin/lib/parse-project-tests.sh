#!/usr/bin/env bash
# Resolve test plan JSON — prefers python3 parser; minimal bash fallback for tests.yaml.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER_PY="${SCRIPT_DIR}/parse-project-tests.py"

parse_project_tests_json() {
    local root="${1:?root}"
    local cockpit="${root}/.agents/verification/cockpit.yaml"
    local tests="${root}/.agents/verification/tests.yaml"

    if command -v python3 >/dev/null 2>&1 && [ -f "$PARSER_PY" ]; then
        if [ -f "$cockpit" ] || [ -f "$tests" ]; then
            python3 "$PARSER_PY" --root "$root"
        else
            python3 "$PARSER_PY" --discover "$root"
        fi
        return 0
    fi

    _parse_tests_yaml_fallback "$root"
}

_parse_tests_yaml_fallback() {
    local root="$1"
    local manifest="${root}/.agents/verification/tests.yaml"
    local max_run=2
    local tests_json="[]"

    if [ ! -f "$manifest" ]; then
        printf '{"max_run":2,"tests":[{"id":"none","priority":1,"command":"echo at: install python3 for test discovery","label":"python3 missing"}]}\n'
        return 0
    fi

    max_run="$(awk -F: '/^[[:space:]]*max_run:/{gsub(/ /,"",$2); print $2; exit}' "$manifest")"
    [ -n "$max_run" ] || max_run=2

    tests_json="$(
        awk -v root="$root" '
            function esc(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); return s }
            BEGIN { print "["; first=1 }
            /^[[:space:]]*- id:/ {
                if (id != "") {
                    if (!first) print ","
                    first=0
                    printf "{\"id\":\"%s\",\"priority\":%s,\"command\":\"%s\",\"label\":\"%s\"",
                        esc(id), (prio==""?"99":prio), esc(cmd), esc(lbl==""?id:lbl)
                    if (watch != "") printf ",\"watch_command\":\"%s\"", esc(watch)
                    printf "}"
                }
                id=$0; sub(/^[[:space:]]*- id:[[:space:]]*/, "", id)
                prio=""; cmd=""; watch=""; lbl=""
                next
            }
            /^[[:space:]]*priority:/ { sub(/.*priority:[[:space:]]*/, ""); prio=$0; next }
            /^[[:space:]]*command:/ { sub(/.*command:[[:space:]]*/, ""); cmd=$0; next }
            /^[[:space:]]*watch_command:/ { sub(/.*watch_command:[[:space:]]*/, ""); watch=$0; next }
            /^[[:space:]]*label:/ { sub(/.*label:[[:space:]]*/, ""); lbl=$0; next }
            END {
                if (id != "") {
                    if (!first) print ","
                    printf "{\"id\":\"%s\",\"priority\":%s,\"command\":\"%s\",\"label\":\"%s\"",
                        esc(id), (prio==""?"99":prio), esc(cmd), esc(lbl==""?id:lbl)
                    if (watch != "") printf ",\"watch_command\":\"%s\"", esc(watch)
                    printf "}"
                }
                print "\n]"
            }
        ' "$manifest"
    )"

    printf '{"max_run":%s,"tests":%s}\n' "$max_run" "$tests_json"
}
