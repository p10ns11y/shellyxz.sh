# Verification plugin (SN-4)

Agent verification cockpit: `ab` / `av` / `at`, tmux layouts, headless `cockpit-mcp`, test discovery.

**Kernel boundary:** [PLUGIN.md](../../PLUGIN.md) · **Ontology:** [`.agents/ontology/INDEX.md`](../../.agents/ontology/INDEX.md)

## Layout

| Path | Role |
|------|------|
| `bin/` | Layout scripts, tmux helpers, `cockpit-mcp.sh` |
| `lib/` | `verify-launch.sh`, `verify-layout.sh`, test parsers |
| `data/` | `tmux-keymaps.tsv` |
| `conf/` | `tmux.verify.conf.ex` templates (migrate copies to `~/.config/shell/`) |

Stable entrypoints remain **`~/.config/shell/bin/*` shims** so tmux binds and aliases need not change.

## Env (set in `core/env.sh`)

- `SHELL_VERIFICATION_ROOT` — default `$SHELL_ROOT/plugins/verification`
- `SHELL_VERIFICATION_BIN` — plugin `bin/`
- `SHELL_VERIFICATION_LIB` — plugin `lib/`

## Per-project cockpit

Project manifests stay at **`.agents/verification/`** in each repo (not under this tree). Dogfood copy: [`.agents/verification/`](../../.agents/verification/).
