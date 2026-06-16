# `bin/` — operational scripts

Executable helpers for **setup**, **verification**, and **recovery** of `~/.config/shell/`. Run from a working shell unless noted; paths assume `$HOME/.config/shell`.

See also: [README.md](../README.md) (overview), [VERIFICATION.md](../arch-design/VERIFICATION.md) (cockpit workflow), [human-in-the-loop-workflow.md](../arch-design/human-in-the-loop-workflow.md) (repeatable drills), [shell.md](../arch-design/shell.md) (load order).

---

## Quick reference

| Script | When to run | Prerequisites | Exit code |
|--------|-------------|---------------|-----------|
| [migrate.sh](#migratesh) | First install, refresh managed rc, scaffold dotfiles | bash, curl (bootstrap), Omarchy recommended | 0 on success; `set -e` aborts on hard errors |
| [check-shell.sh](#check-shellsh) | After edits or migrate | bash; optional `shellcheck` | 0 if no **errors** (warnings OK) |
| [recover-shell.sh](#recover-shellsh) | Broken rc / `source` loops | bash only | 0 (informational menu) |
| [agent-build-layout.sh](#agent-build-layoutsh) | Open tmux agent build window | **Inside tmux**, tmux on PATH | 0 on success; 1 if not in tmux |
| [agent-verify-layout.sh](#agent-verify-layoutsh) | Open tmux verification cockpit | **Inside tmux**, tmux on PATH | 0 on success; 1 if not in tmux |
| [fzf-preview.sh](#fzf-previewsh) | *(internal)* fzf bat preview | bat | inherits bat exit code |

---

## Cold-start paths

### Path A — git clone (full tree, recommended)

```bash
git clone git@github.com:p10ns11y/shellyxz.sh.git ~/.config/shell
~/.config/shell/bin/migrate.sh
source ~/.zshrc    # or ~/.bashrc
git config --global include.path ~/.config/git/verification   # if migrate did not set it
~/.config/shell/bin/check-shell.sh
```

Includes verification assets (`agent-build-layout.sh`, `agent-verify-layout.sh`, `fzf-preview.sh`, `arch-design/VERIFICATION.md`, example configs).

### Path B — curl one-liner (bootstrap)

```bash
curl -fsSL https://raw.githubusercontent.com/p10ns11y/shellyxz.sh/refs/heads/master/bin/migrate.sh | bash
source ~/.zshrc
git config --global include.path ~/.config/git/verification
~/.config/shell/bin/check-shell.sh
```

`migrate.sh` auto-fetches missing core files from `SHELL_CONFIG_RAW`. **Limitation:** remote bootstrap fetches only the file list in `bootstrap_from_remote()` inside `migrate.sh` — verification scaffolds (tmux/yazi/git examples) require a full clone or `migrate.sh --bootstrap` after those files exist locally.

Override source for forks:

```bash
SHELL_CONFIG_RAW=https://raw.githubusercontent.com/you/shellyxz.sh/refs/heads/master \
  curl -fsSL "$SHELL_CONFIG_RAW/bin/migrate.sh" | bash
```

---

## migrate.sh

**Purpose:** One-command migration — backup dotfiles, generate portable modules (first run), refresh **managed** rc/login/fish files, scaffold starship/tmux/yazi/git when absent.

```bash
~/.config/shell/bin/migrate.sh [--force-rc] [--bootstrap]
```

| Flag | Effect |
|------|--------|
| `--force-rc` | Overwrite managed dotfiles (`~/.zshrc`, login files, fish) even if hand-edited (no managed marker) |
| `--bootstrap` | Re-fetch missing repo files from `SHELL_CONFIG_RAW` |
| `-h`, `--help` | Usage and one-liner install URL |

**Environment:** `SHELL_CONFIG_RAW` — GitHub raw base URL (default: `p10ns11y/shellyxz.sh` master).

**What it does (summary):**

1. Backs up existing dotfiles to `backups/TIMESTAMP/` + `revert.sh`
2. Bootstraps missing files when piped, `--bootstrap`, or `lib.sh` absent
3. Generates `env.sh`, `aliases.sh`, `functions.sh` **only if missing** (preserves yours)
4. Regenerates managed `~/.zshrc`, `~/.bashrc`, fish config, login dotfiles (skips hand-edited unless `--force-rc`)
5. Copies `starship.ex.toml` → `~/.config/starship.toml` when absent
6. Scaffolds verification (when example files exist locally):
   - Omarchy `tmux.conf` → `~/.config/tmux/tmux.conf` + `verify.conf` include
   - `yazi.ex.toml` → `~/.config/yazi/yazi.toml`
   - `git.ex.config` → `~/.config/git/verification`
7. `chmod +x` on `agent-build-layout.sh`, `agent-verify-layout.sh`, `fzf-preview.sh`
8. Attempts `git add -A && git commit` inside `~/.config/shell` (no-op if nothing to commit)

**Preserves:** existing `env.sh`, `aliases.sh`, `functions.sh`, hand-edited rc files (without `--force-rc`), existing `starship.toml`, tmux/yazi/git configs.

**Arch note:** tries `paru -S yazi thefuck procs difftastic` when `paru` exists; fails softly otherwise. **Other distros:** install those packages manually — see [human-in-the-loop-workflow.md](../arch-design/human-in-the-loop-workflow.md#platform-note-arch-vs-other-distros).

**Git delta:** migrate copies `git.ex.config` → `~/.config/git/verification` and sets `git config --global include.path` when not already configured. Re-run manually if needed:

```bash
git config --global include.path ~/.config/git/verification
```

**Difftastic:** `gdf` / `gdfs` aliases in `aliases.sh` when `difft` is on PATH (`paru -S difftastic` on Arch).

**Revert:**

```bash
~/.config/shell/backups/<timestamp>/revert.sh
```

---

## check-shell.sh

**Purpose:** Validate load order, reserved names, verification helpers, fish hooks, and run **shellcheck** on `*.sh` under `~/.config/shell/`.

```bash
~/.config/shell/bin/check-shell.sh [--audit]
```

| Flag | Effect |
|------|--------|
| `--audit` | Extra: `dev.env` mode 600, `recover-shell.sh` executable, `lib.sh` present |
| `-h`, `--help` | Usage |

**Default checks include:**

- No `.envrc` in shell repo; `lib.sh` wired into `env.sh`
- Omarchy before `aliases.sh` in bash/zsh rc
- Reserved names (`ga`, `n`; runtime `gd` in zsh)
- Login dotfiles delegate to `env.sh`
- Verification: `FZF_DEFAULT_OPTS`, `agent_build`, `agent_verify`, `vf`, layout scripts, `tmux.conf`, `arch-design/VERIFICATION.md`
- Git delta: `include.path` when `~/.config/git/verification` exists; `delta`, `procs`, `difft` on PATH (warn if missing)
- Optional nvim `verification-workflow.lua` (warn if missing)
- fish: direnv, `functions.sh`, fzf, thefuck
- **shellcheck** on all `*.sh` (warns if `shellcheck` not installed — `pacman -S shellcheck`)

**Exit:** `0` only when `errors=0`. Warnings do not fail the script.

---

## recover-shell.sh

**Purpose:** Minimal PATH recovery menu when rc files are broken. Does **not** auto-revert — prints options only.

```bash
bash --norc ~/.config/shell/bin/recover-shell.sh
```

Use `bash --norc` if `~/.bashrc` is also broken. **No flags** — any argument is ignored (including `--help`).

**Printed options:**

1. Latest `backups/*/revert.sh`
2. Clean shell: `exec zsh -f` / `exec bash --norc`
3. Edit `env.sh`, `aliases.sh` directly
4. `migrate.sh --force-rc`
5. `check-shell.sh`

**Note:** `revert.sh` restores bash/zsh/login/starship — not fish `config.fish`.

---

---

## agent-build-layout.sh

**Purpose:** Create or focus the **build** tmux window — single full pane for agent TUIs (Grok Build default). See [VERIFICATION.md](../arch-design/VERIFICATION.md).

```bash
~/.config/shell/bin/agent-build-layout.sh [directory] [--continue] [-- command...]
```

| Arg | Default | Effect |
|-----|---------|--------|
| `directory` | `.` | Working directory; stored as `@workflow_dir` on the session |
| `--continue` / `-c` | — | Launch `grok -c` in the build pane |
| `-- cmd...` | — | Launch a custom command (e.g. `cx` for Claude) |

**Requirements:** same as agent-verify-layout (tmux, inside tmux).

**Behavior:**

- If window `build` exists → `select-window`
- Else if legacy `work` exists → rename to `build`
- Else creates `build` window and launches `grok` by default
- Sets `@workflow_mode` to `build` on the session

**Entry points:**

- Shell: `agent_build` / `ab` (`af`/`aw`/`agent_work` legacy), `agent_back` (from `functions.sh`)
- tmux: `Prefix+B` via `~/.config/tmux/verify.conf`

---

## verify-workflow-root.sh

**Purpose:** Print the canonical project root shared by `ab`, `av`, and `agent_scan` (layout walk-up → git toplevel → cwd).

**Shell (after `reload`):**

```bash
verify_workflow_root              # from any subdirectory
verify_workflow_root /path/to/dir # explicit start
```

**Script (no shell function needed):**

```bash
~/.config/shell/bin/verify-workflow-root.sh [directory]
```

`verify-workflow-root.sh` is **not** on `PATH` by default — use the function or full path.

**Tests:** `bin/test/verify-workflow-root.test.sh` (also run by `check-shell.sh`).

---

## tmux-mode-sync.sh

**Purpose:** Apply status-bar mode display (`PREFIX` · `COPY` · `INSERT`/`NORMAL` · `ZOOM`) with correct `status-right-length` (120).

```bash
~/.config/shell/bin/tmux-mode-sync.sh apply workflow   # default bar
~/.config/shell/bin/tmux-mode-sync.sh apply soc        # verify cockpit theme
~/.config/shell/bin/tmux-mode-sync.sh set-editor insert|normal|''
```

Library: `bin/lib/tmux-status-mode.sh` — format string source of truth.

---

## tmux-keymap-menu.sh

**Purpose:** Workflow keymap helper — fzf popup (preferred) or tmux `display-menu` fallback.

```bash
~/.config/shell/bin/tmux-keymap-menu.sh
```

| Trigger | Action |
|---------|--------|
| `Prefix+?` | Open menu |
| Click status-right (`?` hint) | Open menu |

Data file: `bin/data/tmux-keymaps.tsv` — shell aliases, tmux binds, nvim leader keys.

---

## agent-verify-layout.sh

**Purpose:** Create or focus the **verify** tmux window. Delegates to `.agents/verification/tmux-layout.sh` when present. See [VERIFICATION.md](../arch-design/VERIFICATION.md).

```bash
~/.config/shell/bin/agent-verify-layout.sh [directory] [--generic]
```

| Arg | Default | Effect |
|-----|---------|--------|
| `directory` | `.` | Resolved via `verify_workflow_root` before layout (walk-up from cwd) |
| `--generic` | off | Skip project layout; use generic cockpit |

**Requirements:**

- `tmux` on PATH
- **Must run inside tmux** (`$TMUX` set) — use Omarchy `t` or Super+Alt+Return first

**Behavior:**

- If `.agents/verification/tmux-layout.sh` exists and `--generic` not set → `exec` project layout
- If window `verify` exists → `select-window` (idempotent; runs `agent_scan` only when `av --scan` / `@workflow_rescan=1`)
- Else creates generic `verify` window:
  - Pane 0 (top-left): shell — `agent_scan`, `gdf`, `vf`
  - Pane 1 (right, 42%): `lazygit` if installed
  - Pane 2 (left bottom, 40%): `yazi` if installed
  - Pane 3 (below yazi, 35%): `btop` if installed

**Entry points:**

- Shell: `agent_verify` / `av` (from `functions.sh` — also blocks Cursor integrated terminal)
- tmux: `Prefix+V` (`C-Space` `V` with Omarchy prefix) via `~/.config/tmux/verify.conf`

**No `--help`** — do not pass `-h` (it is interpreted as a directory).

---

## verify-launch.sh / verify-pane-launch.sh

**Purpose:** Tiered pane launches for project verification cockpits.

| Script | Role |
|--------|------|
| `bin/lib/verify-launch.sh` | Library: `verify_launch_pane`, `verify_apply_theme`, `verify_maybe_rescan` |
| `bin/verify-pane-launch.sh` | In-pane confirm gate for `verify` / `mutate` tiers |

**Tiers:** `monitor`/`watch` auto-launch; `verify` prompts `[y/N]`; `mutate` requires `av --launch-mutate` and typing `YES`.

**Theme:** `tmux.verify-soc-theme.conf.ex` — amber SOC status bar applied by project layouts.

---

## fzf-preview.sh

**Purpose:** Internal **fzf `--preview`** helper. Files get `bat` with line numbers; Ctrl+R history lines are stripped of their index and highlighted as shell.

```sh
~/.config/shell/bin/fzf-preview.sh <file-or-history-line>
```

**Wired by:** `core/env.sh` when `fzf` + `bat` present and **not** in editor terminal (`SHELL_IN_EDITOR_TERMINAL=no`):

- `FZF_CTRL_T_OPTS` — file search preview (right pane)
- `FZF_CTRL_R_OPTS` — history search preview (bottom pane)
- `FZF_DEFAULT_OPTS` — layout only (no global preview)

**Do not run manually** unless debugging preview. Requires `bat` on PATH.

---

## Typical workflows

### After editing portable modules

```bash
source ~/.zshrc
~/.config/shell/bin/check-shell.sh
```

### Refresh managed rc templates

```bash
~/.config/shell/bin/migrate.sh --sync-rc   # managed files only
# or overwrite hand-edited rc files:
~/.config/shell/bin/migrate.sh --force-rc
```

### Agent output verification

```bash
t                    # tmux attach
z my-project
ab                   # agent build (grok)
# ... agent runs ...
av --scan            # verify cockpit + agent_scan
# or: av             # layout only
# not happy: ab -c
```

### Nuclear recovery

```bash
bash --norc ~/.config/shell/bin/recover-shell.sh
```

---

## Bootstrap file list (remote fetch)

Files fetched by `bootstrap_from_remote()` when missing (authoritative list in `bin/lib/migrate-common.sh`):

| Group | Paths |
|-------|--------|
| **Core** | `core/{lib,path,path.contract,env,aliases,functions}.sh`, root shims (`env.sh`, `lib.sh`, …) |
| **Environments** | `environments/{generic,omarchy}/*`, `environment.example`, `environments/README.md` |
| **Templates** | `templates/{zshrc,bashrc,fish.config.fish,login/*,core/*}` |
| **Bin** | `bin/migrate.sh`, `bin/lib/`, `bin/tasks/`, `bin/check-shell.sh`, `bin/check-template-sync.sh`, `bin/scaffold-environment.sh`, `bin/recover-shell.sh`, `bin/fzf-preview.sh`, `bin/agent-build-layout.sh`, `bin/agent-verify-layout.sh` |
| **Docs & examples** | `README.md`, `arch-design/{shell,VERIFICATION,SHELL-env-var-behavior}.md`, `starship.ex.toml`, `yazi.ex.toml`, `git.ex.config`, `.gitignore` |
| **Local** | `local/personal.sh` |

Files already present are never overwritten.
