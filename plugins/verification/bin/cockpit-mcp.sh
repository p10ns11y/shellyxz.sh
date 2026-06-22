#!/usr/bin/env bash
# Headless verification bridge — same verbs as ab/av/at for MCP, CI, and IDE hosts.
# Usage: cockpit-mcp.sh verify|test|scan [directory]
set -euo pipefail

VERB="${1:-}"
DIR="${2:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_LIB="$(cd "$SCRIPT_DIR/../lib" && pwd)"

usage() {
    cat <<EOF
Usage: cockpit-mcp.sh verify|test|scan [directory]

Host-agnostic verification verbs (tmux is one renderer; this is headless):

  verify   Run project verification gates (check-shell, template sync, manifest verify panes)
  test     Run priority tests (run-project-tests.sh — python optional)
  scan     Structured rg/dust/JSON sweep (agent_scan without tmux)

Examples:
  cockpit-mcp.sh verify .
  cockpit-mcp.sh test ~/Work/my-app
  cockpit-mcp.sh scan .
EOF
}

# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../lib/verify-launch.sh"

case "$VERB" in
    verify | test | scan) ;;
    -h | --help | '')
        usage
        exit 0
        ;;
    *)
        if [ -d "$VERB" ]; then
            DIR="$VERB"
            VERB="${2:-verify}"
            [ "$VERB" = verify ] || [ "$VERB" = test ] || [ "$VERB" = scan ] || {
                usage >&2
                exit 1
            }
        else
            echo "cockpit-mcp: unknown verb: $VERB" >&2
            usage >&2
            exit 1
        fi
        ;;
esac

DIR="$(verify_workflow_root "$DIR")"
COCKPIT="${DIR}/.agents/verification/cockpit.yaml"

cmd_verify() {
    local failures=0
    echo "=== cockpit-mcp verify: $DIR ==="
    if [ -x "$DIR/bin/check-shell.sh" ]; then
        "$DIR/bin/check-shell.sh" || failures=$((failures + 1))
    fi
    if [ -x "$DIR/bin/check-template-sync.sh" ]; then
        "$DIR/bin/check-template-sync.sh" || failures=$((failures + 1))
    fi
    if command -v python >/dev/null 2>&1 \
        && [ -f "$PLUGIN_LIB/parse-project-tests.py" ] \
        && [ -f "$COCKPIT" ]; then
        python "$PLUGIN_LIB/parse-project-tests.py" --root "$DIR" >/dev/null \
            && ok_manifest=1 || ok_manifest=0
        if [ "$ok_manifest" = 1 ]; then
            echo "OK:   cockpit.yaml test manifest parses"
        else
            echo "WARN: cockpit.yaml test section missing or invalid"
        fi
    elif [ -f "$COCKPIT" ]; then
        echo "WARN: python required to validate cockpit.yaml (manifest present)"
    fi
    if [ "$failures" -eq 0 ]; then
        echo "=== cockpit-mcp verify: OK ==="
        return 0
    fi
    echo "=== cockpit-mcp verify: FAILED ($failures gate(s)) ==="
    return 1
}

cmd_test() {
    local runner="$DIR/bin/run-project-tests.sh"
    [ -x "$runner" ] || runner="$SCRIPT_DIR/run-project-tests.sh"
    echo "=== cockpit-mcp test: $DIR ==="
    exec "$runner" "$DIR"
}

cmd_scan() {
    echo "=== cockpit-mcp scan: $DIR ==="
    echo "=== rg sweep ==="
    if command -v rg >/dev/null 2>&1; then
        rg -n 'TODO|FIXME|panic!|unwrap\(|ERROR|error:' "$DIR" 2>/dev/null | head -30 || true
    else
        echo "rg not found"
    fi
    echo "=== dust ==="
    if command -v dust >/dev/null 2>&1; then
        dust -s "$DIR" 2>/dev/null | head -15 || true
    fi
    for f in "$DIR/report.json" "$DIR/output.json"; do
        if [ -f "$f" ]; then
            echo "=== $f ==="
            if command -v jq >/dev/null 2>&1; then
                jq '.summary // .issues // .' "$f" 2>/dev/null || head -20 "$f"
            else
                head -20 "$f"
            fi
        fi
    done
}

case "$VERB" in
    verify) cmd_verify ;;
    test) cmd_test ;;
    scan) cmd_scan ;;
esac
