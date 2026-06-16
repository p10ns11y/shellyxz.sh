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
| `monitor` | yes | `lazygit`, `yazi`, `btop`, empty console |
| `watch` | yes | `pnpm test --watch`, `cargo watch -x check`, `vitest --watch` |
| `verify` | confirm `[y/N]` | `pnpm test`, `cargo test`, `pnpm build`, `tsc --noEmit` |
| `mutate` | blocked unless `av --launch-mutate` + type `YES` | `pnpm install`, migrations, deploy, format-all |

**Rule:** if it writes deps, data, or project structure → `mutate`. If it only reads/compiles/tests → `verify` or `watch`.

Set `risk_profile` in manifest: `low` | `medium` | `high` (from AGENTS.md stability contracts).

### 3. Design layout

Default: one window `verify`, idempotent (select if exists, create if not).

```
+--------------------+---------------------+
|  CMD (console)     |  GIT (lazygit)      |
+--------------------+---------------------+
|  watch pane(s)     |  watch pane(s)      |
+--------------------+---------------------+
|  FILES (yazi)      |  SYS (btop)         |
+--------------------+---------------------+
```

- **console** pane: `tier: monitor`, no command — for `agent_scan`, `gdf`, `vf`
- Add watch panes per stack (FE, Rust, API, etc.)
- Put full-suite tests in `verify` tier (confirm in pane)
- Optional second window `verify-risk` only when many amber/red commands would crowd one window

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
- Idempotent: if window `verify` exists → `select-window`, skip pane creation
- Sources `~/.config/shell/bin/lib/verify-launch.sh`
- Calls `verify_apply_theme`, `verify_launch_pane`, `verify_maybe_rescan`
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
