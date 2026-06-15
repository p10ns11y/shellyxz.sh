# Shell environments

Optional presets for **where** this shell runs: Omarchy desktop, generic Linux (containers, VPS, CI), or custom.

Not to be confused with `~/.profile` (POSIX login file) or `templates/login/profile`.

## Contract

Each `environments/<name>/` directory provides:

| File | Role |
|------|------|
| `env.sh` | Exports + `path_prepend` / `path_append` only |
| `bash.sh` | Interactive bash hooks |
| `zsh.sh` | Interactive zsh hooks |
| `fish.sh` | Fish hooks (bash syntax via bass) |

## Built-in presets

| Preset | Use when |
|--------|----------|
| `generic` | Containers, VPS, CI, sandboxes — no Omarchy/desktop assumptions |
| `omarchy` | Omarchy desktop (`~/.local/share/omarchy`) |

## Enable a preset

**Recommended:** omit `~/.config/shell/environment` and let auto-detect choose.

To pin explicitly:

```sh
cp ~/.config/shell/environment.example ~/.config/shell/environment
# edit — uncomment ONE line, e.g.:
# SHELL_ENVIRONMENT=generic
```

Or at runtime:

```sh
export SHELL_ENVIRONMENT=generic
source ~/.config/shell/env.sh
```

## Add a custom preset

```sh
~/.config/shell/bin/scaffold-environment.sh mydistro
```

Edit `environments/mydistro/*.sh`, then `SHELL_ENVIRONMENT=mydistro` in `environment`.

## PATH ownership

`core/env.sh` builds canonical PATH order via `path_prepend` / `path_append` (each call removes then re-adds — idempotent reorder). Presets may only declare entries in `env.sh`. Rare machine tweaks: `local/overwrite.sh` (see `local/overwrite.sh.example`). Do not source `~/.cargo/env` or `~/.local/bin/env` from presets.
