#!/usr/bin/env bash
# Tests for verify_workflow_root (layout walk-up → git toplevel → cwd).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export VERIFY_LAUNCH_LIB_DIR="$ROOT/bin/lib"
# shellcheck source=/dev/null
source "$ROOT/bin/lib/verify-launch.sh"

TMP=""
failures=0

cleanup() {
    [ -n "$TMP" ] && rm -rf "$TMP"
}
trap cleanup EXIT

assert_eq() {
    local got="$1" want="$2" label="$3"
    if [ "$got" = "$want" ]; then
        echo "OK:   $label"
    else
        echo "FAIL: $label"
        echo "      want: $want"
        echo "      got:  $got"
        failures=$((failures + 1))
    fi
}

TMP="$(mktemp -d)"

# 1 — layout walk-up from nested subdir
LAYOUT_ROOT="$TMP/project-a"
LAYOUT_DIR="$LAYOUT_ROOT/nested/deep"
mkdir -p "$LAYOUT_DIR/.agents/verification"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' >"$LAYOUT_DIR/.agents/verification/tmux-layout.sh"
chmod +x "$LAYOUT_DIR/.agents/verification/tmux-layout.sh"
mkdir -p "$LAYOUT_DIR/subdir"
got="$(verify_workflow_root "$LAYOUT_DIR/subdir")"
assert_eq "$got" "$(cd "$LAYOUT_DIR" && pwd)" "layout walk-up wins over git/cwd"

# 2 — git toplevel when no layout
GIT_ROOT="$TMP/project-b"
mkdir -p "$GIT_ROOT/sub/dir"
git -C "$GIT_ROOT" init -q
git -C "$GIT_ROOT" config user.email test@test.local
git -C "$GIT_ROOT" config user.name test
touch "$GIT_ROOT/sub/dir/.keep"
git -C "$GIT_ROOT" add . && git -C "$GIT_ROOT" commit -q -m init
got="$(verify_workflow_root "$GIT_ROOT/sub/dir")"
assert_eq "$got" "$(cd "$GIT_ROOT" && pwd)" "git toplevel when no layout"

# 3 — plain directory fallback (not a git repo)
PLAIN="$TMP/plain-dir/leaf"
mkdir -p "$PLAIN"
got="$(verify_workflow_root "$PLAIN")"
assert_eq "$got" "$(cd "$PLAIN" && pwd)" "cwd fallback outside git"

# 4 — CLI wrapper matches library
WRAPPER="$ROOT/bin/verify-workflow-root.sh"
chmod +x "$WRAPPER"
got="$("$WRAPPER" "$LAYOUT_DIR/subdir")"
assert_eq "$got" "$(cd "$LAYOUT_DIR" && pwd)" "verify-workflow-root.sh wrapper"

if [ "$failures" -gt 0 ]; then
    echo "=== $failures test(s) failed ==="
    exit 1
fi

echo "=== all verify_workflow_root tests passed ==="
