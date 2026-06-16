---
name: verification-cockpit
description: >-
  Generates project-specific tmux verification cockpits for repos that use the
  ~/.config/shell av workflow. Reads target project AGENTS.md, setup docs, and
  scripts; writes .agents/verification/ with SOC-style panes and tiered
  auto-launch. Distributable skill — copy from ~/.config/shell/.agents/skills/ into
  the target project; do not run against the shell config repo itself.
---

# Verification Cockpit Generator

**Distributable skill** — lives in `~/.config/shell/.agents/skills/` as source-of-truth. Primary use: generate layouts **in app/library repos**. This shell repo also ships a **dogfood** copy at `.agents/verification/` to stress-test the stack.

**Output:** `.agents/verification/` in the **workspace you are verifying** (target project or this repo). `av` auto-delegates when `tmux-layout.sh` exists there.

## Adopt in a target project

Copy or symlink this skill into the **project you are verifying**:

```bash
mkdir -p /path/to/my-app/.cursor/skills
ln -sfn ~/.config/shell/.agents/skills/verification-cockpit /path/to/my-app/.cursor/skills/verification-cockpit
# or: cp -a ~/.config/shell/.agents/skills/verification-cockpit /path/to/my-app/.cursor/skills/
```

Open that project in Cursor, then invoke the skill. It generates `.agents/verification/*` **in that repo** — tweak manifest and layout for that stack.

**Prerequisite:** shell workflow installed (`av`, `ab`, `~/.config/shell/bin/lib/verify-launch.sh`). See [arch-design/VERIFICATION.md](../../arch-design/VERIFICATION.md).

## When to run

- Target project (or **this shell repo** as dogfood/stress test) needs a verification dashboard
- `AGENTS.md` / README lists verify commands not reflected in panes
- Stack changed (new `pnpm` scripts, Rust crate, CI jobs)
- User asks for "verification cockpit", "av layout", or "mission control"

## Workflow

Copy this checklist and track progress:

```
- [ ] 1. Discover verification commands
- [ ] 2. Classify launch tiers
- [ ] 3. Design pane layout
- [ ] 4. Write .agents/verification/*
- [ ] 5. Symlink .cursor/verify
- [ ] 6. Optional: AGENTS.md cockpit row
```

### 1. Discover

Read in order (stop when you have enough signal):

| Source | Look for |
|--------|----------|
| `AGENTS.md` | verify-before-done, post-change commands, stability hotspots |
| `docs/SETUP.md`, `README.md` | build/test/lint commands |
| `package.json` scripts | `test`, `build`, `lint`, `dev` |
| `Makefile`, `Cargo.toml`, `justfile` | check/test targets |
| `.github/workflows/*` | CI verify steps |
| `.agents/skills/*/SKILL.md` | domain-specific verify |

### 2. Classify tiers

| Tier | Auto on `av`? | Examples |
|------|---------------|----------|
| `monitor` | yes | `lazygit`, empty console — **omit** `yazi`/`btop` unless they surface verify failures |
| `watch` | yes | `pnpm test --watch`, `cargo watch -x check`, `vitest --watch` |
| `verify` | confirm `[y/N]` | `pnpm test`, `cargo test`, `pnpm build`, `tsc --noEmit` |
| `mutate` | blocked unless `av --launch-mutate` + type `YES` | `pnpm install`, migrations, deploy, format-all |

**Rule:** if it writes deps, data, or project structure → `mutate`. If it only reads/compiles/tests → `verify` or `watch`.

Set `risk_profile` in manifest: `low` | `medium` | `high` (from AGENTS.md stability contracts).

### 3. Design layout (two-pass, golden ratio)

**Mandatory:** every pane answers *what failure does this surface?* If it does not, omit it. Prefer four high-signal panes over six decorative ones.

**Golden ratio:** all splits use φ ≈ 1.618 → **62% major / 38% minor** (`bin/lib/verify-layout.sh`). Nest splits so higher priority panes accumulate major shares.

#### Pass 1 — priority → area

Rank panes `priority: 1` (highest) through `N`. Allocate area in golden proportions:

