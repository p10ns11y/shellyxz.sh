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
        functions["functions.sh<br/>⚠ not sourced today"]
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
    aliases --> personal
    zshrc --> oaliases
    zshrc --> ofns
    bashrc --> orc
    orc --> oenvs
    orc --> oaliases
    orc --> ofns
    orc --> oinit

    zshrc --> aliases
    bashrc --> aliases
```

**Key idea:** `env.sh` is the portable foundation. Omarchy is your personal base layer (aliases, functions, tool hooks). `aliases.sh` adds non-conflicting extras and chains `personal.sh` at the end. **Bash and zsh integrate Omarchy differently** — do not assume one shared order.

---

## `~/.config/shell` modules

| File | Role | Sourced by |
|------|------|------------|
| `env.sh` | `path_add`, exports (SSH, GPG, threads), Omarchy envs, cargo/vite loaders | zsh, bash, fish (via bass) |
| `aliases.sh` | yazi `y()`, monitoring aliases, `ff`/`lg`/`n`, git shortcuts; **chains** `personal.sh` | zsh, bash |
| `personal.sh` | Work aliases (`agrepos`, `agcore`, `agproto`) | via `aliases.sh` tail only |
| `functions.sh` | Placeholder for custom functions | **nothing today** |
| `bin/migrate.sh` | Generates dotfiles, backups, intended load order | manual run |

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

Recommended daily driver. Omarchy is sourced **modularly** (not via `rc`).

```mermaid
flowchart TD
    A["1. env.sh"] --> B["2. Omarchy envs"]
    B --> C["3. Omarchy aliases"]
    C --> D["4. Omarchy functions<br/>ga/gd worktrees, fns/*"]
    D --> E["5. aliases.sh"]
    E --> F["5a. personal.sh<br/>(chained inside aliases.sh)"]
    F --> G["6. mise activate zsh"]
    G --> H["7. starship init zsh"]
    H --> I["8. zoxide init zsh"]
    I --> J["9. fzf --zsh"]
    J --> K["10. thefuck --alias"]
    K --> L["11. compinit + history opts"]
    L --> M["12. grok completions"]
    M --> N["13. zshconfig, reload aliases"]

    A -.->|"also loads Omarchy envs"| B
```

| Step | File / command | Notes |
|------|----------------|-------|
| 1 | `env.sh` | Already sources Omarchy `envs` — step 2 duplicates that file |
| 4 | Omarchy `functions` | Defines `ga()` git-worktree helper — **never alias `ga`** |
| 5 | `aliases.sh` | `ff` = **fastfetch** (wins over Omarchy here) |
| 6–10 | tool inits | All in `.zshrc`, not Omarchy `init` |

**Intended (migrate.sh):** inserts `direnv hook zsh` after `env.sh`. Live `~/.zshrc` does **not** have direnv yet.

---

## bash load order

Bash uses Omarchy's monolithic `rc` bundle instead of modular parts.

### Live `~/.bashrc` (current)

```mermaid
flowchart TD
    A["1. env.sh"] --> B["2. aliases.sh + personal.sh"]
    B --> C["3. Omarchy rc"]
    C --> C1["envs"]
    C1 --> C2["shell"]
    C2 --> C3["aliases<br/>ff = fzf preview"]
    C3 --> C4["functions<br/>ga/gd worktrees"]
    C4 --> C5["init<br/>mise, starship, zoxide, fzf bash"]
    C5 --> C6["completions + inputrc"]
    C6 --> D["4. bash history opts"]

    style B fill:#f9f,stroke:#333
```

The pink step is the problem: **`aliases.sh` runs before Omarchy `rc`**. Omarchy aliases loaded later can override yours — notably `ff` means **fzf** in bash but **fastfetch** in zsh.

### Intended (`migrate.sh` template)

```mermaid
flowchart TD
    A["1. env.sh"] --> B["2. direnv hook bash"]
    B --> C["3. Omarchy rc<br/>(envs → aliases → functions → init)"]
    C --> D["4. aliases.sh + personal.sh"]
    D --> E["5. bash history opts"]
```

This order matches zsh semantics: Omarchy functions like `ga()` load **before** `aliases.sh`, so bash does not hit `syntax error near unexpected token '('` if someone re-adds `alias ga=`.

---

## Omarchy integration: zsh vs bash

```mermaid
flowchart LR
    subgraph zsh_mode["zsh — modular"]
        z1["env.sh"] --> z2["envs"]
        z2 --> z3["aliases"]
        z3 --> z4["functions"]
        z4 --> z5["aliases.sh"]
        z5 --> z6["tool inits in .zshrc"]
    end

    subgraph bash_mode["bash — rc bundle"]
        b1["env.sh"] --> b2["aliases.sh<br/>(live: wrong order)"]
        b2 --> b3["rc → envs, shell, aliases, functions, init"]
        b3 --> b4["hist opts"]
    end
