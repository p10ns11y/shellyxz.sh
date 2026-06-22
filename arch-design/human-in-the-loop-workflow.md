# Human-in-the-loop workflow

Repeatable rituals for reviewing agent output before you commit. This doc is the **muscle-memory playbook**; [VERIFICATION.md](VERIFICATION.md) covers tooling, keymaps, and setup.

**Rule of thumb:** run verification in **Ghostty + tmux** (`t` or Super+Alt+Return). Cursor’s integrated terminal refuses `agent_build` / `agent_verify` (`ab` / `av`) by design.

See [VERIFICATION.md — What happens (ab → av)](VERIFICATION.md#what-happens-when-you-run-ab-then-av) for exact side effects (`av --scan`, `@workflow_dir`, status bar).

> **Meta-tooling, on purpose:** you use agents to build tooling that makes *human* review of agent output faster. The loop is: agent works in focus layout → you verify in the cockpit → you commit (or send the agent back). AI assists; you approve.

---

## Platform note (Arch vs other distros)

`bin/migrate.sh` auto-installs optional tools via **paru on Arch** (`yazi`, `thefuck`, `procs`, `difftastic`). On other distros, install manually:

```bash
# Arch (automated by migrate when paru exists)
paru -S procs difftastic git-delta yazi thefuck

# Other distros — package names vary; need: procs, difft (difftastic), delta, bat, rg, fd
# e.g. cargo install git-delta difftastic, or your package manager equivalent
```

Then: `source ~/.zshrc` and `git config --global include.path ~/.config/git/verification`.

---

## Build → Verify → Loop

Three tmux windows form the agent workflow:

| Window | Command | Purpose |
|--------|---------|---------|
| `build` | `ab` / Prefix+B | Agent build — single full pane for Grok Build (`grok`) or other agent TUIs |
| `verify` | `av` / Prefix+V | Review cockpit — lazygit (major left), watch panes, shell CMD (bottom-right) |
| `test` | `at` | Test cockpit — btop left, priority tests right (see `.agents/verification/tests.yaml`) |

**Mnemonic:** **ab** = agent **b**uild · **av** = agent **v**erify · **at** = agent **t**est · tmux **B** / **V** · **Z** = Zoom (ad-hoc inside any window)

```bash
t && z <project> && ab              # full-screen grok in `build`
# agent runs...
av                                  # verify layout only
av --scan                           # verify + agent_scan checklist
# review: lg, gdf, vf, at
# not happy:
ab -c                               # back to grok --continue in `build`
```

**Omarchy `tdl` / `ic` / `ix`** — nvim + Claude side-by-side while the agent runs. Use **`ab`** when you want the whole screen for the agent TUI.

---

## `agent_verify` vs `agent_scan`

| | `agent_verify` (`av`) | `agent_scan` |
|--|----------------------|--------------|
| **What** | **Spatial** — arranges panes | **Temporal** — prints a report |
| **Role** | **Venue** — open the cockpit | **Survey** — run the checklist |
| **What it does** | Creates/focuses tmux `verify` window: lazygit, watch panes, shell CMD | Prints rg sweep, dust summary, JSON report excerpts |
| **When** | After the agent finishes | When you want a checklist (`av --scan` or manual) |
| **Requires** | tmux + native terminal (not Cursor) | Any shell in the project directory |
| **Alias** | `av` | — |

**Mnemonic:** **V = Venue** (space) · **S = Survey** (time)

`av` sets up *where* you work; `agent_scan` tells you *what to look at first* in that moment.

```bash
t && z <project> && ab && av --scan
```

Use `av --scan` when you want the checklist; plain `av` only opens the cockpit. Re-run `agent_scan .` manually before commit if you made more edits.

---

## Cockpit tour (what each pane is for)

After `av`, you get the golden φ verify grid (this repo uses `.agents/verification/` as its local stress-test layout):

```
+----------------------------+------------------+
|                            | SYNC (minor top) |
|  lazygit 62% w             |------------------|
|  full height               | CHECK:watch      |
|                            |------------------|
|                            | CMD (minor bot.) |
+----------------------------+------------------+
```

| Pane | Tool | Your job there |
|------|------|----------------|
| Left | lazygit | File list, **delta** diffs, stage (`space`), commit (`c`) |
| Right top | SYNC / confirm | Template drift, one-shot verify (`[y/N]`) |
| Right center | CHECK:watch | `check-shell-watch.sh` — live guardrail output |
| Right bottom | shell / CMD | `agent_scan .`, `gdf`, `vf`, edits — default focus |

**Note:** Many users run nvim in a separate window (Omarchy `eff` / `n`) instead of the verify CMD pane. CMD is for short verify commands (`agent_scan`, `gdf`, `vf`); use `vf` or your editor workflow for file edits.

**Test window (`at`):** separate `test` window — btop left (62%), priority tests right. Top 2 from `tests.yaml`; full audit via `shellyhow` or `bin/run-project-tests.sh --all`.

**tmux window:** `verify` (and `test` when you run `at`). **Zoom:** Prefix+Z on a pane when you need full width (e.g. `gdf` side-by-side).

**Narrow panes:** `ff` (fastfetch) truncates in thin panes — run it full-width before `av`, or use `fastfetch --logo none`.

**Visual file sweep:** use `y` (yazi) in a separate pane or window — not in the default verify layout.

---

## Core ritual (drill this)

> **Tee-Zed-A-W, verify, look, diff, fix, git.**

| Step | Command | Pane |
|------|---------|------|
| 1 | `t` | — |
| 2 | `z <project>` | — |
| 3 | `ab` | `build` — full-screen agent |
| 4 | `av --scan` | `verify` layout + optional `agent_scan` |
| 5 | `y` | yazi (optional visual sweep) |
| 6 | `lg` / `gdf` | lazygit / shell |
| 7 | `vf` / nvim | editor |
| 8 | `at` | `test` window — btop + priority tests |
| 9 | `lg` → `c` | lazygit commit |
| 10 | Prefix+d | detach |

**Not happy with the diff?** `ab -c` (or `agent_back`) returns to `build` with `grok -c`.

---

## Example A — clean agent pass (docs only)

Agent added one new markdown file and updated cross-links. lazygit shows a small diff; `agent_scan` may look noisy but is harmless.

**lazygit:** `human-in-the-loop-workflow.md` (A), `VERIFICATION.md` (M) — small hunks.

**`agent_scan` output:**

```
./VERIFICATION.md:85:3. **Structured scan** — `agent_scan .` ...
./functions.sh:65:        rg -n 'TODO|FIXME|panic!|unwrap\(|ERROR|error:'
./bin/migrate.sh:54:error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
```

**Triage:** all **noise** — docs mentioning the scanner, or `error()` helper names. No action.

**Flow:**

```bash
t && z ~/.config/shell && av && agent_scan .
# lazygit: read new doc hunks → space stage → c commit
```

---

## Example B — messy / realistic agent pass (multi-file, mixed signal)

Agent touched **7+ files**: `README.md`, `VERIFICATION.md`, `aliases.sh`, `bin/migrate.sh`, `bin/check-shell.sh`, `shell.md`, `git.ex.config`, plus untracked `human-in-the-loop-workflow.md`. Some changes are good; some need editing. This is the case Grok asked for — **noise + real review**.

### 1. Spatial — open cockpit

```bash
t && z ~/.config/shell && av
```

**lazygit Files pane:** scan the list — anything unexpected? (`??` untracked, `M` modified). Click each file; **delta** diff in center pane.

### 2. Temporal — survey (filter noise)

```bash
agent_scan .
```

| `agent_scan` hit | Verdict | Action |
|------------------|---------|--------|
| `VERIFICATION.md` mentions `agent_scan` | Noise | Ignore |
| `functions.sh:65` rg pattern | Noise | Scanner source |
| `migrate.sh:54` `error()` | Noise | Log helper, not app error |
| `check-shell.sh` `ERROR:` string | Noise | Test harness message |
| *New* `TODO` in `aliases.sh` | **Signal** | Open in nvim / `vf` |
| `dust` shows huge new dir | **Signal** | `y` → investigate |

### 3. Diff strategy — pick the right lens

| Change type | Tool | Why |
|-------------|------|-----|
| Markdown tables / prose | `lg` (delta inline) or `gdf README.md` | Readable word-level highlights |
| Shell logic (`migrate.sh`, `check-shell.sh`) | `gdf bin/migrate.sh` | **difftastic** structural view for `if`/`fi` blocks |
| Config snippet (`git.ex.config`) | `lg` + `vf` | Small file; fuzzy-open to edit comments |
| “Did agent break load order?” | `source ~/.zshrc && check-shell.sh` | shell pane — must pass 0 errors |

**From your cockpit session:**

- `gdf shell.md` — side-by-side table row change (`aliases.sh` description) — **keep** if accurate.
- `lg` on `README.md` — paru line gains `procs difftastic` — **keep** if migrate matches.
- `vf` → `tmux.verify.conf.ex` — confirm Prefix+Z / Prefix+V bindings still make sense.

### 4. Fix loop (human irons out agent slop)

```bash
# Edit in nvim pane or:
vf migrate.sh
# Re-survey:
agent_scan .
check-shell.sh
gdf                          # full unstaged pass
```

**Reject** agent changes that: shadow Omarchy (`ga`, `gd`, `n`), skip `command -v` guards, or add secrets.

### 5. Ship in slices (not one blind commit)

lazygit: stage **by concern** — e.g. commit 1 toolchain (`aliases.sh`, `check-shell.sh`, `migrate.sh`), commit 2 docs (`human-in-the-loop-workflow.md`, `VERIFICATION.md`). Matches how you’d review a PR.

```bash
# lazygit: space per hunk/file → c → message → repeat
```

---

## Example C — agent left failing checks

```bash
t && z my-project && av
agent_scan .
bin/run-project-tests.sh      # or shellyhow for full audit
# fix → agent_scan . → gdf → at → lg
```

Do not `lg` commit until checks you care about are green.

---

## Example D — security-sensitive diff

```bash
t && z my-project && av
agent_scan .
rg -n 'password|secret|api[_-]?key|token' --glob '!.git' .
gdf
check-shell.sh --audit       # if shell repo
```

Never commit secrets. Read every hunk in `lg` even when `agent_scan` is quiet.

---

## Interpreting `agent_scan` (quick reference)

| Section | Means |
|---------|--------|
| `=== rg sweep ===` | Grep for TODO/FIXME/panic/unwrap/ERROR — **smoke alarm**, not verdict |
| `=== dust ===` | Largest paths — spot unexpected bulk or new dirs |
| `=== report.json ===` | Agent left structured output — read `.summary` / `.issues` |

**Noise in `~/.config/shell`:** hits in `VERIFICATION.md`, `functions.sh`, `migrate.sh`, `check-shell.sh` are usually self-reference. **Signal in app repos:** new hits under `src/`, `lib/`, etc.

---

## Decision tree

```
Start task → Ghostty → t → z → ab (agent build in `build`)
Agent done → av --scan (or av then agent_scan .)
    → noise only? → lg/gdf review → commit
    → signal? → vf/nvim fix → re-scan → commit
    → not happy? → ab -c → agent fixes → av again
    → tests/security? → at / shellyhow → commit when green
```

---

## Command cheat sheet

| Situation | Command |
|-----------|---------|
| Agent build | `ab` / Prefix+B |
| Open cockpit | `av` / Prefix+V |
| Test cockpit | `at` (`tt` legacy) |
| Scan checklist | `av --scan` or `agent_scan .` |
| Back to agent | `ab -c` / `agent_back` |
| Checklist | `agent_scan .` |
| Git UI + delta | `lg` |
| Structural terminal diff | `gdf` / `gdfs` |
| Fuzzy open | `vf` |
| Zoom pane | Prefix+Z |
| Config file peek | `vf` → type `tmux` / `migrate` |
| Validate shell repo | `check-shell.sh` / `shellyhow` |
| Priority tests only | `at` or `bin/run-project-tests.sh` |

---

## Related docs

- [VERIFICATION.md](VERIFICATION.md) — philosophy, keys, toolchain setup
- [bin/README.md](../bin/README.md) — migrate, check-shell, agent-verify-layout
- [shell.md](shell.md) — load order
