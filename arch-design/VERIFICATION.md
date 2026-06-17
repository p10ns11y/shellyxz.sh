# Verification workflow

Human-in-the-loop verification cockpit for agent output. Goal: **insight + action in under 10 seconds** after an agent finishes.

See [README.md](../README.md) for shell setup; [shell.md](shell.md) for load order. **Genesis:** [motivation.md](../motivation.md). **Repeatable drills:** [human-in-the-loop-workflow.md](human-in-the-loop-workflow.md) (cockpit tour, messy-diff triage, examples).

---

## Philosophy: frictionless feedback loops

- **Persistent context** — tmux is the source of truth; detach and resume without losing panes.
- **Preview before you act** — bat, fzf, yazi, lazygit, delta reduce blind commits.
- **Fuzzy + visual** — zoxide, fzf, yazi replace path typing.
- **One concern per pane** — editor, git review, file browser, monitor together.
- **Composability** — pipe rg → fzf → nvim; jq + bat on JSON agent reports.
- **Human stays in the loop** — tools collapse time between "agent done" and "I understand + I act".

Run verification in **Ghostty + tmux** (`t` or Super+Alt+Return). Cursor integrated terminals skip `mise activate` and refuse `agent_build` / `agent_verify` (`ab` / `av`; `af`/`aw`/`agent_work` are legacy) (phantom-tab / no-cockpit UX).

---

## What happens when you run `ab` then `av`

Explicit cause-and-effect — layout scripts only send keys when you ask (e.g. `grok` on first `build` open, `agent_scan` only with `av --scan`).

| Step | You type | What runs | Side effects |
|------|----------|-----------|--------------|
| 1 | `ab` (or Prefix+B) | `agent_build` → `bin/agent-build-layout.sh` | Creates/focuses tmux window `build` (one full pane). Sets `@workflow_dir` and `@workflow_mode build`. On **first** open only: sends `grok`. Renames legacy window `work` → `build` if present. |
| 2 | *(agent runs)* | Your agent TUI in `build` | No automatic hooks. Other apps/notifications unchanged — this is **one tmux pane**, not OS-level focus mode. |
| 3 | `av` (or Prefix+V) | `agent_verify` → `bin/agent-verify-layout.sh` | Creates/focuses window `verify` (golden-ratio insight layout; project-specific panes). Updates `@workflow_dir` / `@workflow_mode verify`. **Does not** run `agent_scan` unless you passed `--scan`. |
| 4 | `av --scan` | same + `agent_scan` in verify CMD pane | Opt-in rg/dust/JSON sweep at workflow root. tmux shows brief message: `agent_scan (av --scan)`. |
| 5 | `ab -c` / `agent_back` | Build layout + `grok -c` | Returns to `build`; no scan. |

**Session state (tmux options on the session):**

| Option | Set by | Purpose |
|--------|--------|---------|
| `@workflow_dir` | build or verify layout | Canonical project root (`verify_workflow_root`: layout walk-up → git toplevel → cwd) |
| `@workflow_mode` | build or verify layout | `build` / `verify` — status bar when `@workflow_status` is `on` |
| `@workflow_rescan` | `agent_verify --scan` only | Triggers one `agent_scan` in verify shell pane |

**Status bar:** toggle with `tmux set -g @workflow_status off` or use minimal `status-right` in `tmux.verify.conf.ex`.

**Mode indicators** (status-right, applied by `bin/tmux-mode-sync.sh`):

| Label | When |
|-------|------|
| `PREFIX` | Prefix key held (C-Space / C-b) |
| `COPY` | tmux copy mode (`#{pane_in_mode}`) |
| `INSERT` / `NORMAL` | nvim active pane (`@editor_mode` via verification-workflow plugin + `tmux-mode-sync.sh`) |
| `ZOOM` | Zoomed pane |
| `build` / `verify` | `@workflow_mode` when `@workflow_status` is on |
| `?` | Keymap menu hint — **Prefix+?** or **click status-right** |

`status-right-length` is set to **120** so mode labels are not truncated (default Omarchy `50` hides them).

**Keymap menu:** `~/.config/shell/bin/tmux-keymap-menu.sh` — fzf popup (or tmux `display-menu` fallback). Data: `bin/data/tmux-keymaps.tsv`.

**Mnemonic:** **ab** = agent **b**uild · **av** = agent **v**erify · tmux **B** / **V** (shifted — does not conflict with tmux `b` last-window).

---

## Tool map

