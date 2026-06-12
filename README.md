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
├── env.sh              # Portable PATH + environment variables
├── aliases.sh          # Generic + commonly useful aliases
├── personal.sh         # Your work/personal specific aliases
├── functions.sh        # Custom functions (optional)
├── bin/
│   └── migrate.sh      # Master migration / setup script
└── backups/            # Timestamped backups + revert.sh
```

## File Responsibilities

| File            | Purpose                                      | Edit Frequency | Notes |
|-----------------|----------------------------------------------|----------------|-------|
| `env.sh`        | PATH setup, exports, environment variables   | Rarely         | Sourced by all shells |
| `aliases.sh`    | Generic useful aliases                       | Occasionally   | Sourced by bash + zsh |
| `personal.sh`   | Your work-specific aliases (agrepos, etc.)   | Frequently     | Your personal additions |
| `functions.sh`  | Custom shell functions                       | Rarely         | Optional |
| `migrate.sh`    | One-command setup / migration script         | Rarely         | Git tracked |

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
- The setup still works well because `~/.bashrc` sources the same `env.sh` and `aliases.sh`

**When to use:**
- Writing portable scripts
- Working on remote servers or containers
- Running third-party scripts that assume bash

### fish

**Use for:** Modern interactive experience (optional).

**Why:**
- Very user-friendly defaults (autosuggestions, syntax highlighting out of the box)
- Clean syntax
- However, it has different syntax for scripting, so we only do **best-effort** sourcing via `bass`

**When to use:**
- When you want a very polished interactive shell
- Experimentation or personal preference
- Not recommended as your only shell (due to compatibility)

## How Sourcing Works

1. `env.sh` is sourced first (sets up PATH and environment)
2. Omarchy files are sourced (your personal base layer)
3. `aliases.sh` is sourced (generic aliases)
4. `personal.sh` is sourced last (your work-specific aliases — can override previous ones)
5. Shell-native tools are initialized (`starship`, `mise activate`, `zoxide`, etc.)

This order ensures:
- Your personal aliases win when there are conflicts
- Everything stays consistent across bash and zsh

## How to Add New Aliases

### Generic / Commonly Useful
→ Add to `~/.config/shell/aliases.sh`

### Work / Personal Specific
→ Add to `~/.config/shell/personal.sh`

Example in `personal.sh`:

```bash
alias myproject="cd ~/Work/my-important-project"
alias deploy="make deploy"
```

After editing, just run:

```bash
source ~/.zshrc
# or
source ~/.bashrc
```

## Maintenance

- Run `~/.config/shell/bin/migrate.sh` when you want to re-apply or update the base setup
- The `backups/` folder contains timestamped backups + a `revert.sh`
- Everything important lives under `~/.config/shell/` and is git tracked
- See [shell.md](shell.md) for the full load-order reference and gotchas

## Notes

- This setup treats **Omarchy** as your personal foundation and layers modern tooling on top without fighting it.
- The goal is **low cognitive load** — you should rarely need to edit `~/.zshrc` or `~/.bashrc` directly.

