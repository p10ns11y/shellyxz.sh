#!/usr/bin/env bash
# capture-shell-init.sh — detect installer pollution in rc files and route to shell modules.
set -euo pipefail

CONFIG_DIR="${HOME}/.config/shell"
MANAGED_MARKER="${MANAGED_MARKER:-Managed by ~/.config/shell/bin/migrate.sh}"
MANIFEST="${CONFIG_DIR}/templates/tool-init.manifest"
DRY_RUN=false
APPLY=false
FORCE=false
INSTALL_LOG=""

usage() {
    cat <<EOF
Usage: capture-shell-init.sh [--dry-run] [--apply] [--force] [--since-install LOG]

  (default)   Scan rc files for unmanaged init blocks
  --dry-run   Show routing recommendations only
  --apply     Move classified blocks into ~/.config/shell modules (backs up first)
  --force     Edit rc files without managed marker
  --since-install LOG  Parse installer log for "add to ~/.zshrc" hints

After capture: run ~/.config/shell/bin/check-shell.sh && path_check
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --apply) APPLY=true; shift ;;
        --force) FORCE=true; shift ;;
        --since-install) INSTALL_LOG="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

log() { printf '[capture] %s\n' "$1"; }
warn() { printf '[capture] WARN: %s\n' "$1" >&2; }

classify_line() {
    local line="$1"
    case "$line" in
        *'export PATH='*|*'PATH='*|*path_prepend*|*'.cargo/env'*|*'.local/bin/env'*|*'.vite-plus/env'*)
            echo "path.contract / core/env.sh"
            ;;
        alias\ *)
            echo "core/aliases.sh"
            ;;
        *'eval "$(mamba '*|*'eval "$(mise '*|*'eval "$(starship '*|*'eval "$(zoxide '*|*'eval "$(thefuck '*|*'eval "$(direnv '*|*'fzf --zsh'*)
            echo "templates/zshrc (tool-init.manifest)"
            ;;
        export\ *)
            echo "core/env.sh"
            ;;
        *'function '*|*'() {'*)
            echo "core/functions.sh"
            ;;
        *'source '*|*'. '*)
            echo "review: source line"
            ;;
        *)
            echo "review: unclassified"
            ;;
    esac
}

is_managed_rc() {
    local f="$1"
    [[ -f "$f" ]] && grep -qF "$MANAGED_MARKER" "$f"
}

manifest_match() {
    local line="$1"
    [[ -f "$MANIFEST" ]] || return 1
    local pat owner
    while IFS= read -r pat; do
        [[ "$pat" =~ ^[[:space:]]*pattern:[[:space:]]*(.*)$ ]] || continue
        pat="${BASH_REMATCH[1]}"
        pat="${pat//\'/}"
        if [[ "$line" == *"$pat"* ]]; then
            owner=$(awk -v p="$pat" '$0 ~ "pattern:.*" p {getline; if ($0 ~ /owner:/) print $2; exit}' "$MANIFEST" 2>/dev/null || true)
            [[ -n "$owner" ]] && echo "managed: $owner" && return 0
        fi
    done < <(grep 'pattern:' "$MANIFEST" 2>/dev/null || true)
    return 1
}

scan_rc() {
    local rc="$1"
    [[ -f "$rc" ]] || return 0
    log "Scanning $rc"
    if ! is_managed_rc "$rc" && [[ "$FORCE" != true ]]; then
        warn "$rc is not managed — use --force to edit"
    fi
    local n=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        case "$line" in
            *"$MANAGED_MARKER"*|source\ \"\$HOME/.config/shell/*|source\ \"\$HOME/.config/shell/*)
                continue
                ;;
        esac
        case "$line" in
            *'config/shell/env.sh'*|*'config/shell/functions.sh'*|*'config/shell/aliases.sh'*|*source_environment_shell*|*path_contract_reassert*)
                continue
                ;;
        esac
        local dest managed
        dest=$(classify_line "$line")
        managed=$(manifest_match "$line" || true)
        if [[ -n "$managed" ]]; then
            printf '  L%-4s DUPLICATE %s\n    %s\n    → remove from rc (%s)\n' "$n" "$managed" "$line" "$managed"
        else
            printf '  L%-4s → %s\n    %s\n' "$n" "$dest" "$line"
        fi
    done < "$rc"
}

parse_install_log() {
    local logf="$1"
    [[ -f "$logf" ]] || { warn "log not found: $logf"; return 1; }
    log "Parsing install log: $logf"
    grep -iE 'zshrc|bashrc|profile|PATH|add.*shell|source.*env' "$logf" 2>/dev/null | while IFS= read -r line; do
        printf '  log → %s\n    %s\n' "$(classify_line "$line")" "$line"
    done
}

apply_capture() {
    warn "--apply: manual review recommended for first run; use --dry-run output"
    local backup="${CONFIG_DIR}/backups/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup"
    for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
        [[ -f "$rc" ]] && cp -a "$rc" "$backup/" && log "Backed up $rc → $backup/"
    done
    log "Add classified lines to modules under $CONFIG_DIR, then remove from rc files."
    log "For PATH entries: edit core/path.contract (one line) — not env.sh path_prepend."
    log "Re-run: ~/.config/shell/bin/check-shell.sh && zsh -lic path_check"
}

log "Shell init capture"
for rc in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    scan_rc "$rc"
done
[[ -n "$INSTALL_LOG" ]] && parse_install_log "$INSTALL_LOG"

if [[ "$DRY_RUN" == true ]]; then
    log "Dry run complete — no files modified"
elif [[ "$APPLY" == true ]]; then
    apply_capture
else
    log "Hint: --dry-run for routing only; --apply to backup and guide module edits"
fi
