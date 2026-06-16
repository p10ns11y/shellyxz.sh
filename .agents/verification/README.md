# Verification cockpit — shell (dogfood)

Stress-test layout for the `verification-cockpit` skill. This repo verifies **shell config**, not an app — panes map to `check-shell.sh` and template drift checks.

## Panes

| Title | Tier | Command | Auto-launch |
|-------|------|---------|-------------|
| CMD | monitor | (console) | — |
| GIT | monitor | lazygit | yes |
| CHECK:watch | watch | `watch -n 15 check-shell.sh` | yes |
| SYNC | verify | `check-template-sync.sh` | confirm `[y/N]` |
| FILES | monitor | yazi | yes |
| SYS | monitor | btop | yes |

## Mutate tier (manual)

`bin/migrate.sh --sync-rc` — use `av --launch-mutate` only when you intend to refresh managed rc files.

## Commands

```bash
av                  # this layout (delegates from agent-verify-layout.sh)
av --scan           # + agent_scan in CMD
av --generic        # skip dogfood layout
```

## Regenerate

Re-run `verification-cockpit` skill when verify workflow changes. Reference: `.agents/skills/verification-cockpit/`.
