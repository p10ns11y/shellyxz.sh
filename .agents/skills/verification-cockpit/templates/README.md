# Verification cockpit — PROJECT_NAME

Mission-control tmux layout for post-agent verification in **this project**. Open with `av` in Ghostty + tmux.

Generated from `~/.config/shell/.agents/skills/verification-cockpit/` — edit freely for this repo's stack.

## Panes

| Title | Tier | Command | Auto-launch |
|-------|------|---------|-------------|
| CMD | monitor | (console) | — |
| GIT | monitor | lazygit | yes |
| WATCH | watch | pnpm test --watch | yes |
| FILES | monitor | yazi | yes |
| SYS | monitor | btop | yes |

## Commands

```bash
av                  # open cockpit; watchers start immediately
av --scan           # + agent_scan in CMD pane
av --launch-mutate  # allow mutate-tier panes (if any)
av --generic        # skip this layout; use generic cockpit
```

## Regenerate

Re-run the `verification-cockpit` skill in this project's workspace when `AGENTS.md` verify steps change. Skill source: `~/.config/shell/.agents/skills/verification-cockpit/`.
