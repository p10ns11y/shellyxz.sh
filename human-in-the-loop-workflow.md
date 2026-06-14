# Human-in-the-loop workflow

Repeatable rituals for reviewing agent output before you commit. This doc is the **muscle-memory playbook**; [VERIFICATION.md](VERIFICATION.md) covers tooling, keymaps, and setup.

**Rule of thumb:** run verification in **Ghostty + tmux** (`t` or Super+Alt+Return). Cursor’s integrated terminal refuses `agent_verify` / `av` by design.

---

## `agent_verify` vs `agent_scan`

| | `agent_verify` (`av`) | `agent_scan` |
|--|----------------------|--------------|
| **What** | **Spatial** — arranges panes | **Temporal** — prints a report |
| **Role** | **Venue** — open the cockpit | **Survey** — run the checklist |
| **What it does** | Creates/focuses tmux `verify` window: nvim/shell, lazygit, yazi, btop | Prints rg sweep, dust summary, JSON report excerpts |
| **When** | Once, right after the agent finishes | After the cockpit is open (re-run anytime before commit) |
| **Requires** | tmux + native terminal (not Cursor) | Any shell in the project directory |
| **Alias** | `av` | — |

**Mnemonic:** **V = Venue** (space) · **S = Survey** (time)

`av` sets up *where* you work; `agent_scan` tells you *what to look at first* in that moment.

```bash
# agent_verify — layout only (bin/agent-verify-layout.sh)
av                    # same as: agent_verify .
agent_verify ~/code/my-app

# agent_scan — terminal report (functions.sh)
agent_scan .          # rg + dust + report.json / output.json
agent_scan src/
```

---

## Core ritual (drill this)

Same sequence every time. Say it while typing:

> **Tee-Zed-A-V, scan, look, diff, fix, git.**

```bash
t && z <project> && av && agent_scan .
```

| Step | Command | Where | Purpose |
|------|---------|-------|---------|
| 1 | `t` | — | tmux attach or new session `Work` |
| 2 | `z <project>` | — | Jump to repo (zoxide) |
| 3 | `av` | all panes | Open verification cockpit |
| 4 | `agent_scan .` | top-left shell | Structured spot-check |
| 5 | `y` | yazi pane | Visual sweep (mtime / modified) |
| 6 | `lg` or `gdf` | lazygit / shell | Review diffs (delta / difftastic) |
| 7 | `vf` or nvim | editor pane | Fix flagged files |
| 8 | `tt` + tests | test window + btop | Run checks; watch load |
| 9 | `lg` → commit | lazygit | Ship when satisfied |
| 10 | Prefix+d | — | Detach (layout persists) |

**tmux prefix:** `Ctrl+Space` (Omarchy). **nvim leader:** `Space`.

---

## Workflow examples

### Simple — single-file doc or comment fix

Agent updated one markdown file or a small config tweak. Low risk; you still verify before commit.

```bash
t && z ~/.config/shell && av
agent_scan .
gdf                          # one-file diff in terminal
vf                           # fuzzy-open if scan flagged something odd
lg                           # stage + commit with message
```

**Time budget:** 2–5 minutes. Skip `tt` and btop unless you changed executable scripts.

**Nvim shortcut:** open file → `<leader>vh` pin it if you bounce between doc and `check-shell.sh` output.

---

### Simple — alias or env one-liner

Agent added an alias or export. Confirm it loads and doesn’t shadow Omarchy reserved names.

```bash
t && z ~/.config/shell && av
agent_scan .
source ~/.zshrc && check-shell.sh    # top-left shell pane
gdf                                  # aliases.sh / env.sh only?
```

If `check-shell` is clean and diff looks right → `lg` commit. No cockpit re-layout needed on return visits; `tmux select-window -t verify` if session still open.

---

### Moderate — multi-file feature in one repo

Agent touched several files (e.g. new shell function + migrate template + doc). Standard post-agent flow.

```bash
t && z my-project && av
agent_scan .
y                                # yazi: sort by modified, skim tree
lg                               # lazygit: delta side-by-side per file
gdf                              # or gdfs for staged-only pass
vf                               # open anything scan highlighted
tt                               # new tmux window: npm test / cargo test / ./bin/check-shell.sh
ps                               # procs — glance at test processes (btop pane too)
agent_scan .                     # re-survey before commit
lg                               # commit with scoped message
```

**Nvim parallel:** `<leader>va` (TODO/FIXME preset) → `<leader>vf` → edit → `<leader>sg` for one more grep pass.

