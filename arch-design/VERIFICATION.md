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

Run verification in **Ghostty + tmux** (`t` or Super+Alt+Return). Cursor integrated terminals skip `mise activate` and refuse `agent_work` / `agent_verify` (`aw` / `av`) (phantom-tab / no-cockpit UX).

---

## Tool map

| Tool / concern | Where it lives |
|----------------|----------------|
| PATH, fzf defaults | `env.sh` |
| `top`, `lg`, `ff`, `y`, `aw`, `av`, guarded `cat`/`grep`/`find`/`ps`, `gdf`/`gdfs` | `aliases.sh` |
| `vf`, `agent_scan`, `agent_work`, `agent_verify`, `agent_back` | `functions.sh` |
| Focus layout script | `bin/agent-focus-layout.sh` |
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

**Work window** (`aw` / Prefix+W): single full pane — Grok Build (`grok`) or custom agent command.

**Verify window** (`av` / Prefix+V):

```
+--------------------+---------------------+
|   nvim / shell     |   lazygit           |
+--------------------+---------------------+
|   yazi (mtime sort)                      |
+------------------------------------------+
|   btop                                   |
+------------------------------------------+
```

**Open focus + verify:**

```bash
t                              # Omarchy: tmux attach || new -s Work
z my-project                   # zoxide jump
aw                             # zen agent focus (grok default)
# ... agent runs ...
av                             # or: agent_verify .
# inside tmux: Prefix+V        # C-Space V (verify overlay binding)
# not happy: aw -c             # grok --continue in work window
```

---

## Omarchy tmux keys (reference)

| Key | Action |
|-----|--------|
| `C-Space` | Prefix (also `C-b` as prefix2) |
| `Prefix + h` | Split horizontal (pane below) |
| `Prefix + v` | Split vertical (pane right) |
| `Prefix + W` | Zen agent focus (`work` window) |
| `Prefix + V` | Verification cockpit |
| `Prefix + Z` | Zoom pane |
| `Prefix + Space` | Cycle layout |
| `M-1` … `M-9` | Select window |
| `Prefix + q` | Reload tmux.conf |

Hyprland: **Super+Alt+Return** → tmux.

---

## Agent super-flow (8 steps)

0. **Focus** — `aw` (full-screen grok/agent in `work` window) or Omarchy `tdl` / `ic` for nvim+agent splits
1. **Jump** — `z project` or `tmux select-window -t verify`
2. **Verify** — `av` (opens cockpit; runs `agent_scan .` in shell pane)
3. **Visual sweep** — `y` → sort modified (`o` `m` in yazi if not using `yazi.ex.toml` defaults)
4. **Review diffs** — `lg` (lazygit + delta) or `gdf` / `gdfs` (difftastic in terminal)
5. **Targeted tests** — `tt` for new test window; watch btop pane
6. **Fix loop** — `vf` or `rg --vimgrep 'pat' src/ \| nvim -q -`; `aw -c` if agent must continue; `thefuck` for rushed commands
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
| `agent_work [dir] [cmd...]` / `aw` | tmux zen focus (`work` window; grok default) |
| `agent_back` | `aw -c` — return to agent with `grok -c` |
| `agent_verify [dir]` / `av` | tmux cockpit layout (+ auto `agent_scan`) |
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
aw                             # zen agent focus (grok)
av                             # verify cockpit after agent runs
```

End of day: detach tmux — `work` and `verify` windows persist in session.

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
