---
name: verification-cockpit
description: >-
  Generates project-specific tmux cockpits for shellyxz ab/av/at workflows.
  Reads AGENTS.md and stack scripts; writes .agents/verification/ (tmux-layout,
  cockpit.yaml, legacy manifests). Use when setting up or regenerating av/at
  project config, mission-control panes, or after stack/verify-command changes.
---

# Verification Cockpit Generator

**Portable skill** — install from the [agent skills library](https://github.com/p10ns11y/skills) (`verification-cockpit/`). Primary use: generate layouts **in app/library repos** you are verifying. This shell repo dogfoods the same skill under `.agents/skills/verification-cockpit/`.

**Output:** `.agents/verification/` in the **workspace you are verifying**. Host `av` / `at` / `ab` consume that tree (see contract below).

## Host vs project (extensibility contract)

| Alias | Window | Who configures it | Runtime source of truth |
|-------|--------|-------------------|-------------------------|
| **av** | `verify` | **Project** `.agents/verification/` | Executable `tmux-layout.sh` (YAML panes are the agent map; script launches panes) |
| **at** | `test` | **Project** `.agents/verification/` | `cockpit.yaml` → `cockpits.test` (or legacy `tests.yaml`) via `run-project-tests.sh` |
| **ab** | `build` | **Host** personal env | `SHELL_AGENT_BUILD_CMD` / `SHELL_AGENT_BUILD_CONTINUE_CMD` — not project YAML yet |

**Generic fallback:** if no project `tmux-layout.sh`, `av --generic` (or missing layout) uses the host golden empty grid and tells you to add a project layout via this skill.

**Libs (SN-4a):** layouts source  
`${SHELL_VERIFICATION_LIB:-$HOME/.config/shell/plugins/verification/lib}/verify-{launch,layout}.sh`  
(`SHELL_VERIFICATION_*` is set by shell `core/env.sh`). Do **not** use the obsolete `~/.config/shell/bin/lib/` path.

**Custom layout binaries (optional):** for project-specific helpers beyond the standard cockpit, add `PWD/bin/...` via repo [`.path.contract`](../../../.path.contract.example) (`phase:project`) + direnv (`bin/path-contract-project.sh`). Baseline `av` still delegates to `.agents/verification/tmux-layout.sh` — path contract is an escape hatch, not a replacement.

## Adopt in a target project

Copy or symlink this skill into the **project you are verifying**:

```bash
SKILLS_ROOT=~/skills   # or wherever you cloned the skills library
mkdir -p /path/to/my-app/.cursor/skills
ln -sfn "$SKILLS_ROOT/verification-cockpit" /path/to/my-app/.cursor/skills/verification-cockpit
# or: cp -a "$SKILLS_ROOT/verification-cockpit" /path/to/my-app/.cursor/skills/
```

Open that project in Cursor, then invoke the skill. It generates `.agents/verification/*` **in that repo** — tweak `cockpit.yaml` + `tmux-layout.sh` for that stack.

**Prerequisite:** host shellyxz with verification plugin (`plugins/verification/`). See [shell-av-workflow overlay](../../examples/overlays/shell-av-workflow.md) in the skills library when installed from `p10ns11y/skills`.

## When to run

- Target project (or **this shell repo** as a local stress test) needs a verification dashboard
- `AGENTS.md` / README lists verify commands not reflected in panes
- Stack changed (new `pnpm` scripts, Rust crate, CI jobs)
- User asks for "verification cockpit", "av layout", "at tests", or "mission control"

## Workflow

Copy this checklist and track progress:

```
- [ ] 1. Discover verification + test commands
- [ ] 2. Classify launch tiers (av panes)
- [ ] 3. Design pane layout
- [ ] 4. Write .agents/verification/* (cockpit.yaml + tmux-layout.sh)
- [ ] 5. Symlink .cursor/verify
- [ ] 6. Optional: AGENTS.md cockpit row
- [ ] 7. Dogfood: av + at in tmux (ab = host env check)
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

Split discoveries into **av panes** (live watch / confirm / git) vs **at tests** (priority one-shots for the test window).

### 2. Classify tiers

| Tier | Auto on `av`? | Examples |
|------|---------------|----------|
| `monitor` | yes | `lazygit`, empty console — **omit** `yazi`/`btop` unless they surface verify failures |
| `watch` | yes | `pnpm test --watch`, `cargo watch -x check`, `vitest --watch` |
| `verify` | confirm `[y/N]` | `pnpm test`, `cargo test`, `pnpm build`, `tsc --noEmit` |
| `mutate` | blocked unless `av --launch-mutate` + type `YES` | `pnpm install`, migrations, deploy, format-all |

**Rule:** if it writes deps, data, or project structure → `mutate`. If it only reads/compiles/tests → `verify` or `watch`.

Set `risk_profile` in cockpit/manifest: `low` | `medium` | `high` (from AGENTS.md stability contracts).

### 3. Design layout (two-pass, golden ratio)

**Mandatory:** every pane answers *what failure does this surface?* If it does not, omit it. Prefer four high-signal panes over six decorative ones.

**Golden ratio:** all splits use φ ≈ 1.618 → **62% major / 38% minor** (`plugins/verification/lib/verify-layout.sh`). Nest splits so higher priority panes accumulate major shares.

#### Pass 1 — priority → area

Rank panes `priority: 1` (highest) through `N`. Allocate area in golden proportions:

| Prio | Typical pane | Column / band |
|------|--------------|---------------|
| 1 | Primary watcher (test/lint/health watch) | Ops column — major height in right stack |
| 2 | CMD console | Ops column — minor height bottom-right (default focus) |
| 3 | GIT (lazygit) | Left column — major width (62%), full height |
| 4 | Verify-tier one-shot | Ops column — minor height top-right |
| 5+ | Second watcher / domain verify | Only if distinct failure signal; split ops stack again |

Use `verify_layout_build_golden_grid` from `verify-layout.sh` for the default 4-pane skeleton.

#### Pass 2 — context → arrangement

Adjust using `space_profile` per pane (manifest + `reference.md`):

| Profile | Output shape | Space rule |
|---------|--------------|------------|
| `scroll` | streaming logs, test output | Largest vertical band in ops stack (right center) |
| `interactive` | short commands, `agent_scan` | Compact bottom band (38% height), bottom-right |
| `tui-side` | lazygit, tig | Major left column (62% width), full height |
| `confirm-burst` | build/test on demand | Small bottom band; confirm before run |
| `omit` | btop, yazi (default) | **Do not include** in verify window |

#### Default golden grid

```
+----------------------------+------------------+
|                            | VERIFY (minor)   |
|  GIT (tui-side, 62% w)     |------------------|
|  lazygit full height       | WATCH (scroll)   |
|                            |------------------|
|                            | CMD (interactive)|
+----------------------------+------------------+
     git column 62%              ops column 38%
```

- **CMD** — `tier: monitor`, no command — `agent_scan`, `gdf`, `vf`
- **WATCH** — highest-priority watcher for this stack
- **VERIFY** — full-suite or build; confirm in pane
- Optional second window `verify-risk` only when many amber/red commands would crowd one window

#### Value audit (before shipping)

```
- [ ] Each pane has `value:` in cockpit/manifest — one concrete failure mode
- [ ] No system monitors (btop) unless debugging perf during verify
- [ ] No file browser unless verify workflow inspects files
- [ ] No duplicate signals (two panes showing same test output)
- [ ] WATCH pane shows live output without manual refresh
- [ ] cockpits.test priorities match what `at` should run first
```

### 4. Write artifacts

Create under `.agents/verification/`:

| File | Purpose |
|------|---------|
| `cockpit.yaml` | **Preferred** unified verify + test map (`cockpits.verify`, `cockpits.test`) |
| `manifest.yaml` | Legacy verify pane map (still supported; keep in sync with `tmux-layout.sh`) |
| `tests.yaml` | Legacy test runners (still supported; prefer `cockpits.test`) |
| `tmux-layout.sh` | Executable **av** layout (chmod +x) — must match verify panes |
| `tmux-theme.conf` | Optional project theme overrides |
| `README.md` | Human pane legend |

Use templates from [templates/](templates/) in this skill directory. Fill `PROJECT_NAME`, risk, pane commands, and `cockpits.test` from discovery.

**Keep YAML and script aligned:** edit `cockpit.yaml` (and legacy manifests) for agents/`at`; mirror the same commands into `tmux-layout.sh` so `av` launches what the map describes. Runtime does **not** yet auto-render verify panes from YAML.

**`tmux-layout.sh` contract:**

- Args: `[directory]` (default `.`)
- Must run inside tmux (`$TMUX` set)
- Sets `@workflow_dir`, `@workflow_mode verify`
- Idempotent: `verify_layout_ok` — recreate when CMD missing or placeholder panes (FILES/SYS/INSIGHT/VERIFY)
- Resolves project layout by walking up from cwd for `.agents/verification/tmux-layout.sh`
- Sources `verify-launch.sh` + `verify-layout.sh` via `SHELL_VERIFICATION_LIB`
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
| Verification cockpit | `.agents/verification/README.md` — `av` / `at` in tmux after agent work |
```

## Test

In tmux (Ghostty, Cursor agent viewport, or any terminal with `$TMUX` set):

```bash
t && z <project>
av                  # project layout; watchers auto-start
av --scan           # + agent_scan in console
av --launch-mutate  # allow mutate-tier confirms
av --generic        # fallback to generic 4-pane cockpit
at                  # priority tests from cockpit.yaml / tests.yaml
ab                  # build window (requires SHELL_AGENT_BUILD_CMD on host)
```

## Reference

- Manifest / cockpit schema: [reference.md](reference.md)
- Starter templates: [templates/](templates/) — copy into **target project** `.agents/verification/`
- Host plugin: `plugins/verification/README.md` (this shell repo)
- Runtime integration overlay: [shell-av-workflow](../../examples/overlays/shell-av-workflow.md) (skills library)
