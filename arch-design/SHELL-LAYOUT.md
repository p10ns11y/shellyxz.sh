# Shell layout (checkout → config)

**Rule:** keep the **git checkout outside** `~/.config/shell`. Sync into config on demand; machine-specific files stay in config.

## Model

1. **Source / product checkout** lives outside system config (example paths):
   - `~/dev/foundations-infra/shellyxz` (preferred when you use foundations-infra)
   - `~/dev/shellyxz` (standalone clone)
2. **Runtime config** is `~/.config/shell` — populated by `bin/sync-to-config.sh`.
3. **Local tweaks** only under `~/.config/shell/local/` (plus top-level `environment`, secrets elsewhere).
4. **Upstream updates:** `git pull` in the checkout, then run sync.

```
~/dev/.../shellyxz/   →  sync-to-config  →  ~/.config/shell/
     (git source)                              (+ local/ overlays)
```

## Sync is on-demand (not live)

`bin/sync-to-config.sh` runs **when you invoke it**. It does not watch the checkout, run in the background, or use rsync.

```bash
# From your shellyxz checkout (or foundations-infra/shellyxz via SHELLXZ_SRC)
bin/sync-to-config.sh
# or: make sync-to-config
```

**Preserves** (never deleted by sync): `local/`, `environment`, `backups/`.

**Environment overrides:**

| Variable | Default |
|----------|---------|
| `SHELLXZ_SRC` | Parent of `bin/` (repo root when run in-tree) |
| `SHELLXZ_DST` | `~/.config/shell` |

## Per-host install (aliases)

Use the same pattern on every machine; only `local/` differs.

| Host alias | Checkout path (example) | After sync |
|------------|-------------------------|------------|
| **box** | `~/dev/foundations-infra/shellyxz` | `~/.config/shell/bin/migrate.sh` on first install |
| **mac-mini** | `~/dev/foundations-infra/shellyxz` | same |
| **laptop-1** | `~/dev/foundations-infra/shellyxz` | same |
| **laptop-2** | `~/dev/foundations-infra/shellyxz` | same |

First-time on a host:

```bash
git clone https://github.com/p10ns11y/shellyxz.sh.git ~/dev/foundations-infra/shellyxz
cd ~/dev/foundations-infra/shellyxz
bin/sync-to-config.sh
~/.config/shell/bin/migrate.sh
source ~/.zshrc
~/.config/shell/bin/check-shell.sh
```

Ongoing updates:

```bash
cd ~/dev/foundations-infra/shellyxz
git pull
bin/sync-to-config.sh
source ~/.config/shell/env.sh && path_check
```

## Related tools (different jobs)

| Tool | Scope |
|------|--------|
| **`bin/sync-to-config.sh`** | Checkout → `~/.config/shell` (this doc) |
| **`bin/check-template-sync.sh`** | `templates/` vs `core/` drift inside the repo |
| **`bin/migrate.sh --sync-rc`** | Refresh managed `~/.zshrc` / login files from templates |
| **`bin/sync-tmux-verify.sh`** | tmux verification keybinds after plugin changes |
| **keeper / mesh** | Vault ciphertext or escrow distribution across machines (separate; not this script) |

When a foundations-infra checkout exists, **prefer clone + sync** over `curl \| bash` bootstrap or GitHub zipballs.
