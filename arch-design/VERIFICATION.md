# Verification workflow

Human-in-the-loop verification cockpit for agent output. Goal: **insight + action in under 10 seconds** after an agent finishes.

See [README.md](../README.md) for shell setup; [shell.md](shell.md) for load order. **Repeatable drills:** [human-in-the-loop-workflow.md](human-in-the-loop-workflow.md) (cockpit tour, messy-diff triage, examples).

---

## Philosophy: frictionless feedback loops

- **Persistent context** — tmux is the source of truth; detach and resume without losing panes.
- **Preview before you act** — bat, fzf, yazi, lazygit, delta reduce blind commits.
- **Fuzzy + visual** — zoxide, fzf, yazi replace path typing.
- **One concern per pane** — editor, git review, file browser, monitor together.
- **Composability** — pipe rg → fzf → nvim; jq + bat on JSON agent reports.
- **Human stays in the loop** — tools collapse time between "agent done" and "I understand + I act".

Run verification in **Ghostty + tmux** (`t` or Super+Alt+Return). Cursor integrated terminals skip `mise activate` and refuse `agent_verify` (phantom-tab / no-cockpit UX).

---

## Tool map

| Tool / concern | Where it lives |
|----------------|----------------|
| PATH, fzf defaults | `env.sh` |
| `top`, `lg`, `ff`, `y`, `av`, guarded `cat`/`grep`/`find`/`ps`, `gdf`/`gdfs` | `aliases.sh` |
| `vf`, `agent_scan`, `agent_verify` | `functions.sh` |
| Cockpit layout script | `bin/agent-verify-layout.sh` |
| tmux base | Omarchy → `~/.config/tmux/tmux.conf` |
| tmux verify bindings | `tmux.verify.conf.ex` → `~/.config/tmux/verify.conf` |
| yazi defaults | `yazi.ex.toml` → `~/.config/yazi/yazi.toml` |
| git delta | `git.ex.config` → `~/.config/git/verification` |
| nvim Telescope + Harpoon | `~/.config/nvim/lua/plugins/verification-workflow.lua` |
| eza ls, eff, zd, tmux `t` | Omarchy `default/bash/aliases` |

**Naming:** `ff` = fastfetch (shell repo). Use `fzf` or Omarchy `eff` for fuzzy file pick.

---

## Cockpit layout

```
+--------------------+---------------------+
|   nvim / shell     |   lazygit           |
+--------------------+---------------------+
|   yazi (mtime sort)                      |
+------------------------------------------+
|   btop                                   |
+------------------------------------------+
```

**Open it:**

```bash
t                              # Omarchy: tmux attach || new -s Work
z my-project                   # zoxide jump
av                             # or: agent_verify .
# inside tmux: Prefix+V        # C-Space V (verify overlay binding)
```

---

## Omarchy tmux keys (reference)

| Key | Action |
|-----|--------|
| `C-Space` | Prefix (also `C-b` as prefix2) |
| `Prefix + h` | Split horizontal (pane below) |
| `Prefix + v` | Split vertical (pane right) |
| `Prefix + V` | Verification cockpit |
| `Prefix + Z` | Zoom pane |
| `Prefix + Space` | Cycle layout |
| `M-1` … `M-9` | Select window |
| `Prefix + q` | Reload tmux.conf |

Hyprland: **Super+Alt+Return** → tmux.

---

## Agent super-flow (7 steps)

1. **Jump** — `z project` or `tmux select-window -t verify`
2. **Visual sweep** — `y` → sort modified (`o` `m` in yazi if not using `yazi.ex.toml` defaults)
3. **Structured scan** — `agent_scan .` or `rg 'TODO|FIXME|panic|unwrap' src/ | head -20`
4. **Review diffs** — `lg` (lazygit + delta) or `gdf` / `gdfs` (difftastic in terminal)
5. **Targeted tests** — `tt` for new test window; watch btop pane
6. **Fix loop** — `vf` or `rg --vimgrep 'pat' src/ \| nvim -q -`; `thefuck` for rushed commands
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
| `agent_verify [dir]` / `av` | tmux cockpit layout |
| `tt` | New tmux window `test` in current path |
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
y / vf                         # browse or fuzzy-open
av                             # agent verify mode after agent runs
```

End of day: detach tmux — layout persists in session.

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
