# Verification plugin

Agent verification cockpit: `ab` / `av` / `at`, tmux layouts, headless `cockpit-mcp`, test discovery.

**Kernel boundary:** [PLUGIN.md](../../PLUGIN.md) · **Workflow philosophy:** [arch-design/VERIFICATION.md](../../arch-design/VERIFICATION.md) · **Ontology:** [`.agents/ontology/INDEX.md`](../../.agents/ontology/INDEX.md)

## Layout

| Path | Role |
|------|------|
| `bin/` | Layout scripts, tmux helpers, `cockpit-mcp.sh` |
| `lib/` | `verify-launch.sh`, `verify-layout.sh`, `tmux-status-mode.sh`, test parsers |
| `data/` | `tmux-keymaps.tsv` — keymap menu data |
| `conf/` | `tmux.verify.conf.ex` templates (scaffold copies to `~/.config/shell/`) |

Stable entrypoints remain **`~/.config/shell/bin/*` shims** so tmux binds and aliases need not change. Shell functions resolve the real script via `verification_script_path` in `core/lib.sh` (plugin `bin/` first, shim fallback).

## Env (set in `core/env.sh`)

| Variable | Default |
|----------|---------|
| `SHELL_VERIFICATION_ROOT` | `$SHELL_ROOT/plugins/verification` |
| `SHELL_VERIFICATION_BIN` | plugin `bin/` |
| `SHELL_VERIFICATION_LIB` | plugin `lib/` |

## Install paths

| Method | What you get |
|--------|----------------|
| **Git checkout + `bin/migrate.sh`** | Full tree including `plugins/verification/` (recommended) |
| **Remote bootstrap** (`migrate.sh --bootstrap`) | Fetches shims + full `plugins/verification/*` via `bootstrap_from_remote` in `migrate-common.sh` |
| **Partial copy** | `ab`/`av`/`at` fail if `plugins/verification/bin/` is missing — shims alone are not enough |

After bootstrap or migrate, run `bin/sync-tmux-verify.sh` once if tmux binds are stale.

### Scaffold copies

`bin/scaffold.sh` (via migrate) copies plugin templates to the kernel root when absent:

| Plugin source | Scaffold target | Used by |
|---------------|-----------------|---------|
| `conf/tmux.verify.conf.ex` | `~/.config/shell/tmux.verify.conf.ex` | `~/.config/tmux/verify.conf` |
| `conf/tmux.status-mode.conf.ex` | `~/.config/shell/tmux.status-mode.conf.ex` | status-bar mode display |
| `conf/tmux.verify-soc-theme.conf.ex` | `~/.config/shell/tmux.verify-soc-theme.conf.ex` | project cockpit theme |

Do not `source` `tmux.*.ex` in zsh — tmux loads `~/.config/tmux/verify.conf` via Omarchy `tmux.conf`.

Kernel-root examples (`yazi.ex.toml`, `git.ex.config`, `starship.ex.toml`) are **not** plugin internals — migrate scaffolds them separately. See [PLUGIN.md](../../PLUGIN.md).

## Plugin file map

| Concern | Location |
|---------|----------|
| Build layout | `bin/agent-build-layout.sh` (shim: `~/.config/shell/bin/agent-build-layout.sh`) |
| Verify layout | `bin/agent-verify-layout.sh` |
| Test layout | `bin/agent-test-layout.sh` |
| Headless MCP/CI | `bin/cockpit-mcp.sh` |
| tmux bind sync | `bin/sync-tmux-verify.sh` |
| Keymap menu | `bin/tmux-keymap-menu.sh` — data: `data/tmux-keymaps.tsv` |
| Mode display | `bin/tmux-mode-sync.sh` + `lib/tmux-status-mode.sh` |
| Verify launch tiers | `lib/verify-launch.sh`, `lib/verify-layout.sh` |
| Test runner | `bin/run-project-tests.sh`, `lib/project-tests.sh`, `lib/parse-project-tests.py` |

Shell aliases (`ab`, `av`, `at`, `vf`, `agent_scan`) live in `core/aliases.sh` and `core/functions.sh`. tmux verify bindings come from scaffolded `tmux.verify.conf.ex`.

## Headless verbs (MCP / CI)

Same manifest and rituals as tmux — different renderer:

```bash
~/.config/shell/bin/cockpit-mcp.sh verify [dir]   # gates: check-shell, template sync
~/.config/shell/bin/cockpit-mcp.sh test [dir]     # run-project-tests.sh (python optional)
~/.config/shell/bin/cockpit-mcp.sh scan [dir]     # rg + dust + JSON (agent_scan)
```

| Verb | tmux alias | Headless |
|------|------------|----------|
| verify | `av` | `cockpit-mcp.sh verify` |
| test | `at` | `cockpit-mcp.sh test` |
| scan | `av --scan` | `cockpit-mcp.sh scan` |

**Python optional:** `test` uses sh auto-discovery when python is absent. Full `cockpit.yaml` test parsing needs python.

## Per-project cockpit

Project manifests stay at **`.agents/verification/`** in each repo (not under this plugin tree).

This shell repo ships a **local stress-test layout** at [`.agents/verification/`](../../.agents/verification/) — `av` delegates there when you run verification in this checkout (`check-shell.sh` watch + template sync).

| Artifact | Purpose |
|----------|---------|
| `.agents/verification/cockpit.yaml` | Pane map + launch tiers + tests |
| `.agents/verification/tmux-layout.sh` | Layout script (`av` auto-delegates) |
| `.agents/verification/tmux-theme.conf` | Optional theme overrides |
| `.cursor/verify` | Symlink → `../.agents/verification` |

Generate per repo with the [verification-cockpit skill](../../.agents/skills/verification-cockpit/SKILL.md).

**Launch tiers:**

| Tier | On `av` | Examples |
|------|---------|----------|
| `monitor` / `watch` | auto-start | `lazygit`, `pnpm test --watch`, `cargo watch -x check` |
| `verify` | confirm `[y/N]` in pane | `pnpm test`, `cargo test`, `pnpm build` |
| `mutate` | blocked unless `av --launch-mutate` | `pnpm install`, migrations, deploy |

## Refresh tmux binds

```bash
~/.config/shell/bin/sync-tmux-verify.sh
# inside tmux: Prefix+q to reload tmux.conf
```
