# Architecture & design docs

Deep reference for shell config layout, verification workflow, and `$SHELL` behavior. Start at [../README.md](../README.md) for setup; use these for load order, cockpit workflow, and maintenance.

| Doc | Purpose |
|-----|---------|
| [shell.md](shell.md) | Load order, PATH contract, migrate policy, login templates |
| [VERIFICATION.md](VERIFICATION.md) | Agent verification cockpit (`av`, tmux, nvim, `gdf`/`gdfs`) |
| [human-in-the-loop-workflow.md](human-in-the-loop-workflow.md) | Repeatable review rituals before commit |
| [coming-next.md](coming-next.md) | Deferred follow-ups from PR reviews (not blocking) |
| [SHELL-env-var-behavior.md](SHELL-env-var-behavior.md) | Why `$SHELL` is stale; truth seeker behavior |
| [../motivation.md](../motivation.md) | Project genesis — CLI-first workflow, human-in-the-loop verification |

Operational scripts: [../bin/README.md](../bin/README.md). Environment presets: [../environments/README.md](../environments/README.md).
