# Verification cockpit — shell (local stress test)

Golden-ratio layout for **shell config verification** — every pane surfaces a concrete failure mode. No file browser or system monitor clutter.

## Layout (φ 62% / 38%)

```
+----------------------------+------------------+
|                            | SYNC (minor top) |
|  GIT / lazygit 62% w       |------------------|
|  full height               | CHECK:watch      |
|                            |------------------|
|                            | CMD (minor bot.) |
+----------------------------+------------------+
     git column 62%              ops column 38%
```

Pane indices: `0=GIT` `1=SYNC` `2=CHECK:watch` `3=CMD` (tmux reindexes during splits).

| Title | Prio | Space | What you learn |
|-------|------|-------|----------------|
| CHECK:watch | 1 | scroll | `check-shell-watch.sh` — full run first, then every 90s (no clear; scroll up for errors) |
| CMD | 2 | interactive | `agent_scan`, `gdf`, manual checks — bottom-right for mouse reach |
| GIT | 3 | tui-side | Uncommitted agent changes — major left column |
| SYNC | 4 | confirm | Managed template drift (`[y/N]` to run) |

**Dropped:** `yazi` and `btop` — useful elsewhere, not post-agent verification.

**CHECK pane:** `check-shell-watch.sh` (same as `shellyhow`) runs once in full, then appends every 90s — **does not clear** like `watch(1)`. Scroll up (`Prefix` `[`) to read the first run including shellcheck errors.

## Flows

| Alias | Config here | Notes |
|-------|-------------|-------|
| `av` | `tmux-layout.sh` (+ `cockpit.yaml` verify map) | Host delegates when this file is executable |
| `at` | `cockpit.yaml` → `cockpits.test` (legacy `tests.yaml` ok) | Priority runners |
| `ab` | — | Host `SHELL_AGENT_BUILD_CMD` only |

## Commands

```bash
av                  # this layout (delegates from agent-verify-layout.sh)
av --scan           # + agent_scan in CMD
av --generic        # skip this repo's layout; use generic 4-pane cockpit
at                  # top max_run tests from cockpit.yaml
at --watch          # same, every 60s
ab                  # build window (host env)
```

## Regenerate

Re-run `verification-cockpit` skill when verify workflow changes. Reference: `.agents/skills/verification-cockpit/`.

## at tests (priority cockpit)

Prefer `cockpit.yaml` → `cockpits.test`. Legacy `tests.yaml` still works. Top `max_run` by priority; the rest are listed as available.

| Prio | id | at runs | What |
|------|-----|---------|------|
| 1 | shellcheck | yes | `check-shell.sh --shellcheck-only` |
| 2 | workflow-root | yes | `bin/test/verify-workflow-root.test.sh` |
| 3 | load-order | listed only | full `check-shell.sh` |

```bash
at              # top 2 from cockpit.yaml
bin/run-project-tests.sh   # without tmux
```

Agents: edit `.agents/verification/cockpit.yaml` — keep `tmux-layout.sh` commands in sync for `av`.
