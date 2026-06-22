# Verification plugin (SN-4)

Agent verification cockpit: `ab` / `av` / `at`, tmux layouts, headless `cockpit-mcp`, test discovery.

**Kernel boundary:** [PLUGIN.md](../../PLUGIN.md) · **Ontology:** [`.agents/ontology/INDEX.md`](../../.agents/ontology/INDEX.md)

## Layout

| Path | Role |
|------|------|
| `bin/` | Layout scripts, tmux helpers, `cockpit-mcp.sh` |
| `lib/` | `verify-launch.sh`, `verify-layout.sh`, test parsers |
| `data/` | `tmux-keymaps.tsv` |
| `conf/` | `tmux.verify.conf.ex` templates (scaffold copies to `~/.config/shell/`) |

Stable entrypoints remain **`~/.config/shell/bin/*` shims** so tmux binds and aliases need not change. Shell functions resolve the real script via `verification_script_path` in `core/lib.sh` (plugin `bin/` first, shim fallback).

## Env (set in `core/env.sh`)

- `SHELL_VERIFICATION_ROOT` — default `$SHELL_ROOT/plugins/verification`
- `SHELL_VERIFICATION_BIN` — plugin `bin/`
- `SHELL_VERIFICATION_LIB` — plugin `lib/`

## Install paths

| Method | What you get |
|--------|----------------|
| **Git checkout + `bin/migrate.sh`** | Full tree including `plugins/verification/` (recommended) |
| **Remote bootstrap** (`migrate.sh --bootstrap`) | Fetches shims + full `plugins/verification/*` via `bootstrap_from_remote` in `migrate-common.sh` |
| **Partial copy** | `ab`/`av`/`at` fail if `plugins/verification/bin/` is missing — shims alone are not enough |

After bootstrap or migrate, run `bin/sync-tmux-verify.sh` once if tmux binds are stale. `scaffold.sh` copies `conf/*.ex` to `~/.config/shell/tmux.*.ex` for `source-file` paths in `verify.conf`.

## Per-project cockpit

Project manifests stay at **`.agents/verification/`** in each repo (not under this tree). Dogfood copy: [`.agents/verification/`](../../.agents/verification/).
