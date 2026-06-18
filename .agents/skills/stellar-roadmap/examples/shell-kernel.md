# Overlay — shellyxz shell kernel + verification bridge

**Type:** shell-kernel · **Current state:** [architecture.md](../../../arch-design/architecture.md) · **Backlog:** [coming-next.md](../../../arch-design/coming-next.md) · **Boundary:** [PLUGIN.md](../../../PLUGIN.md)

## Fused abstraction

Ship computer (kernel: PATH, migrate, recover) + command bridge (ab/av/at, tmux, cockpit-mcp, cockpit.yaml) + hull bays (PLUGIN) → host-agnostic human verification before launch.

## Scorecard snapshot (post PR #8)

| Area | Grade | Evidence |
|------|-------|----------|
| path.contract + project phase | A | PR #6 + #8, `path-contract-project.sh` |
| PLUGIN boundary | B+ | `PLUGIN.md`; SN-4 physical split open |
| Agent strict PATH | B+ | `ab --strict`, `tool.contract` |
| Cockpit + MCP CLI | A- | `cockpit-mcp.sh`, tmux layouts |
| sh test discovery | B+ | `parse-project-tests-discover.sh` |
| Per-project tmux (`ts`) | — | SN-TS next |

## Open SN priority

1. **SN-TS** Per-project tmux `ts`
2. **SN-4** `plugins/verification/` modular split

## Key paths

`arch-design/architecture.md` · `core/path-resolve.sh` · `bin/cockpit-mcp.sh` · `planned-features/done/`

## Verify

```bash
bin/check-shell.sh
bin/cockpit-mcp.sh verify .
```

**Expand full doc for:** shipped cards → [planned-features/done/](../../../planned-features/done/).
