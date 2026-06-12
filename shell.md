# Shell environment architecture

How `~/.config/shell/` layers portable environment, Omarchy, and shell-native tooling across **zsh**, **bash**, and **fish**.

For day-to-day editing guidance see [README.md](README.md). This document is the **accurate load-order reference** — verified against live dotfiles and `bin/migrate.sh`.

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
    functions --> aliases
    aliases --> personal
    zshrc --> aliases
    bashrc --> aliases
    fishcfg --> aliases
```

**Key idea:** `env.sh` is the portable foundation (including Omarchy envs). Omarchy aliases and functions load next. `functions.sh` and `aliases.sh` load after Omarchy so your overrides win. `personal.sh` chains from the tail of `aliases.sh`. **Bash and zsh integrate Omarchy differently** — modular in zsh, `rc` bundle in bash — but override semantics match.

---

## `~/.config/shell` modules

| File | Role | Sourced by |
|------|------|------------|
| `env.sh` | `path_add`, exports (SSH, GPG, threads), Omarchy envs, cargo/vite loaders | zsh, bash, fish (via bass) |
| `aliases.sh` | yazi `y()`, monitoring aliases, `ff`/`lg`/`n`, git shortcuts; **chains** `personal.sh` | zsh, bash, fish (via bass) |
| `personal.sh` | Work aliases (`agrepos`, `agcore`, `agproto`) | via `aliases.sh` tail only |
| `functions.sh` | Custom functions (placeholder today) | zsh, bash rc files |
| `bin/migrate.sh` | Generates dotfiles, backups; preserves existing modules | manual run |
| `bin/check-shell.sh` | Verifies load order, direnv hooks, reserved names | manual run |

### What `env.sh` sets up

```mermaid
flowchart LR
    subgraph path_add["path_add (deduped, prepended)"]
        p1["~/.local/bin"]
        p2["~/bin"]
        p3["mise shims"]
        p4["bun, opencode, solana, pnpm, cargo, risc0, grok"]
        p5["mamba (late)"]
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

    path_add --> exports --> loaders
```

---

## Login vs interactive layers

Some environment is applied **before** `~/.zshrc` or `~/.bashrc` run.

```mermaid
flowchart TD
    subgraph zsh_stack["zsh startup"]
        Z1["~/.zshenv<br/>every zsh: cargo, vite-plus"]
        Z2["~/.zprofile<br/>login only: hardcoded PATH"]
        Z3["~/.zshrc<br/>interactive: full stack"]
        Z1 --> Z2 --> Z3
    end

    subgraph bash_stack["bash startup"]
        B1["~/.profile or ~/.bash_profile<br/>login: PATH, GPG, cargo, vite-plus"]
        B2["~/.bashrc<br/>interactive: full stack"]
        B1 --> B2
        B3["~/.bash_profile may re-source vite-plus after bashrc"]
        B2 --> B3
    end
```

**Caveat:** PATH is built in multiple places (`path_add` in `env.sh`, Omarchy `OMARCHY_PATH/bin`, hardcoded exports in `~/.zprofile`). Later entries do not always win — `path_add` prepends, so order inside `env.sh` matters.

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
    F1["bass → env.sh"] --> F2["bass → Omarchy aliases"]
    F2 --> F3["bass → aliases.sh<br/>(chains personal.sh)"]
    F3 --> F4["starship / zoxide / mise (fish native)"]

    F5["❌ not loaded"] --- F5a["Omarchy functions (ga, gd)"]
    F5 --- F5b["functions.sh"]
    F5 --- F5c["fzf, thefuck, direnv"]
```

Fish gets PATH/exports, Omarchy aliases, and work shortcuts via `aliases.sh` → `personal.sh`. Worktree helpers (`ga`, `gd`) need fish-native rewrites or wrappers.

---

## Tool initialization matrix

| Tool | zsh | bash | fish | Where |
|------|-----|------|------|-------|
| direnv | `.zshrc` | `.bashrc` | — | hook after `env.sh` |
| mise | `.zshrc` | Omarchy `init` | `config.fish` | |
| starship | `.zshrc` | Omarchy `init` | `config.fish` | |
| zoxide | `.zshrc` | Omarchy `init` | `config.fish` | |
| fzf | `.zshrc` | Omarchy `init` | — | |
| thefuck | `.zshrc` | — | — | |
| compinit | `.zshrc` | — | — | |
| grok completions | `.zshrc` | — | — | |

---

## `migrate.sh` behavior

Re-running `bin/migrate.sh`:

| Action | Behavior |
|--------|----------|
| `env.sh`, `aliases.sh`, `functions.sh` | **Preserved** if they already exist |
| `~/.zshrc`, `~/.bashrc`, fish config | **Regenerated** from templates |
| Dotfile backups | Written to `backups/TIMESTAMP/` with `revert.sh` |

Templates match live load order: Omarchy before `aliases.sh`, direnv hooked, `functions.sh` wired, `personal.sh` chained in generated `aliases.sh`.

Run `bin/check-shell.sh` after migrate to confirm nothing drifted.

---

## Operations

```mermaid
flowchart LR
    edit["Edit env.sh / aliases.sh / personal.sh"] --> check["bin/check-shell.sh"]
    check --> source["source ~/.zshrc<br/>or source ~/.bashrc"]
    migrate["bin/migrate.sh"] --> backup["backups/TIMESTAMP/"]
    backup --> revert["revert.sh"]
    migrate --> regen["Regenerates ~/.zshrc, ~/.bashrc, fish config"]
    regen --> check
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
- [ ] **PATH is set in `env.sh`, Omarchy, and `~/.zprofile`** — debug with `echo $PATH` per shell.
- [ ] **fish is partial** — no `ga`/`gd`, no `functions.sh`, no `thefuck`/`fzf`/`direnv`.
- [ ] **migrate still regenerates** `~/.bashrc` / `~/.zshrc` — update migrate templates before re-running if you've hand-edited rc files.

---

## Related files

| Path | Purpose |
|------|---------|
| [README.md](README.md) | Philosophy, where to add aliases, maintenance |
| [env.sh](env.sh) | Portable environment |
| [aliases.sh](aliases.sh) | Shared aliases + `personal.sh` chain |
| [personal.sh](personal.sh) | Work-specific shortcuts |
| [functions.sh](functions.sh) | Custom functions |
| [bin/migrate.sh](bin/migrate.sh) | Setup script and dotfile templates |
| [bin/check-shell.sh](bin/check-shell.sh) | Load-order verification |