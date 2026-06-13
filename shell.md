# Shell environment architecture

How `~/.config/shell/` layers portable environment, Omarchy, and shell-native tooling across **zsh**, **bash**, and **fish**.

For day-to-day editing guidance see [README.md](README.md). This document is the **accurate load-order reference** — verified against live dotfiles and `bin/migrate.sh`.

**Prerequisites:** Omarchy (`~/.local/share/omarchy`), direnv (for managed zsh/bash rc), bass (fish only). See [README — Getting started](README.md#getting-started).

---

## Overview

```mermaid
flowchart TB
    subgraph login["Login / pre-rc (outside ~/.config/shell)"]
        zshenv["~/.zshenv"]
        zprofile["~/.zprofile"]
        profile["~/.profile / ~/.bash_profile"]
    end

    subgraph core["~/.config/shell (git-tracked)"]
        env["env.sh<br/>PATH, exports, loaders"]
        aliases["aliases.sh<br/>generic aliases + y()"]
        personal["personal.sh<br/>work shortcuts"]
        functions["functions.sh<br/>custom functions"]
    end

    subgraph omarchy["Omarchy (~/.local/share/omarchy)"]
        oenvs["default/bash/envs"]
        oaliases["default/bash/aliases"]
        ofns["default/bash/functions<br/>ga, gd worktrees"]
        orc["default/bash/rc<br/>bash-only bundle"]
        oinit["default/bash/init<br/>mise, starship, zoxide, fzf"]
    end

    subgraph shells["Interactive rc files"]
        zshrc["~/.zshrc"]
        bashrc["~/.bashrc"]
        fishcfg["~/.config/fish/config.fish"]
    end

    login --> shells
    zshrc --> env
    bashrc --> env
    fishcfg --> env

    env --> oenvs
    zshrc --> oaliases
    zshrc --> ofns
    bashrc --> orc
    orc --> oenvs
    orc --> oaliases
    orc --> ofns
    orc --> oinit

    zshrc --> functions
    bashrc --> functions
    zshrc --> aliases
    bashrc --> aliases
    aliases --> personal
    fishcfg --> aliases
```

**Key idea:** `env.sh` is the portable foundation (including Omarchy envs). Omarchy aliases and functions load next. `functions.sh` and `aliases.sh` load after Omarchy so your overrides win. `personal.sh` chains from the tail of `aliases.sh`. **Bash and zsh integrate Omarchy differently** — modular in zsh, `rc` bundle in bash — but override semantics match.

---

## Startup files: what rc, profile mean

Unix shells do not read one config file. They read **different files depending on shell name, login vs non-login, and interactive vs non-interactive**. Your setup keeps heavy logic in `~/.config/shell/` and uses home-directory files as thin entrypoints.

### The files on this machine

| File | Role | Loaded when | What it does here |
|------|------|-------------|-------------------|
| `~/.zshenv` | zsh env | **Every** zsh (including scripts) | `cargo/env`, vite-plus — runs before everything else in zsh |
| `~/.zprofile` | zsh login | Login zsh only (`zsh -l`, some terminals) | Sources `env.sh` for early PATH on login |
| `~/.zshrc` | zsh interactive | Interactive zsh (normal terminal) | Full stack: `env.sh` → direnv → Omarchy → `functions.sh` → `aliases.sh` → tool inits |
| `~/.profile` | POSIX login | Login sh/bash (when `bash_profile` absent) | GPG agent, `env.sh`, cargo, vite-plus |
| `~/.bash_profile` | bash login | Login bash | Sources `~/.bashrc`, then vite-plus again |
| `~/.bashrc` | bash interactive | Interactive bash | Full stack via Omarchy `rc` bundle + your modules |
| `~/.config/fish/config.fish` | fish main | Interactive fish | Fish has no separate profile/rc split — one file does it all |

Files **outside** `~/.config/shell/` but in the chain: Omarchy under `~/.local/share/omarchy/`, plus optional `~/.cargo/env`, `~/.vite-plus/env`.

### Login vs interactive vs non-interactive

```mermaid
flowchart TD
    subgraph modes["Three questions the shell asks"]
        Q1["Which shell?<br/>bash / zsh / fish"]
        Q2["Login shell?<br/>-l or TTY login"]
        Q3["Interactive?<br/>prompt vs script"]
    end

    Q1 --> Q2 --> Q3

    Q3 -->|interactive| RC["Load rc / config.fish<br/>aliases, prompt, fzf, …"]
    Q3 -->|non-interactive| MIN["Minimal env only<br/>scripts, CI, cron"]
    Q2 -->|login| PROF["Also load profile / zprofile<br/>PATH, GPG, env.sh"]
```

| Session type | Example | Typical files read (zsh) |
|--------------|---------|---------------------------|
| Interactive login | New terminal tab (most emulators) | `zshenv` → `zprofile` → `zshrc` |
| Interactive non-login | `zsh` from inside bash | `zshenv` → `zshrc` |
| Non-interactive | `zsh -c 'npm test'`, CI | `zshenv` only (often nothing you care about) |
| Script shebang | `#!/usr/bin/env bash` in Makefile | **No rc** unless bash is invoked as login/interactive |

That is why `path_debug` can differ between `zsh` and `zsh -l`: login adds `zprofile` → `env.sh` an extra time.

### Where to put changes

| You want to… | Edit this | Not this |
|--------------|-----------|----------|
| Add an alias | `aliases.sh` or `personal.sh` | `~/.zshrc` |
| Fix PATH | `env.sh` | `~/.zprofile` (already delegates to `env.sh`) |
| Add a function | `functions.sh` | rc files |
| Change load order or add a tool init | `migrate.sh` template, then `--force-rc` | hand-edit rc without migrating |
| One-off experiment | `exec fish` / `bash -l` | `chsh` |

### Switching shells

**Default shell** (what new login sessions use) is stored in `/etc/passwd`, changed with:

```bash
chsh -s /usr/bin/zsh   # list options: chsh -l
```

**Current shell** is the running process. `echo $SHELL` is the default, not the current. Use `echo $0` or `ps -p $$ -o comm=` to see what is running.

| Action | Command | Effect |
|--------|---------|--------|
| Temporary switch | `exec zsh` / `exec bash` / `exec fish` | Replaces current process; `exit` closes terminal |
| Subshell try-out | `fish` or `bash` (no exec) | Nested; `exit` returns to parent |
| Login simulation | `bash -l`, `zsh -l` | Runs profile + rc — good for PATH debugging |
| Non-interactive test | `bash -c 'cmd'` | Does not load your interactive aliases |

Fish is **opt-in**: use `exec fish` to try it without changing `chsh`. Switch back by opening a new terminal (if zsh is default) or `exec zsh`.

### Workflow: edit → reload → verify

```mermaid
flowchart TD
    A["Edit ~/.config/shell/module"] --> B{"Which shell?"}
    B -->|zsh| C["source ~/.zshrc or reload"]
    B -->|bash| D["source ~/.bashrc"]
    B -->|fish| E["Open new fish session"]
    C --> F["bin/check-shell.sh"]
    D --> F
    E --> F
    F --> G{"PATH wrong?"}
    G -->|yes| H["path_debug in each shell<br/>compare zsh vs zsh -l vs bash -l"]
    G -->|no| I["Done"]
```

### When you actually need another shell

| Use case | Shell | Notes |
|----------|-------|-------|
| Local daily work | zsh | Default; all tools wired |
| Remote SSH, VPS, Docker exec | bash | Often only `/bin/bash`; your `env.sh` layer still applies if dotfiles synced |
| Vendor install script | bash | Run as `bash ./install.sh`, not `source` |
| Reproduce user bug | match their shell | `bash -l` vs `bash` changes PATH |
| Portable script / CI | `#!/usr/bin/env bash` or `sh` | Do not source `aliases.sh`; set explicit env in script |
| Fish autosuggestions experiment | fish (temporary) | `ga`/`gd` not ported; use zsh for git worktrees |

You rarely need `chsh`. Most switching is **temporary** (`exec bash` on a server session) or **implicit** (scripts spawn their own shell from shebang).

---

## `~/.config/shell` modules

| File | Role | Sourced by |
|------|------|------------|
| `env.sh` | `path_prepend`/`path_append`, exports (SSH, GPG, threads), Omarchy envs, cargo/vite loaders | zsh, bash, fish (via bass) |
| `aliases.sh` | yazi `y()`, monitoring aliases, `ff`/`lg`/`n`, git shortcuts; **chains** `personal.sh` | zsh, bash, fish (via bass) |
| `personal.sh` | Work aliases (`agrepos`, …); loads `~/.config/secrets/dev.env` | via `aliases.sh` tail only |
| `functions.sh` | Custom functions (`path_debug`, …) | zsh, bash rc files; fish (via bass) |
| `bin/migrate.sh` | Generates dotfiles, backups; preserves existing modules | manual run |
| `bin/check-shell.sh` | Verifies load order, direnv hooks, reserved names | manual run |

### What `env.sh` sets up

```mermaid
flowchart LR
    subgraph path_prepend["path_prepend (last call wins)"]
        p1["tool bins: bun, pnpm, cargo, …"]
        p2["mamba"]
        p3["mise shims"]
        p4["~/bin"]
        p5["~/.local/bin (highest)"]
    end

    subgraph path_append["path_append (fallbacks)"]
        a1["condabin"]
        a2["/opt/rocm/bin"]
    end

    subgraph exports["exports"]
        e1["PNPM_HOME"]
        e2["PIP_CACHE_DIR, TMPDIR"]
        e3["OMP/MKL threads, HSA_OVERRIDE"]
        e4["SSH_AUTH_SOCK, GPG_TTY"]
    end

    subgraph loaders["optional dotfiles"]
        l1["Omarchy envs"]
        l2["~/.local/bin/env"]
        l3["~/.vite-plus/env"]
        l4["~/.cargo/env"]
    end

    path_prepend --> path_append --> exports --> loaders
```

---

## Login vs interactive layers

Some environment is applied **before** `~/.zshrc` or `~/.bashrc` run.

```mermaid
flowchart TD
    subgraph zsh_stack["zsh startup"]
        Z1["~/.zshenv<br/>every zsh: cargo, vite-plus"]
        Z2["~/.zprofile<br/>login only: sources env.sh"]
        Z3["~/.zshrc<br/>interactive: full stack"]
        Z1 --> Z2 --> Z3
    end

    subgraph bash_stack["bash startup"]
        B1["~/.profile or ~/.bash_profile<br/>login: GPG, env.sh, cargo, vite-plus"]
        B2["~/.bashrc<br/>interactive: full stack"]
        B1 --> B2
        B3["~/.bash_profile may re-source vite-plus after bashrc"]
        B2 --> B3
    end
```

**Caveat:** PATH is built in `env.sh` via `path_prepend` (last call = highest priority) and `path_append` (fallbacks). Omarchy envs then prepend `omarchy/bin` again. Login files delegate to `env.sh`. Use `path_debug` when troubleshooting. `path_add` remains as an alias for `path_prepend`.

---

## zsh load order (live `~/.zshrc`)

Recommended daily driver. Omarchy is sourced **modularly** (not via `rc`). Omarchy envs load only via `env.sh` (not duplicated in `.zshrc`).

```mermaid
flowchart TD
    A["1. env.sh<br/>(includes Omarchy envs)"] --> B["2. direnv hook zsh"]
    B --> C["3. Omarchy aliases"]
    C --> D["4. Omarchy functions<br/>ga/gd worktrees, fns/*"]
    D --> E["5. functions.sh"]
    E --> F["6. aliases.sh"]
    F --> G["6a. personal.sh<br/>(chained inside aliases.sh)"]
    G --> H["7. mise activate zsh"]
    H --> I["8. starship init zsh"]
    I --> J["9. zoxide init zsh"]
    J --> K["10. fzf --zsh"]
    K --> L["11. thefuck --alias"]
    L --> M["12. compinit + history opts"]
    M --> N["13. grok completions"]
    N --> O["14. zshconfig, reload aliases"]
```

| Step | File / command | Notes |
|------|----------------|-------|
| 1 | `env.sh` | Single source for Omarchy envs |
| 4 | Omarchy `functions` | Defines `ga()` git-worktree helper — **never alias `ga`** |
| 6 | `aliases.sh` | `ff` = **fastfetch** (wins over Omarchy) |
| 7–11 | tool inits | All in `.zshrc`, not Omarchy `init` |

---

## bash load order (live `~/.bashrc`)

Bash uses Omarchy's monolithic `rc` bundle instead of modular parts. Load order now matches zsh override semantics.

```mermaid
flowchart TD
    A["1. env.sh"] --> B["2. direnv hook bash"]
    B --> C["3. Omarchy rc"]
    C --> C1["envs"]
    C1 --> C2["shell"]
    C2 --> C3["aliases"]
    C3 --> C4["functions<br/>ga/gd worktrees"]
    C4 --> C5["init<br/>mise, starship, zoxide, fzf bash"]
    C5 --> C6["completions + inputrc"]
    C6 --> D["4. functions.sh"]
    D --> E["5. aliases.sh + personal.sh"]
    E --> F["6. bash history opts"]
```

Omarchy functions like `ga()` load **before** `aliases.sh`, so bash does not hit `syntax error near unexpected token '('` if someone re-adds `alias ga=`.

---

## Omarchy integration: zsh vs bash

```mermaid
flowchart LR
    subgraph zsh_mode["zsh — modular"]
        z1["env.sh"] --> z2["direnv"]
        z2 --> z3["aliases"]
        z3 --> z4["functions"]
        z4 --> z5["functions.sh"]
        z5 --> z6["aliases.sh"]
        z6 --> z7["tool inits in .zshrc"]
    end

    subgraph bash_mode["bash — rc bundle"]
        b1["env.sh"] --> b2["direnv"]
        b2 --> b3["rc → envs, shell, aliases, functions, init"]
        b3 --> b4["functions.sh"]
        b4 --> b5["aliases.sh"]
        b5 --> b6["hist opts"]
    end
```

| Concern | zsh | bash |
|---------|-----|------|
| Omarchy envs | via `env.sh` only | via `env.sh` + rc (harmless duplicate) |
| `ga` worktree fn | Omarchy functions | Omarchy functions (safe order) |
| `ff` | fastfetch (`aliases.sh` wins) | fastfetch (`aliases.sh` wins) |
| mise / starship | `.zshrc` | Omarchy `init` inside rc |
| thefuck | `.zshrc` only | not loaded |
| direnv | after `env.sh` | after `env.sh` |

---

## Override precedence

Later definitions win **within the same shell**. Bash and zsh now share the same override semantics for the `~/.config/shell` layer.

```mermaid
flowchart TD
    subgraph shared_precedence["zsh and bash — who wins"]
        direction TB
        O["Omarchy aliases/functions"]
        F["functions.sh"]
        A["aliases.sh + personal.sh"]
        O --> F --> A
        A -->|"ff, gs, gc, top, df, du"| WINS["aliases.sh wins for those names"]
    end
```

### Reserved names

| Name | Owner | Meaning | Do not |
|------|-------|---------|--------|
| `ga` | Omarchy `fns/worktrees` | `git worktree add` helper | `alias ga='git add'` |
| `gd` | Omarchy `fns/worktrees` | remove worktree + branch | alias over it |
| `ff` | `aliases.sh` (override) | fastfetch in all shells | assume Omarchy's fzf meaning |

Use `fzf` directly or Omarchy's `eff` for file picking.

---

## fish (best-effort)

```mermaid
flowchart TD
    F1["bass → env.sh"] --> F2["direnv hook fish"]
    F2 --> F3["bass → Omarchy aliases"]
    F3 --> F4["bass → functions.sh"]
    F4 --> F5["bass → aliases.sh<br/>(chains personal.sh)"]
    F5 --> F6["starship / zoxide / mise / fzf (fish native)"]

    F7["❌ not loaded"] --- F7a["Omarchy functions (ga, gd)"]
```

Fish gets PATH/exports, direnv, `functions.sh`, thefuck, Omarchy aliases, and work shortcuts via `aliases.sh` → `personal.sh`. Worktree helpers (`ga`, `gd`) still need fish-native function ports for full parity.

---

## Tool initialization matrix

| Tool | zsh | bash | fish | Where |
|------|-----|------|------|-------|
| direnv | `.zshrc` | `.bashrc` | `config.fish` | hook after `env.sh` |
| mise | `.zshrc` | Omarchy `init` | `config.fish` | |
| starship | `.zshrc` | Omarchy `init` | `config.fish` | |
| zoxide | `.zshrc` | Omarchy `init` | `config.fish` | |
| fzf | `.zshrc` | Omarchy `init` | `config.fish` | |
| thefuck | `.zshrc` | — | `config.fish` | native fish only |
| compinit | `.zshrc` | — | — | |
| grok completions | `.zshrc` | — | — | |

---

## Login dotfiles (manual setup)

`bin/migrate.sh` **backs up** login-layer dotfiles but does **not** generate them. Without these, login shells may miss early PATH, GPG agent, cargo, or vite-plus setup.

Copy or create these in `$HOME` (templates match a typical Omarchy + portable-env setup):

**`~/.zprofile`** — login zsh only; early PATH via portable env:

```bash
# Login PATH — delegate to portable env (~/.config/shell/env.sh)
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
```

**`~/.zshenv`** — every zsh (including scripts):

```bash
. "$HOME/.cargo/env"

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
```

**`~/.profile`** — POSIX login (GPG, env, cargo, vite-plus):

```bash
. "$HOME/.local/bin/env"
export GPG_TTY=$(tty)
gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1 || true

# Portable PATH and exports (~/.config/shell/env.sh)
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"

. "$HOME/.cargo/env"

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
```

**`~/.bash_profile`** — login bash; sources interactive rc then vite-plus:

```bash
[[ -f ~/.bashrc ]] && . ~/.bashrc

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
```

After creating login files, compare PATH across modes: `zsh -ic path_debug`, `zsh -lc path_debug`, `bash -lc path_debug`.

---

## `migrate.sh` behavior

Re-running `bin/migrate.sh`:

| Action | Behavior |
|--------|----------|
| `env.sh`, `aliases.sh`, `functions.sh` | **Preserved** if they already exist |
| `personal.sh` | **Not generated** — create manually or copy from repo; `aliases.sh` sources it if present |
| `~/.zshrc`, `~/.bashrc`, fish config | **Refreshed** only if missing or marked managed; **skipped** if hand-edited |
| Login dotfiles (`~/.zprofile`, `~/.profile`, `~/.bash_profile`, `~/.zshenv`) | **Backed up only** — not generated (see [Login dotfiles](#login-dotfiles-manual-setup)) |
| `--force-rc` | Overwrites rc files even when hand-edited |
| Dotfile backups | Written to `backups/TIMESTAMP/` (gitignored) with `revert.sh` |
| `completions/` | Empty placeholder directory created; reserved for future shell completions |
| Package installs (Arch) | Tries `paru -S yazi thefuck` when missing; warns on failure |
| Git | `git init` + initial commit if `~/.config/shell/.git` absent; `git add -A` + commit on every run (no-op if clean) |

Managed rc files include the marker comment `Managed by ~/.config/shell/bin/migrate.sh`. Edit `~/.config/shell/*` modules for day-to-day changes; use `--force-rc` when you intentionally want template updates in rc files.

**direnv note:** Managed zsh/bash templates call `eval "$(direnv hook …)"` without a `command -v` guard (fish template does guard). Install direnv before sourcing rc files, or edit hooks locally.

Run `bin/check-shell.sh` after migrate to confirm nothing drifted.

---

## Operations

```mermaid
flowchart LR
    edit["Edit env.sh / aliases.sh / personal.sh"] --> source["source ~/.zshrc<br/>or source ~/.bashrc"]
    source --> check["bin/check-shell.sh"]
    migrate["bin/migrate.sh"] --> backup["backups/TIMESTAMP/"]
    backup --> revert["revert.sh"]
    migrate --> regen["Regenerates ~/.zshrc, ~/.bashrc, fish config"]
    regen --> source
```

| Task | Command |
|------|---------|
| Verify config | `~/.config/shell/bin/check-shell.sh` |
| Reload zsh | `source ~/.zshrc` or `reload` |
| Reload bash | `source ~/.bashrc` |
| Re-apply template | `~/.config/shell/bin/migrate.sh` |
| Roll back dotfiles | `~/.config/shell/backups/<timestamp>/revert.sh` |

---

## Gotchas checklist

- [x] **Never alias `ga`** — Omarchy defines it as a git-worktree function; aliasing before the function breaks bash.
- [x] **`ff` consistent across shells** — `aliases.sh` loads after Omarchy in bash and zsh; `ff` = fastfetch everywhere.
- [x] **`functions.sh` wired** — sourced in bash and zsh rc files after Omarchy, before `aliases.sh`.
- [x] **`personal.sh` chained from `aliases.sh`** — not sourced directly by rc files.
- [x] **Omarchy envs not duplicated in zsh** — only via `env.sh`.
- [x] **direnv hooked** in bash and zsh when installed.
- [x] **migrate preserves modules** — won't overwrite existing `env.sh` / `aliases.sh` / `functions.sh`.
- [x] **PATH centralized** — `path_prepend`/`path_append` in `env.sh`; login files delegate; last prepend wins; use `path_debug`.
- [x] **secrets outside shell repo** — `~/.config/secrets/dev.env`; no `.envrc` in workspace.
- [ ] **fish is partial** — requires bass plugin; no `ga`/`gd` (direnv, fzf, `functions.sh`, thefuck added).
- [x] **migrate rc policy** — skips hand-edited rc files; refreshes managed ones; `--force-rc` to overwrite.
- [x] **login dotfiles manual** — migrate backs up but does not generate `~/.zprofile`, `~/.profile`, `~/.bash_profile`, `~/.zshenv`.
- [x] **direnv required for managed zsh/bash** — templates hook direnv unconditionally; install before first `source ~/.zshrc`.

---

## Related files

| Path | Purpose |
|------|---------|
| [README.md](README.md) | Philosophy, switching shells, where to add aliases, maintenance |
| [env.sh](env.sh) | Portable environment |
| [aliases.sh](aliases.sh) | Shared aliases + `personal.sh` chain |
| [personal.sh](personal.sh) | Work-specific shortcuts |
| [functions.sh](functions.sh) | Custom functions |
| [bin/migrate.sh](bin/migrate.sh) | Setup script and dotfile templates |
| [bin/check-shell.sh](bin/check-shell.sh) | Load-order verification |