```

| Concern | zsh | bash (live) | bash (migrate template) |
|---------|-----|-------------|-------------------------|
| Omarchy envs | twice (env.sh + .zshrc) | via rc | via rc |
| `ga` worktree fn | Omarchy functions | Omarchy functions (if no `alias ga` first) | safe order |
| `ff` | fastfetch | fzf (Omarchy wins) | fastfetch if order fixed |
| mise / starship | `.zshrc` | Omarchy `init` inside rc | Omarchy `init` |
| thefuck | `.zshrc` only | not loaded | not loaded |
| direnv | missing live | missing live | after env.sh |

---

## Override precedence

Later definitions win **within the same shell**, but bash and zsh load Omarchy at different points.

```mermaid
flowchart TD
    subgraph zsh_precedence["zsh — who wins"]
        direction TB
        ZO["Omarchy aliases/functions"]
        ZA["aliases.sh + personal.sh"]
        ZO --> ZA
        ZA -->|"ff, gs, gc, top, df, du"| ZWINS["aliases.sh wins for those names"]
    end

    subgraph bash_precedence["bash live — who wins"]
        direction TB
        BA["aliases.sh + personal.sh"]
        BO["Omarchy rc aliases/functions"]
        BA --> BO
        BO -->|"ff, many Omarchy aliases"| BWINS["Omarchy wins for overlapping names"]
    end
```

### Reserved names

| Name | Owner | Meaning | Do not |
|------|-------|---------|--------|
| `ga` | Omarchy `fns/worktrees` | `git worktree add` helper | `alias ga='git add'` |
| `gd` | Omarchy `fns/worktrees` | remove worktree + branch | alias over it |
| `ff` | **conflict** | fastfetch (zsh) vs fzf (bash live) | assume same across shells |

---

## fish (best-effort)

```mermaid
flowchart TD
    F1["bass → env.sh"] --> F2["bass → Omarchy aliases only"]
    F2 --> F3["starship / zoxide / mise (fish native)"]
    F3 --> F4["abbr: n, lg, ff, cls"]

    F5["❌ not loaded"] --- F5a["aliases.sh / personal.sh"]
    F5 --- F5b["Omarchy functions (ga, gd)"]
    F5 --- F5c["fzf, thefuck, direnv"]
```

Fish gets PATH/exports and some Omarchy aliases. Work shortcuts (`agrepos`, etc.) and worktree helpers are **not** available unless you add fish-native equivalents.

---

## Tool initialization matrix

| Tool | zsh | bash | fish | Where |
|------|-----|------|------|-------|
| direnv | migrate only | migrate only | — | hook after `env.sh` |
| mise | `.zshrc` | Omarchy `init` | `config.fish` | |
| starship | `.zshrc` | Omarchy `init` | `config.fish` | |
| zoxide | `.zshrc` | Omarchy `init` | `config.fish` | |
| fzf | `.zshrc` | Omarchy `init` | — | |
| thefuck | `.zshrc` | — | — | |
| compinit | `.zshrc` | — | — | |
| grok completions | `.zshrc` | — | — | |

---

## Live vs `migrate.sh` drift

Re-running `bin/migrate.sh` regenerates dotfiles. Your live configs may differ:

| Item | Live | migrate.sh generates |
|------|------|----------------------|
| bash Omarchy order | aliases **before** rc | rc **before** aliases |
| direnv | absent | hooked in bash + zsh |
| `aliases.sh` → `personal.sh` | chained in live file | not in migrate heredoc |

Align live dotfiles with migrate (or update migrate to match your edits) before the next migration run.

---

## Operations

```mermaid
flowchart LR
    edit["Edit env.sh / aliases.sh / personal.sh"] --> source["source ~/.zshrc<br/>or source ~/.bashrc"]
    migrate["bin/migrate.sh"] --> backup["backups/TIMESTAMP/"]
    backup --> revert["revert.sh"]
    migrate --> regen["Regenerates ~/.zshrc, ~/.bashrc, fish config"]
```

| Task | Command |
|------|---------|
| Reload zsh | `source ~/.zshrc` or `reload` |
| Reload bash | `source ~/.bashrc` |
| Re-apply template | `~/.config/shell/bin/migrate.sh` |
| Roll back dotfiles | `~/.config/shell/backups/<timestamp>/revert.sh` |

---

## Gotchas checklist

- [ ] **Never alias `ga`** — Omarchy defines it as a git-worktree function; aliasing first breaks bash with a syntax error.
- [ ] **`ff` differs by shell** on live bash (fzf) vs zsh (fastfetch) due to load order.
- [ ] **`functions.sh` is documented but unused** — wire it into rc files or remove from README.
- [ ] **`personal.sh` is not sourced by rc directly** — only via the tail of `aliases.sh`.
- [ ] **Omarchy envs load twice in zsh** — harmless but redundant.
- [ ] **PATH is set in `env.sh`, Omarchy, and `~/.zprofile`** — debug with `echo $PATH` per shell.
- [ ] **fish is partial** — no `ga`, no `personal.sh`, no `thefuck`/`fzf`.
- [ ] **migrate overwrites** manual `~/.bashrc` / `~/.zshrc` fixes unless migrate.sh is updated first.

---

## Related files

| Path | Purpose |
|------|---------|
| [README.md](README.md) | Philosophy, where to add aliases, maintenance |
| [env.sh](env.sh) | Portable environment |
| [aliases.sh](aliases.sh) | Shared aliases + `personal.sh` chain |
| [personal.sh](personal.sh) | Work-specific shortcuts |
| [bin/migrate.sh](bin/migrate.sh) | Setup script and intended dotfile templates |
