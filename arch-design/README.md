# Architecture & design docs

**Canonical trio** (read these first): [../README.md](../README.md) · [shell.md](shell.md) · [../PLUGIN.md](../PLUGIN.md)

Deep reference for load order, verification workflow, and maintenance. Everything else below is supplementary.

| Doc | Purpose |
|-----|---------|
| [shell.md](shell.md) | Load order, PATH contract, migrate policy, login templates |
| [VERIFICATION.md](VERIFICATION.md) | Agent verification cockpit (`av`, tmux, nvim, `gdf`/`gdfs`) |
| [human-in-the-loop-workflow.md](human-in-the-loop-workflow.md) | Repeatable review rituals before commit |
| [coming-next.md](coming-next.md) | Backlog blueprint cards (SN-* items) |
| [SHELL-env-var-behavior.md](SHELL-env-var-behavior.md) | Why `$SHELL` is stale; truth seeker behavior |
| [test-of-travelled-time-from-future.md](test-of-travelled-time-from-future.md) | Risk / thrive analysis for kernel vs plugin |
| [../motivation.md](../motivation.md) | Project genesis — CLI-first workflow, human-in-the-loop verification |

Operational scripts: [../bin/README.md](../bin/README.md). Environment presets: [../environments/README.md](../environments/README.md).
