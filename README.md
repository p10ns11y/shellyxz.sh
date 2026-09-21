# ~/.config/shell/

Portable shell config for **bash**, **zsh**, and **fish** — built so humans can review agent work in a terminal cockpit without fighting `PATH`, rc files, or editor terminals.

**Core intent:** a small **kernel** (`core/`) that always loads cleanly, plus an optional **verification plugin** (`ab` / `av` / `at` in tmux). Why this exists: [motivation.md](motivation.md).

| Start here | What you get |
|------------|----------------|
| [PLUGIN.md](PLUGIN.md) | What must work without tmux/agents vs what the verification plugin may assume |
| [arch-design/architecture.md](arch-design/architecture.md) | Current system map, scorecard, PATH layers |
| [arch-design/VERIFICATION.md](arch-design/VERIFICATION.md) | `ab` / `av` cockpit workflow (`$TMUX` required; any terminal, including Cursor agent view) |

## Audience

**Advanced users only.** This config owns `PATH`, login files, and tool hooks. A bad edit can make new terminals unusable — the usual fix tools (`git`, `nvim`, `mise`) may be missing in that session.

Know a recovery path that does **not** need a working interactive shell: root/rescue TTY, `bash --norc`, [`bin/recover-shell.sh`](bin/recover-shell.sh), another user, `backups/*/revert.sh`, or editing dotfiles from a GUI/SSH session that skips your broken rc.

If that sounds stressful, keep a distribution-default shell setup instead.

## Getting started

