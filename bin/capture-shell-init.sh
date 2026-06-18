#!/usr/bin/env bash
# capture-shell-init.sh — detect installer pollution in rc files and route to shell modules.
set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/shell}"
MANAGED_MARKER="${MANAGED_MARKER:-Managed by ~/.config/shell/bin/migrate.sh}"
MANIFEST="${CONFIG_DIR}/templates/tool-init.manifest"
DRY_RUN=false
APPLY=false
FORCE=false
VERBOSE=false
INSTALL_LOG=""

usage() {
    cat <<EOF
Usage: capture-shell-init.sh [--dry-run] [--apply] [--force] [--since-install LOG]

  (default)   Scan rc files for unmanaged init blocks
  --dry-run   Show routing recommendations only
  --apply     Move classified blocks into ~/.config/shell modules (backs up first)
  --force     Edit rc files without managed marker
  --verbose   Show expected inits already present in managed rc (normally hidden)
  --since-install LOG  Parse installer log for "add to ~/.zshrc" hints

After capture: run ~/.config/shell/bin/check-shell.sh && path_check
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --apply) APPLY=true; shift ;;
        --force) FORCE=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --since-install) INSTALL_LOG="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

log() { printf '[capture] %s\n' "$1"; }
warn() { printf '[capture] WARN: %s\n' "$1" >&2; }

classify_line() {
    local line="$1"
    # shellcheck disable=SC2016
    case "$line" in
        *'export GPG_TTY='*|*'gpg-connect-agent updatestartuptty'*)
            echo "templates/login/profile"
            ;;
        *'export PATH='*|*'PATH='*|*path_prepend*|*'.cargo/env'*|*'.local/bin/env'*|*'.vite-plus/env'*)
            echo "path.contract / core/env.sh"
            ;;
        alias\ *)
            echo "core/aliases.sh"
            ;;
        *'eval "$(mamba '*|*'eval "$(mise '*|*'eval "$(starship '*|*'eval "$(zoxide '*|*'eval "$(thefuck '*|*'eval "$(direnv '*)
            echo "templates/zshrc (tool-init.manifest)"
            ;;
        *'fzf --zsh'*)
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

rc_template_for() {
    case "$1" in
        "$HOME/.zshrc") printf '%s' "$CONFIG_DIR/templates/zshrc" ;;
        "$HOME/.bashrc") printf '%s' "$CONFIG_DIR/templates/bashrc" ;;
        "$HOME/.profile") printf '%s' "$CONFIG_DIR/templates/login/profile" ;;
        "$HOME/.zprofile") printf '%s' "$CONFIG_DIR/templates/login/zprofile" ;;
        "$HOME/.bash_profile") printf '%s' "$CONFIG_DIR/templates/login/bash_profile" ;;
        *) printf '' ;;
    esac
}

is_login_rc() {
    case "$1" in
        "$HOME/.profile"|"$HOME/.zprofile"|"$HOME/.bash_profile") return 0 ;;
        *) return 1 ;;
    esac
}

profile_delegates_env_sh() {
    local rc="$1"
    [[ -f "$rc" ]] || return 1
    grep -qE '(^|[[:space:]])\.[[:space:]]*["'\'']?\$HOME/\.config/shell/env\.sh|config/shell/env\.sh' "$rc" 2>/dev/null
}

# Managed rc deployed from templates/* — skip lines that belong in that template.
is_expected_managed_init() {
    local rc="$1" line="$2"
    local tpl stripped
    is_managed_rc "$rc" || return 1
    tpl=$(rc_template_for "$rc")
    [[ -n "$tpl" && -f "$tpl" ]] || return 1
    stripped="${line#"${line%%[![:space:]]*}"}"
    [[ -n "$stripped" ]] || return 1
    grep -qF "$stripped" "$tpl" 2>/dev/null
}

manifest_match() {
    local line="$1"
    [[ -f "$MANIFEST" ]] || return 1
    local manifest_line pattern owner
    while IFS= read -r manifest_line; do
        [[ "$manifest_line" =~ ^[[:space:]]*pattern:[[:space:]]*(.*)$ ]] || continue
        pattern="${BASH_REMATCH[1]}"
        pattern="${pattern#\'}"
        pattern="${pattern%\'}"
        [[ -n "$pattern" ]] || continue
        if [[ "$line" == *"$pattern"* ]]; then
            owner=$(awk -v p="$pattern" '
                $0 ~ p && /pattern:/ {
                    while ((getline line) > 0) {
                        if (line ~ /^[a-zA-Z0-9_-]+:/) exit
                        if (line ~ /owner:/) {
                            sub(/^[^:]*:[[:space:]]*/, "", line)
                            print line
                            exit
                        }
                    }
                }
            ' "$MANIFEST" 2>/dev/null || true)
            [[ -n "$owner" ]] && echo "managed: $owner" && return 0
        fi
    done < <(grep 'pattern:' "$MANIFEST" 2>/dev/null || true)
    return 1
}

scan_rc() {
    local rc="$1"
    [[ -f "$rc" ]] || return 0
    log "Scanning $rc"
    local unmanaged=false duplicates=0
    if ! is_managed_rc "$rc"; then
        unmanaged=true
        if is_login_rc "$rc"; then
            warn "$rc is not managed — login files should delegate to ~/.config/shell/env.sh (see templates/login/profile)"
        else
            warn "$rc is not managed — use --force to edit"
        fi
    fi
    local n=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        n=$((n + 1))
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue
        case "$line" in
            *"$MANAGED_MARKER"*|*'config/shell/env.sh'*|*'config/shell/functions.sh'*|*'config/shell/aliases.sh'*|*source_environment_shell*|*path_contract_reassert*)
                continue
                ;;
        esac
        local dest managed action
        dest=$(classify_line "$line")
        managed=$(manifest_match "$line" || true)
        if [[ -n "$managed" ]]; then
            if is_expected_managed_init "$rc" "$line"; then
                [[ "$VERBOSE" == true ]] && printf '  L%-4s OK expected in managed rc (%s)\n    %s\n' "$n" "$managed" "$line"
                continue
            fi
            duplicates=$((duplicates + 1))
            action="remove from rc ($managed)"
            if is_login_rc "$rc" && profile_delegates_env_sh "$rc"; then
                action="remove from login rc — already applied when sourcing ~/.config/shell/env.sh ($managed)"
            fi
            printf '  L%-4s DUPLICATE %s\n    %s\n    → %s\n' "$n" "$managed" "$line" "$action"
        else
            printf '  L%-4s → %s\n    %s\n' "$n" "$dest" "$line"
        fi
    done < "$rc"
    if [[ "$unmanaged" == true && "$duplicates" -gt 0 ]] && is_login_rc "$rc"; then
        log "Hint: trim $rc to templates/login/$(basename "$rc") or run: $CONFIG_DIR/bin/migrate.sh (install-rc task)"
    fi
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
    local backup ts
    ts=$(date +%Y%m%d-%H%M%S)
    backup="${CONFIG_DIR}/backups/${ts}"
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
