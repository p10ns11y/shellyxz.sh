# manifest.yaml schema

## Top-level fields

| Field | Required | Description |
|-------|----------|-------------|
| `project` | yes | Short project name (status bar) |
| `risk_profile` | yes | `low` \| `medium` \| `high` — shown as `@verify_risk` |
| `panes` | yes | Ordered list of pane definitions |

## Pane fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Stable id (`console`, `fe-watch`, `rust-test`) |
| `title` | yes | Pane title (`CMD`, `FE:watch`, `RUST:test`) |
| `tier` | yes | `monitor` \| `watch` \| `verify` \| `mutate` |
| `cwd` | no | Relative cwd from repo root (default `.`) |
| `command` | no | Shell command; omit for empty console |
| `tool` | no | Binary guard (`lazygit`, `yazi`, `btop`) — skip if missing |

## Layout mapping (default template)

Pane index order after splits:

| Index | Typical id | Split |
|-------|------------|-------|
| 0 | console | new-window |
| 1 | git | split -h 42% |
| 2 | watch-1 | split -v 45% on 0 |
| 3 | watch-2 | split -h 50% on 2 (optional) |
| 4 | files | split -v 40% on 2 |
| 5 | sys | split -v 35% on 4 |

Adjust splits in `tmux-layout.sh` when pane count differs.

## Tier behavior

| Tier | `av` behavior | Confirm |
|------|---------------|---------|
| monitor | immediate launch | none |
| watch | immediate launch | none |
| verify | launch `verify-pane-launch.sh verify` | `[y/N]` |
| mutate | blocked message | `av --launch-mutate` + type `YES` |

## Theme tokens

SOC theme from `~/.config/shell/tmux.verify-soc-theme.conf.ex`:

- Amber (`colour214`) — active verify, warnings
- Red (`colour196`) — mutate prompts
- `brightblack` — borders

Project `tmux-theme.conf` can set extra session options after sourcing SOC base.

## Example

```yaml
project: collab-finder
risk_profile: high
panes:
  - id: console
    title: CMD
    tier: monitor
  - id: git
    title: GIT
    tier: monitor
    command: lazygit
    tool: lazygit
  - id: fe-watch
    title: FE:watch
    tier: watch
    cwd: .
    command: pnpm test --watch
  - id: rust-watch
    title: RUST:check
    tier: watch
    cwd: src-tauri
    command: cargo watch -x check
  - id: rust-test
    title: RUST:test
    tier: verify
    cwd: src-tauri
    command: cargo test
  - id: files
    title: FILES
    tier: monitor
    command: yazi
    tool: yazi
  - id: sys
    title: SYS
    tier: monitor
    command: btop
    tool: btop
```