| Tool / concern | Where it lives |
|----------------|----------------|
| PATH, fzf defaults | `env.sh` |
| `top`, `lg`, `ff`, `y`, `ab`, `av`, guarded `cat`/`grep`/`find`/`ps`, `gdf`/`gdfs` | `aliases.sh` |
| `vf`, `agent_scan`, `agent_build`, `agent_verify`, `agent_back` | `functions.sh` |
| Build layout script | `bin/agent-build-layout.sh` |
| Cockpit layout script | `bin/agent-verify-layout.sh` |
| tmux base | Omarchy → `~/.config/tmux/tmux.conf` |
| tmux verify bindings | `tmux.verify.conf.ex` + `tmux.status-mode.conf.ex` → `~/.config/tmux/verify.conf` |
| tmux mode display | `bin/tmux-mode-sync.sh` + `bin/lib/tmux-status-mode.sh` |
| yazi defaults | `yazi.ex.toml` → `~/.config/yazi/yazi.toml` |
| git delta | `git.ex.config` → `~/.config/git/verification` |
| nvim Telescope + Harpoon | `~/.config/nvim/lua/plugins/verification-workflow.lua` |
| eza ls, eff, zd, tmux `t` | Omarchy `default/bash/aliases` |

**Naming:** `ff` = fastfetch (shell repo). Use `fzf` or Omarchy `eff` for fuzzy file pick.

---

## Cockpit layout

**Build window** (`ab` / Prefix+B): single full pane — Grok Build (`grok`) or custom agent command. One tmux pane only — not OS-level “do not disturb”.

**Verify window** (`av` / Prefix+V): project layouts use the **golden-ratio insight grid** below. `av --generic` falls back to a sparse 4-pane shell (CMD + empty WATCH/BUILD + lazygit) until you generate `.agents/verification/` with the verification-cockpit skill.

### Project-specific cockpit

When a project has `.agents/verification/tmux-layout.sh`, `av` delegates to it (SOC-style mission-control theme, project watch panes). Generate per repo with the [`verification-cockpit` skill](../.agents/skills/verification-cockpit/SKILL.md). **Dogfood:** this shell repo ships [`.agents/verification/`](../.agents/verification/README.md) as a stress test (`check-shell.sh` watch + template sync).

| Artifact | Purpose |
|----------|---------|
| `.agents/verification/manifest.yaml` | Pane map + launch tiers |
| `.agents/verification/tmux-layout.sh` | Layout script (`av` auto-delegates) |
| `.agents/verification/tmux-theme.conf` | Optional theme overrides |
| `.cursor/verify` | Symlink → `../.agents/verification` |

**Launch tiers:**

| Tier | On `av` | Examples |
|------|---------|----------|
| `monitor` / `watch` | auto-start | `lazygit`, `pnpm test --watch`, `cargo watch -x check` |
| `verify` | confirm `[y/N]` in pane | `pnpm test`, `cargo test`, `pnpm build` |
| `mutate` | blocked unless `av --launch-mutate` | `pnpm install`, migrations, deploy |

**Golden-ratio default** (φ 62% / 38%) — high-priority watchers get major area; omit low-signal panes (btop, yazi) unless they surface verify failures. See `verification-cockpit` skill.

```
+----------------------------+------------------+
|                            | SYNC (minor top) |
|  GIT / lazygit 62% w       |------------------|
|  full height               | WATCH / CHECK    |
|                            |------------------|
|                            | CMD (minor bot.) |
+----------------------------+------------------+
     git column 62%              ops column 38%
```

**Flags:**

| Command | Effect |
|---------|--------|
| `av` | Project layout if present, else generic cockpit |
| `av --scan` | + `agent_scan .` in console pane |
| `av --generic` | Force generic 4-pane layout |
| `av --launch-mutate` | Allow mutate-tier confirm prompts |

**Open focus + verify:**

```bash
t                              # Omarchy: tmux attach || new -s Work
z my-project                   # zoxide jump
ab                             # agent build (grok default)
# ... agent runs ...
av                             # verify cockpit (layout only)
av --scan                      # verify + agent_scan in shell pane
# inside tmux: Prefix+V
# not happy: ab -c             # grok --continue in build window
```

---

## Omarchy tmux keys (reference)

| Key | Action |
|-----|--------|
| `C-Space` | Prefix (also `C-b` as prefix2) |
| `Prefix + h` | Split horizontal (pane below) |
| `Prefix + v` | Split vertical (pane right) |
| `Prefix + B` | Agent build (`build` window) |
| `Prefix + V` | Verification cockpit |
| `Prefix + ?` | Keymap menu (or click status-right `?`) |
| `Prefix + Z` | Zoom pane |
| `Prefix + Space` | Cycle layout |
| `M-1` … `M-9` | Select window |
| `Prefix + q` | Reload tmux.conf |