| Prio | Typical pane | Column / band |
|------|--------------|---------------|
| 1 | Primary watcher (test/lint/health watch) | Insight column — major width (62%) |
| 2 | CMD console | Insight column — minor height top (38%) |
| 3 | GIT (lazygit) | Right column — minor width (38%), full height |
| 4 | Verify-tier one-shot | Insight column — minor height bottom |
| 5+ | Second watcher / domain verify | Only if distinct failure signal; split insight stack again |

Use `verify_layout_build_golden_grid` from `verify-layout.sh` for the default 4-pane skeleton.

#### Pass 2 — context → arrangement

Adjust using `space_profile` per pane (manifest + `reference.md`):

| Profile | Output shape | Space rule |
|---------|--------------|------------|
| `scroll` | streaming logs, test output | Largest vertical band in insight column |
| `interactive` | short commands, `agent_scan` | Compact top band (38% height) |
| `tui-side` | lazygit, tig | Narrow right column (38% width) |
| `confirm-burst` | build/test on demand | Small bottom band; confirm before run |
| `omit` | btop, yazi (default) | **Do not include** in verify window |

#### Default golden grid

```
+---------------------------+------------+
| CMD (interactive, 38% h)  |            |
|---------------------------|  GIT 38%   |
| WATCH (scroll, major)     |  lazygit   |
|---------------------------|            |
| VERIFY (confirm, minor)   |            |
+---------------------------+------------+
     insight column 62%
```

- **CMD** — `tier: monitor`, no command — `agent_scan`, `gdf`, `vf`
- **WATCH** — highest-priority watcher for this stack
- **VERIFY** — full-suite or build; confirm in pane
- Optional second window `verify-risk` only when many amber/red commands would crowd one window

#### Value audit (before shipping)

```
- [ ] Each pane has `value:` in manifest — one concrete failure mode
- [ ] No system monitors (btop) unless debugging perf during verify
- [ ] No file browser unless verify workflow inspects files
- [ ] No duplicate signals (two panes showing same test output)
- [ ] WATCH pane shows live output without manual refresh
```

### 4. Write artifacts

Create under `.agents/verification/`:

| File | Purpose |
|------|---------|
| `manifest.yaml` | Machine-readable pane map |
| `tmux-layout.sh` | Executable layout (chmod +x) |
| `tmux-theme.conf` | Optional project theme overrides |
| `README.md` | Human pane legend |

Use templates from [templates/](templates/) in this skill directory. Fill `PROJECT`, `RISK`, and `PANES` from discovery.

**`tmux-layout.sh` contract:**

- Args: `[directory]` (default `.`)
- Must run inside tmux
- Sets `@workflow_dir`, `@workflow_mode verify`
- Idempotent: `verify_layout_ok` — recreate when CMD missing or placeholder panes (FILES/SYS/INSIGHT/VERIFY)
- Resolves project layout by walking up from cwd for `.agents/verification/tmux-layout.sh`
- Sources `verify-launch.sh` + `verify-layout.sh`
- Calls `verify_layout_build_golden_grid`, `verify_apply_theme`, `verify_launch_pane`, `verify_maybe_rescan`
- Ends with `tmux select-pane` on console

### 5. Symlink

```bash
mkdir -p .cursor
ln -sfn ../.agents/verification .cursor/verify
```

### 6. Optional AGENTS.md row

If no cockpit section exists, add under setup/verify:

```markdown
| Verification cockpit | `.agents/verification/README.md` — run `av` in tmux after agent work |
```

## Test

In Ghostty + tmux (not Cursor integrated terminal):

```bash
t && z <project>
av                  # project layout; watchers auto-start
av --scan           # + agent_scan in console
av --launch-mutate  # allow mutate-tier confirms
av --generic        # fallback to generic 4-pane cockpit
```

## Reference

- Manifest schema: [reference.md](reference.md)
- Starter templates: [templates/](templates/) — copy into **target project** `.agents/verification/`
- Shell integration (runtime): [arch-design/VERIFICATION.md](../../arch-design/VERIFICATION.md)
- Skills index: [skills/README.md](../README.md)
