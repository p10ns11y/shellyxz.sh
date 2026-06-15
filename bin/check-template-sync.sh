#!/usr/bin/env bash
# Compare templates/ to installed core modules (drift detection).
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
T="$CONFIG_DIR/templates/core"
errors=0

fail() { echo "DRIFT: $1"; errors=$((errors + 1)); }
ok() { echo "OK:   $1"; }

echo "=== template sync check ==="

for f in lib.sh path.sh env.sh aliases.sh functions.sh; do
    if [[ ! -f "$T/$f" ]]; then
        fail "missing template $T/$f"
        continue
    fi
    if [[ ! -f "$CONFIG_DIR/core/$f" ]]; then
        fail "missing installed core/$f"
        continue
    fi
    if diff -q "$T/$f" "$CONFIG_DIR/core/$f" >/dev/null 2>&1; then
        ok "core/$f matches template"
    else
        fail "core/$f differs from templates/core/$f"
    fi
done

echo "=== summary: $errors drift(s) ==="
[[ "$errors" -eq 0 ]]