New machine or fresh checkout. Existing installs: jump to [Maintenance](#maintenance).

**Layout rule:** clone the repo **outside** `~/.config/shell` (e.g. `~/dev/foundations-infra/shellyxz`), then **sync on demand** into `~/.config/shell`. Machine-specific files live in `local/`, `environment`, and `backups/` — sync never deletes them. Full layout: [arch-design/SHELL-LAYOUT.md](arch-design/SHELL-LAYOUT.md).

### Prerequisites

| Requirement | Why |
|-------------|-----|
| **Environment preset** (`environment` or `SHELL_ENVIRONMENT`) | `generic` for containers/VPS/CI; `omarchy` when `~/.local/share/omarchy` exists (auto-detected) |
| **direnv** (recommended) | Managed rc templates hook direnv |
| **fish + bass** (fish only) | Fish loads portable modules via bass |
| **paru** (Arch only, optional) | `migrate.sh` may install `yazi` / `thefuck` / `procs` / `difftastic`; other distros: install manually |

### First install (recommended — checkout + sync)

Clone **outside** system config, sync into `~/.config/shell`, then migrate:

```bash
mkdir -p ~/dev/foundations-infra
git clone https://github.com/p10ns11y/shellyxz.sh.git ~/dev/foundations-infra/shellyxz
# SSH: git@github.com:p10ns11y/shellyxz.sh.git

cd ~/dev/foundations-infra/shellyxz
bin/sync-to-config.sh          # on-demand; preserves local/ environment backups/
~/.config/shell/bin/migrate.sh

# Optional: pin preset (omit to auto-detect omarchy vs generic)
cp ~/.config/shell/environment.example ~/.config/shell/environment
# SHELL_ENVIRONMENT=generic   # or omarchy

# Optional: secrets (loaded via local/personal.sh)
mkdir -p ~/.config/secrets   # KEY=value in ~/.config/secrets/dev.env (mode 600)

source ~/.zshrc              # or ~/.bashrc
~/.config/shell/bin/check-shell.sh
```

Same pattern on **box**, **mac-mini**, **laptop-1**, **laptop-2** — see [SHELL-LAYOUT.md](arch-design/SHELL-LAYOUT.md).

### Bootstrap fallback (no git checkout)

When you cannot keep a foundations-infra checkout (containers, one-off VPS), use the curl bootstrap — it installs directly into `~/.config/shell`:

```bash
curl -fsSL https://raw.githubusercontent.com/p10ns11y/shellyxz.sh/refs/heads/master/bin/migrate.sh | bash
```

Override source for forks: `SHELL_CONFIG_RAW=...`. Prefer **clone + sync** when a long-lived checkout is available.

`migrate.sh` already scaffolds `~/.config/git/verification` and sets `include.path` when missing. Only set it yourself if that step was skipped:

```bash
git config --global include.path ~/.config/git/verification
```

**What migrate does (short):** backs up dotfiles to `backups/TIMESTAMP/` + `revert.sh`; bootstraps missing repo files when piped; generates modules only if absent; refreshes **managed** rc/login/fish; scaffolds starship/tmux/yazi/git when absent. Full behavior: [bin/README.md](bin/README.md).

### Containers / VPS (no Omarchy)

```bash
export SHELL_ENVIRONMENT=generic
source ~/.config/shell/env.sh
```

Or set `SHELL_ENVIRONMENT=generic` in `~/.config/shell/environment`.

## Layout (kernel vs overlay)

```
~/.config/shell/
├── core/                 # Always loaded — PATH contract, lib, aliases, functions
│   ├── path.contract     # PATH build order (edit here, not ad-hoc path_prepend)
│   ├── path-resolve.sh   # Token → directory resolution
│   ├── tool.contract     # Pinned system commands (shadow audit)
│   ├── env.sh            # Applies contract + environments
│   ├── lib.sh, aliases.sh, functions.sh
├── environments/         # Opt-in presets (omarchy, generic) — environments/README.md
├── local/                # Machine overlay (personal.sh, path.contract)
├── plugins/verification/ # Optional ab/av/at — PLUGIN.md
├── templates/            # Canonical copies for migrate / sync checks
├── bin/                  # migrate, check-shell, recover, layout shims
└── backups/              # gitignored; created by migrate
```

**Philosophy in one line:** distro-agnostic `core/` + opt-in `environments/` + git-tracked history; `templates/` stay in sync with `core/` (`bin/check-template-sync.sh`).

## Day-to-day

```bash
# Edit portable modules under ~/.config/shell/ — not ~/.zshrc
reload                                    # or: source ~/.zshrc
~/.config/shell/bin/check-shell.sh

# Agent verification cockpit (requires tmux)
t && av                                   # or attach tmux in Cursor agent terminal
```

| Task | Where |
|------|--------|
| Aliases / PATH / functions / load order | [arch-design/shell.md](arch-design/shell.md) |
| Shell switching, `$SHELL`, Ghostty after `chsh` | [arch-design/shell.md](arch-design/shell.md#switching-shells) · [SHELL-env-var-behavior.md](arch-design/SHELL-env-var-behavior.md) |
| `ab` / `av` / Prefix+V | [arch-design/VERIFICATION.md](arch-design/VERIFICATION.md) |
| Scripts & flags | [bin/README.md](bin/README.md) |

## Maintenance

- **Upstream updates:** `git pull` in your checkout, then `bin/sync-to-config.sh` (or `make sync-to-config`). Sync is **on-demand** — not a live rsync/watch daemon.
- After edits: `bin/check-shell.sh` (shellcheck + load-order + reserved names; `--audit` for secrets perms). Alias often: `shellyhow`.
- Refresh **managed** rc: `bin/migrate.sh` or `--sync-rc`. Hand-edited rc (no managed marker): `--force-rc` only.
- Modules (`env.sh`, `aliases.sh`, `functions.sh`) are **preserved** across migrate; first install generates them if missing.
- Sync glossary (`sync-to-config` vs `check-template-sync` vs `migrate --sync-rc`): [SHELL-LAYOUT.md](arch-design/SHELL-LAYOUT.md#related-tools-different-jobs).
- Naming for humans under stress: [shell-script-readability.md](arch-design/shell-script-readability.md).
- Doc index: [arch-design/README.md](arch-design/README.md) · backlog: [coming-next.md](arch-design/coming-next.md) · shipped: [planned-features/done/](planned-features/done/).

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `source ~/.zshrc` fails on direnv | Install direnv |
| Still bash after `chsh` in Ghostty | `killall ghostty`, then new window (Omarchy owns ghostty config) |
| Reserved-name violation (`ga` / `gd` / `n`) | Remove those aliases from `aliases.sh` / `personal.sh` |
| Hand-edited rc not updating | `bin/migrate.sh --force-rc` |
| Fish missing PATH/aliases | Install [bass](https://github.com/edc/bass); or use zsh/bash |
| `path_debug` / wrong PATH order | Edit `core/path.contract` or `local/path.contract`; `env.sh` only applies them (`path_check`) |
| `ab` / `av` refuses | Start tmux first (`$TMUX` must be set) |
| Broken everything | Nuclear recovery below |

More gotchas: [arch-design/shell.md — Gotchas](arch-design/shell.md#gotchas-checklist).

### Nuclear recovery

```bash
bash --norc ~/.config/shell/bin/recover-shell.sh
```

Minimal PATH + restore options (`backups/*/revert.sh`, `migrate.sh --force-rc`).

## Notes

- Prefer editing git-tracked modules under `~/.config/shell/`; treat `$HOME` rc files as thin wiring.
- **PATH** is owned by `core/path.contract` (+ optional `local/path.contract`) via `path_contract_apply` in `env.sh`. Debug: `path_debug` / `path_check`. Details: [shell.md — PATH contract](arch-design/shell.md#path-contract-v2), [PLUGIN.md](PLUGIN.md).
- `.gitignore` excludes `backups/` and secret patterns so local backups and keys never enter git.
