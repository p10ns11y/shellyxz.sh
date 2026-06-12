# ~/.config/shell/

Clean, portable, and low-maintenance shell configuration that works across **bash**, **zsh**, and **fish**.

## Audience

**This is for advanced users only.** You should already be comfortable fixing a broken shell environment and recovering a system when things go wrong.

Shell config touches `PATH`, login files, and tool initialization. A bad edit can leave new terminals unusable — wrong `PATH`, syntax errors on `source`, or broken hooks — so the very tools you normally use to fix things (`git`, `nvim`, `mise`, your editor, even `cd`) may not be available in that session.

Before changing anything here, know how you would recover without relying on a working interactive shell: a root/rescue TTY, a minimal `bash --norc`, booting from another user, restoring from `backups/*/revert.sh`, or fixing dotfiles from a graphical file manager or SSH session that does not load your broken rc.

If that sounds stressful, use a simpler, distribution-default setup instead.

## Philosophy

- **Minimal duplication** across shells
- **Single source of truth** for environment and aliases
- **Respect Omarchy** as your personal base layer
- **Easy to maintain** long-term
- **Git tracked** for history and easy syncing across machines

## Directory Structure

```
~/.config/shell/
├── README.md
├── shell.md            # Load-order reference and architecture
├── env.sh              # Portable PATH + environment variables
├── aliases.sh          # Generic aliases + personal.sh chain
├── personal.sh         # Your work/personal specific aliases
├── functions.sh        # Custom functions (optional)
├── bin/
│   ├── migrate.sh      # Master migration / setup script
│   └── check-shell.sh  # Verify load order and guardrails
└── backups/            # Timestamped backups + revert.sh
```

## File Responsibilities

| File            | Purpose                                      | Edit Frequency | Notes |
|-----------------|----------------------------------------------|----------------|-------|
| `env.sh`        | PATH setup, exports, environment variables   | Rarely         | Sourced by all shells |
| `aliases.sh`    | Generic useful aliases                       | Occasionally   | Sourced by bash, zsh, fish (via bass) |
| `personal.sh`   | Your work-specific aliases (agrepos, etc.)   | Frequently     | Chained from `aliases.sh` tail only |
| `functions.sh`  | Custom shell functions                       | Rarely         | Sourced by bash + zsh rc files |
| `migrate.sh`    | One-command setup / migration script         | Rarely         | Regenerates dotfiles; preserves existing modules |
| `check-shell.sh`| Load-order and reserved-name verification    | Never          | Run after edits or before migrate |

## Recommended Shell Usage

### zsh (Recommended Daily Driver)

**Use for:** Interactive development work, daily terminal use.

**Why:**
- Excellent balance of power and modernity
- Native support for `starship`, `mise activate zsh`, `zoxide init zsh`, `fzf --zsh`
- Fast startup with the current setup
- Great plugin ecosystem (without needing Oh My Zsh)
- Works very well with the current `env.sh` + `aliases.sh` + `personal.sh` structure

**When to use:**
- Most of your daily work
- When you want beautiful prompt + smart completions + modern tools

### bash

**Use for:** Maximum compatibility, scripts, servers, CI/CD, containers.

**Why:**
- Ubiquitous — available on almost every Unix-like system
- Required for many scripts and legacy tools
- Shares the same `env.sh` and `aliases.sh` layer as zsh, with Omarchy loaded via its `rc` bundle

**When to use:**
- Writing portable scripts
- Working on remote servers or containers
- Running third-party scripts that assume bash

### fish

**Use for:** Modern interactive experience (optional).

**Why:**
- Very user-friendly defaults (autosuggestions, syntax highlighting out of the box)
- Clean syntax
- Best-effort parity via `bass` for `env.sh`, Omarchy aliases, and `aliases.sh`

**When to use:**
- When you want a very polished interactive shell
- Experimentation or personal preference
- Not recommended as your only shell (due to compatibility)

**Limitations:** Omarchy worktree functions (`ga`, `gd`) and tools like `thefuck` are not available unless you add fish-native equivalents.

## How Sourcing Works

Load order is consistent across bash and zsh: Omarchy loads **before** your layer so its functions (like `ga`) are defined first; `aliases.sh` loads **after** so your overrides win.

### zsh and bash

1. `env.sh` — PATH, exports, Omarchy envs
2. `direnv` hook (when installed)
3. Omarchy — modular parts in zsh (`aliases`, `functions`); monolithic `rc` in bash
4. `functions.sh` — your custom functions
5. `aliases.sh` — generic aliases
6. `personal.sh` — chained at the tail of `aliases.sh`
7. Shell-native tool inits (`starship`, `mise`, `zoxide`, etc.)

### fish (best-effort)

1. `bass` → `env.sh`
2. `bass` → Omarchy aliases
3. `bass` → `aliases.sh` (includes `personal.sh`)
4. Native fish inits for `starship`, `zoxide`, `mise`

This order ensures:
- Omarchy functions like `ga()` are never shadowed by a premature `alias ga=`
- Your aliases (`ff`, `gs`, `top`, etc.) win over Omarchy when names overlap
- Work shortcuts in `personal.sh` are available in bash, zsh, and fish

## Reserved Names

Do not alias these — Omarchy owns them as functions:

| Name | Meaning |
|------|---------|
| `ga` | `git worktree add` helper |
| `gd` | remove worktree + branch |

`ff` is intentionally overridden to `fastfetch` in `aliases.sh` (Omarchy defines it as fzf). Use `fzf` or Omarchy's `eff` for file picking.

## How to Add New Aliases

### Generic / Commonly Useful
→ Add to `~/.config/shell/aliases.sh`

### Work / Personal Specific
→ Add to `~/.config/shell/personal.sh`

### Custom Functions
→ Add to `~/.config/shell/functions.sh`

Example in `personal.sh`:

```bash
alias myproject="cd ~/Work/my-important-project"
alias deploy="make deploy"
```

After editing, reload and verify:

```bash
source ~/.zshrc   # or: source ~/.bashrc
~/.config/shell/bin/check-shell.sh
```

## Maintenance

- Run `~/.config/shell/bin/check-shell.sh` after editing rc files or shell modules
- Run `~/.config/shell/bin/migrate.sh` to re-apply dotfile templates (`~/.zshrc`, `~/.bashrc`, fish config)
- `migrate.sh` **preserves** existing `env.sh`, `aliases.sh`, and `functions.sh` — it only regenerates them on first setup
- The `backups/` folder contains timestamped backups + a `revert.sh`
- Everything important lives under `~/.config/shell/` and is git tracked
- See [shell.md](shell.md) for the full load-order reference and remaining caveats

## Notes

- This setup treats **Omarchy** as your personal foundation and layers modern tooling on top without fighting it.
- The goal is **low cognitive load** — you should rarely need to edit `~/.zshrc` or `~/.bashrc` directly.
- **PATH** is still built in multiple places (`env.sh`, Omarchy, `~/.zprofile`). Use `echo $PATH` per shell when debugging precedence.