**JSON agent report present:**

```bash
agent_scan .                     # auto-pretty-prints report.json / output.json
jq '.issues[]' report.json | bat -l json
```

---

### Moderate — agent changed dependencies or install paths

Agent edited `package.json`, `Cargo.toml`, migrate `paru` block, or PATH in `env.sh`. Verify install + load order.

```bash
t && z my-project && av
agent_scan .
gdf
mise install / npm install / paru -S <pkg>   # only if agent added deps — you run, not blind trust
source ~/.zshrc
check-shell.sh
tt && <project test command>
ps | head                        # procs: confirm no runaway dev servers
lg
```

**Red flags in `agent_scan`:** `ERROR`, `panic!`, `unwrap(`, new `TODO`/`FIXME` in production paths.

---

### Complex — cross-repo or worktree session

Agent worked in a worktree or you have agent output in repo A affecting repo B (shell config + live dotfiles).

```bash
t
z shell-repo && av && agent_scan .
# review ~/.config/shell changes in lazygit
lg                               # commit portable modules first

z app-repo && av && agent_scan .
lg                               # separate verify window per project (Prefix+w / M-2 switch)
```

Use **separate tmux windows** per repo (`Prefix+c` or `tt`). Pin shared context with nvim Harpoon (`<leader>vh`) on the file you keep re-opening.

**Shell + live config:** after committing `~/.config/shell`, run `migrate.sh` in a third pane only if rc templates changed — then `source ~/.zshrc` in a fresh pane and `check-shell.sh`.

---

### Complex — agent left tests failing or partial implementation

Agent “finished” but CI would fail. Full loop with fix iterations.

```bash
t && z my-project && av
agent_scan .
rg --vimgrep 'TODO|FIXME|unimplemented' src/ | nvim -q -   # quickfix list in nvim pane
lg                               # see full diff scope
tt                               # run test suite
# fix loop:
vf                               # or nvim quickfix jumps
agent_scan .                     # after each fix batch
gdf
tt                               # re-run until green
ps                               # btop + procs if tests spawn servers
lg                               # commit only when tests pass
```

**Do not commit** until step 4 of super-flow is satisfied: you understand every hunk (`lg` or `gdf`) and tests you care about pass (`tt`).

---

### Complex — security- or secrets-sensitive diff

Agent touched auth, env loading, `personal.sh`, or `~/.config/secrets/`. Slow down; no autopilot.

```bash
t && z my-project && av
agent_scan .
gdf                              # full unstaged pass
rg -n 'password|secret|api[_-]?key|token' .   # manual; exclude .git
check-shell.sh --audit           # if shell repo: dev.env permissions
lg                               # review hunk-by-hunk; never commit .env / secrets
```

**Never commit:** `~/.config/secrets/*`, API keys, `.envrc` with live credentials. `check-shell` and `.gitignore` are guardrails, not substitutes for reading the diff.

---

## Decision tree

```
Agent finished
    │
    ├─ In Cursor terminal? ──yes──► Open Ghostty → t
    │
    └─ In Ghostty/tmux? ──no──► t
            │
            ▼
        z <project> → av          (venue)
            │
            ▼
        agent_scan .              (survey)
            │
            ├─ 1–2 files, docs only? ──► gdf → lg → done
            │
            ├─ feature / multi-file? ──► y → lg → tt → agent_scan → lg
            │
            └─ tests red / security? ──► rg/nvim quickfix → fix loop → tt → lg
```

---

## Command cheat sheet

| Situation | Reach for |
|-----------|-----------|
| Open cockpit | `av` |
| Quick terminal checklist | `agent_scan .` |
| Browse changed files | `y` (yazi) |
| Git UI + delta | `lg` |
| Terminal structural diff | `gdf` / `gdfs` |
| Fuzzy open file | `vf` |
| New test window | `tt` |
| Process glance | `ps` (procs) / btop pane |
| nvim grep preset | `<leader>va` |
| nvim find in cwd | `<leader>vf` |
| Reload tmux config | Prefix+q |

---

## Related docs

- [VERIFICATION.md](VERIFICATION.md) — philosophy, cockpit layout, tmux/nvim keys, toolchain
- [bin/README.md](bin/README.md) — `migrate.sh`, `check-shell.sh`, `agent-verify-layout.sh`
- [shell.md](shell.md) — load order, `functions.sh` / `aliases.sh` modules
