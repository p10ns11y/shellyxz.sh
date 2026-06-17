# manifest.yaml schema

## Top-level fields

| Field | Required | Description |
|-------|----------|-------------|
| `project` | yes | Short project name (status bar) |
| `risk_profile` | yes | `low` \| `medium` \| `high` — shown as `@verify_risk` |
| `layout` | no | `golden-4` (default) — φ nested 62% / 38% |
| `phi_major` | no | Major split % (default `62`) |
| `phi_minor` | no | Minor split % (default `38`) |
| `panes` | yes | Ordered list of pane definitions |

## Pane fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Stable id (`console`, `fe-watch`, `rust-test`) |
| `title` | yes | Pane title (`CMD`, `FE:watch`, `RUST:test`) |
| `tier` | yes | `monitor` \| `watch` \| `verify` \| `mutate` |
| `priority` | yes | `1` = highest — drives pass-1 area allocation |
| `space_profile` | yes | Pass-2 split hint (see below) |
| `value` | yes | One-line: what failure this pane surfaces |
| `cwd` | no | Relative cwd from repo root (default `.`) |
| `command` | no | Shell command; omit for empty console |
| `tool` | no | Binary guard (`lazygit`) — skip launch if missing |

## space_profile (pass 2)

| Profile | Tool examples | Golden placement |
|---------|---------------|------------------|
| `scroll` | test watch, lint watch, health checks | Major height in insight column |
| `interactive` | CMD, short REPL | Minor height, top of insight column |
| `tui-side` | lazygit, tig | Minor width, full-height right column |
| `confirm-burst` | test, build, tsc | Minor height, bottom of insight stack |
| `omit` | yazi, btop during verify | Do not include — low verification signal |

## Golden grid (default template)

After `verify_layout_build_golden_grid` (see `bin/lib/verify-layout.sh`):

| Index | Role | Approx area |
|-------|------|-------------|
| 0 | git | 62% w — full-height left |
| 1 | verify / confirm | 38% h × 38% w — top-right (φ minor) |
| 2 | watch / insight | φ major of right stack — center-right |
| 3 | CMD | φ minor of right stack — bottom-right (default focus) |

tmux reindexes panes during splits; assign GIT to index 0 after build. Never run `select-layout main-vertical` after build — it destroys φ geometry.

## Tier behavior

| Tier | `av` behavior | Confirm |
|------|---------------|---------|
| monitor | immediate launch | none |
| watch | immediate launch | none |
| verify | launch `verify-pane-launch.sh verify` | `[y/N]` |
| mutate | blocked message | `av --launch-mutate` + type `YES` |

## Value audit (required before shipping)

Reject any pane that does not surface a **concrete verification failure**. Common omissions:

- `btop` / `htop` — system metrics, not project correctness
- `yazi` — unless verify workflow is file-inspection heavy
- Duplicate watchers showing the same signal
- Generic placeholder panes (`INSIGHT`, `VERIFY` titles) — recreate layout via `av`

`agent-verify-layout.sh` resolves cwd via `verify_workflow_root` (layout → git → cwd). After `reload`, run `verify_workflow_root`; script: `~/.config/shell/bin/verify-workflow-root.sh`.

## Example

```yaml
project: collab-finder
risk_profile: high
layout: golden-4
panes:
  - id: fe-watch
    title: FE:watch
    tier: watch
    priority: 1
    space_profile: scroll
    command: pnpm test --watch
    value: Frontend regressions
  - id: console
    title: CMD
    tier: monitor
    priority: 2
    space_profile: interactive
    value: agent_scan
  - id: git
    title: GIT
    tier: monitor
    priority: 3
    space_profile: tui-side
    command: lazygit
    tool: lazygit
    value: Uncommitted agent changes
  - id: rust-test
    title: RUST:test
    tier: verify
    priority: 4
    space_profile: confirm-burst
    cwd: src-tauri
    command: cargo test
    value: Rust integration failures
```
