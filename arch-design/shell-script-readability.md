# Shell script readability

Human maintainers are a **primary audience** for kernel shell — not just agents. When PATH or init fails, you read scripts under stress; opaque scratch names (`_tok`, `_rest`, `_seg`) slow incident response.

**Enforcement:** [`.cursor/rules/shell-readability.mdc`](../.cursor/rules/shell-readability.mdc) steers agents on `*.sh` edits. `check-shell.sh` does **not** lint semantic naming (no cheap programmatic substitute for readable names).

---

## Rules (summary)

1. No opaque one-letter or generic scratch scalars across function boundaries.
2. Locals use **domain vocabulary** from the subsystem (PATH contract, tmux verify, migrate).
3. Private helpers say what they do: `path_contract_environment_gate_passes`, `_flush_pending_prepends`.
4. Public exported functions stay stable unless deliberately versioning API.
5. POSIX `sh` core: `_domain_name` locals. Bash libs: `local full_words`.

---

## PATH contract lexicon

Maps `path.contract` syntax → variable names used in [`core/path-resolve.sh`](../core/path-resolve.sh) and [`core/path.sh`](../core/path.sh).

| Concept | Variable names |
|---------|----------------|
| Contract file path | `contract_file_path` |
| One line from contract | `contract_line` |
| `phase:environment` token | `phase_name` |
| CLI `--phase` filter | `phase_filter` |
| `prepend:` / `append:` token | `path_token` |
| After `path_contract_resolve_token` | `resolved_directory` |
| `deny:` pattern | `deny_pattern` |
| `prepend:TOKEN:omarchy` gate | `environment_gate` |
| Batched prepend queue | `pending_prepend_dirs` |
| One PATH entry | `path_segment` |
| Verify expected order | `expected_prepend_order` |
| Rank in managed order | `path_segment_rank`, `rank_index` |
| Directory to add/remove | `prepend_directory`, `target_directory` |

---

## Before / after (path-resolve.sh)

**Before (opaque):**

```sh
prepend:*)
    _rest="${_line#prepend:}"
    _tok="${_rest%%:*}"
    _cond=""
    _dir=$(path_contract_resolve_token "$_tok")
    [ -n "$_dir" ] && _prepends="$_prepends $_dir"
    ;;
```

**After (readable):**

```sh
prepend:*)
    line_rest="${contract_line#prepend:}"
    path_token="${line_rest%%:*}"
    environment_gate=""
    resolved_directory=$(path_contract_resolve_token "$path_token")
    [ -n "$resolved_directory" ] && pending_prepend_dirs="$pending_prepend_dirs $resolved_directory"
    ;;
```

---

## Pilot scope (shipped)

| File | Status |
|------|--------|
| `core/path-resolve.sh`, `core/path.sh` | Renamed locals + vocabulary header |
| `core/lib.sh`, `core/env.sh`, `core/functions.sh` | Renamed locals + vocabulary header |
| `bin/check-shell.sh`, `bin/fzf-preview.sh`, `bin/agent-build-layout.sh` | Renamed locals |
| `bin/lib/discover-tests.sh` | Renamed discovery priority counter |
| `templates/core/*` | Kept in sync with core |

**Optional follow-up:** remaining `bin/*.sh` entrypoints when next edited.

---

## Vocabulary header pattern

PATH stack files start with a short comment listing domain locals — zero runtime cost, faster incident scans:

```sh
# Vocabulary: path_token, contract_line, phase_name, environment_gate,
# deny_pattern, resolved_directory, pending_prepend_dirs, path_segment
```

---

*Plain rule: name shell for the human reading it at 2am — agents can follow a lexicon; they cannot invent one mid-incident.*
