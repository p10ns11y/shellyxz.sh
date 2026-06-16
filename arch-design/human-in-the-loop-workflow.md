# Human-in-the-loop workflow

Repeatable rituals for reviewing agent output before you commit. This doc is the **muscle-memory playbook**; [VERIFICATION.md](VERIFICATION.md) covers tooling, keymaps, and setup.

**Rule of thumb:** run verification in **Ghostty + tmux** (`t` or Super+Alt+Return). Cursor’s integrated terminal refuses `agent_work` / `agent_verify` (`aw` / `av`) by design.

> **Meta-tooling, on purpose:** you use agents to build tooling that makes *human* review of agent output faster. The loop is: agent works in focus mode → you verify in the cockpit → you commit (or send the agent back). AI assists; you approve.

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

## Focus → Verify → Loop

Two tmux windows form the agent workflow:

| Window | Command | Purpose |
|--------|---------|---------|
| `work` | `aw` / Prefix+W | Zen focus — single full pane for Grok Build (`grok`) or other agent TUIs |
| `verify` | `av` / Prefix+V | Review cockpit — lazygit, yazi, btop, shell |

**Mnemonic:** **W = Work (zen)** · **V = Verify (cockpit)** · **Z = Zoom (ad-hoc inside any window)**

```bash
t && z <project> && aw              # full-screen grok in `work`
# agent runs...
av                                  # switch to verify (+ auto agent_scan)
# review: lg, gdf, vf, tt
# not happy:
aw -c                               # back to grok --continue in `work`
# happy:
# lg → commit → Prefix+d detach
```

**Omarchy `tdl` / `ic` / `ix`** — different mode: nvim + Claude side-by-side while the agent runs. Use **`aw`** when you want the whole screen for the agent TUI.

---

## `agent_verify` vs `agent_scan`

| | `agent_verify` (`av`) | `agent_scan` |
|--|----------------------|--------------|
| **What** | **Spatial** — arranges panes | **Temporal** — prints a report |
| **Role** | **Venue** — open the cockpit | **Survey** — run the checklist |
| **What it does** | Creates/focuses tmux `verify` window: nvim/shell, lazygit, yazi, btop | Prints rg sweep, dust summary, JSON report excerpts |
| **When** | Once, right after the agent finishes | After the cockpit is open (`av` runs it automatically; re-run anytime) |
| **Requires** | tmux + native terminal (not Cursor) | Any shell in the project directory |
| **Alias** | `av` | — |

**Mnemonic:** **V = Venue** (space) · **S = Survey** (time)

`av` sets up *where* you work; `agent_scan` tells you *what to look at first* in that moment.

```bash
t && z <project> && aw && av
```

`av` runs `agent_scan .` in the shell pane on entry. Re-run `agent_scan .` manually before commit if you made more edits.

---

## Cockpit tour (what each pane is for)

After `av`, you get four regions. This matches the tmux + lazygit + delta + difftastic layout in practice:

```
+--------------------+---------------------+
|  shell / nvim      |  lazygit            |  ← lg: stage, diff, commit
+--------------------+---------------------+
|  yazi              |  (lazygit continues)|
+------------------------------------------+
|  btop              |                     |  ← ps/tt: tests & load
+------------------------------------------+
```

| Pane | Tool | Your job there |
|------|------|----------------|
| Top-left | shell / nvim | `agent_scan .`, `gdf`, `vf`, `check-shell.sh`, edits |
| Top-right | lazygit | File list, **delta** diffs, stage (`space`), commit (`c`) |
| Bottom-left | yazi | Visual sweep — what changed, sorted by mtime |
| Bottom-right | btop | Watch CPU/RAM while `tt` runs tests |

**tmux window:** `2:verify` (or `verify` window name). **Zoom:** Prefix+Z on a pane when you need full width (e.g. `gdf` side-by-side, or `ff` before splitting).

**Narrow panes:** `ff` (fastfetch) truncates in thin panes — run it full-width before `av`, or use `fastfetch --logo none`.

---

## Core ritual (drill this)

> **Tee-Zed-A-W, verify, look, diff, fix, git.**

| Step | Command | Pane |
|------|---------|------|
| 1 | `t` | — |
| 2 | `z <project>` | — |
| 3 | `aw` | `work` — full-screen agent |
| 4 | `av` | `verify` layout (+ auto `agent_scan`) |
| 5 | `y` | yazi |
| 6 | `lg` / `gdf` | lazygit / shell |
| 7 | `vf` / nvim | editor |
| 8 | `tt` + tests | test window + btop |
| 9 | `lg` → `c` | lazygit commit |
| 10 | Prefix+d | detach |

**Not happy with the diff?** `aw -c` (or `agent_back`) returns to `work` with `grok -c`.

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
check-shell.sh               # or project test command in tt window
# fix → agent_scan . → gdf → tt → lg
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
Start task → Ghostty → t → z → aw (zen agent work)
Agent done → av (verify cockpit + agent_scan)
    → noise only? → lg/gdf review → commit
    → signal? → vf/nvim fix → re-scan → commit
    → not happy? → aw -c → agent fixes → av again
    → tests/security? → slow loop → commit when green
```

---

## Command cheat sheet

| Situation | Command |
|-----------|---------|
| Zen agent focus | `aw` / Prefix+W |
| Open cockpit | `av` / Prefix+V |
| Back to agent | `aw -c` / `agent_back` |
| Checklist | `agent_scan .` |
| Git UI + delta | `lg` |
| Structural terminal diff | `gdf` / `gdfs` |
| Fuzzy open | `vf` |
| Zoom pane | Prefix+Z |
| Config file peek | `vf` → type `tmux` / `migrate` |
| Validate shell repo | `check-shell.sh` |

---

## Related docs

- [VERIFICATION.md](VERIFICATION.md) — philosophy, keys, toolchain setup
- [bin/README.md](../bin/README.md) — migrate, check-shell, agent-verify-layout
- [shell.md](shell.md) — load order