Hyprland: **Super+Alt+Return** → tmux.

---

## Agent super-flow (8 steps)

0. **Build** — `ab` (full-screen grok/agent in `build` window) or Omarchy `tdl` / `ic` for nvim+agent splits
1. **Jump** — `z project` or `tmux select-window -t verify`
2. **Verify** — `av` (opens cockpit; run `av --scan` for checklist sweep)
3. **Visual sweep** — `y` → sort modified (`o` `m` in yazi if not using `yazi.ex.toml` defaults)
4. **Review diffs** — `lg` (lazygit + delta) or `gdf` / `gdfs` (difftastic in terminal)
5. **Targeted tests** — `tt` (one-shot) or `tt --watch`; btop left, tests right
6. **Fix loop** — `vf` or `rg --vimgrep 'pat' src/ \| nvim -q -`; `ab -c` if agent must continue; `thefuck` for rushed commands
7. **Close loop** — commit in lazygit; detach tmux (`Prefix+d` default detach)

**JSON reports:**

```bash
jq '.summary, .issues' report.json | bat -l json
```

---

## Shell helpers

| Command | Purpose |
|---------|---------|
| `vf` | Fuzzy find file → `$EDITOR` |
| `agent_scan [dir]` | rg sweep + dust + JSON reports |
| `agent_build [dir] [cmd...]` / `ab` | tmux build window (grok default) |
| `agent_back` | `ab -c` — return to agent with `grok -c` |
| `agent_verify [dir]` / `av` | tmux verify cockpit |
| `av --scan` | verify cockpit + `agent_scan .` (opt-in) |
| `av --generic` | skip project `.agents/verification/` layout |
| `av --launch-mutate` | allow mutate-tier pane launches |
| `tt` / `tt --watch` | Test window: btop 62% left, project tests right (pnpm/cargo/check-shell) |
| `ps` | procs (when installed; replaces POSIX `ps`) |
| `gdf` / `gdfs` | git diff with difftastic (unstaged / staged) |
| `eff` | Omarchy: fzf → editor |
| `shell_debug` | Show editor-terminal detection |

---

## Neovim (LazyVim + Telescope)

Plugin: `~/.config/nvim/lua/plugins/verification-workflow.lua`

| Key | Action |
|-----|--------|
| `<leader>sg` | live_grep (project root) |
| `<leader>/` | live_grep |
| `<leader>ff` | find_files |
| `<leader>va` | live_grep preset: TODO/FIXME/panic/unwrap |
| `<leader>vf` | find_files (cwd) |
| `<leader>vh` | Harpoon: pin file |
| `<leader>hj` / `<leader>hk` | Harpoon: next / prev |
| `<leader>ht` | Harpoon: quick menu |

Terminal quickfix bridge:

```bash
rg --vimgrep 'pattern' src/ | nvim -q -
```

---

## Daily rhythm

```bash
ff                             # fastfetch — context at a glance
t                              # tmux daily session
z <project>                    # jump
ab                             # agent build (grok)
av                             # verify cockpit
av --scan                      # + agent_scan
av                             # verify cockpit after agent runs
```

End of day: detach tmux — `build` and `verify` windows persist in session.

---

## Verification toolchain

Aliases are **guarded** (`command -v`); once packages are installed they activate on `source ~/.zshrc`.

| Package | Command / alias | Role |
|---------|-----------------|------|
| `procs` | `ps` | Process list with filters (btop pane companion) |
| `delta` | via `lg`, `git diff`, `git log` | Syntax-highlighted pager diffs (lazygit + terminal) |
| `difftastic` (`difft`) | `gdf`, `gdfs` | Structural diff in terminal without lazygit |

**Enable delta** (required once after migrate scaffolds `~/.config/git/verification`):

```bash
git config --global include.path ~/.config/git/verification
```

`delta` is expected on `PATH` (`~/.cargo/bin` via `env.sh`, or `pacman -S git-delta`). See [git.ex.config](../git.ex.config).

**Optional extras**

| Package | Why |
|---------|-----|
| TPM + tmux-resurrect | Session survive reboot (manual setup) |

---

## Setup / migrate

```bash
~/.config/shell/bin/migrate.sh   # scaffolds tmux, yazi, git when absent
git config --global include.path ~/.config/git/verification   # enable delta
source ~/.zshrc
~/.config/shell/bin/check-shell.sh
```

In nvim after plugin add: `:Lazy sync` then confirm Telescope extra loads.
