# Overlay — shellyxz shell kernel + verification bridge

**Type:** shell-kernel · **Full doc:** [coming-next.md](../../../arch-design/coming-next.md) · **Boundary:** [PLUGIN.md](../../../PLUGIN.md)

## Fused abstraction

Ship computer (kernel: PATH, migrate, recover) + command bridge (ab/av/at, tmux, cockpit.yaml) + hull bays (PLUGIN) → host-agnostic human verification before launch.

## Mission (§0)

Punch through platform shifts with portable PATH kernel + evolving verification bridge — not betting on tmux forever, betting on human-in-the-loop forever.

## Thrive north star (§0b, 2036)

| Role | Wins because |
|------|----------------|
| Kernel | POSIX PATH outlives agent brands |
| Bridge | Faster agents → more audit need |
| cockpit.yaml | Same manifest → tmux, IDE, MCP, CI |
| direnv | Per-planet ops; ship-wide = path.contract |

## Scorecard snapshot (post PR #6)

| Area | Grade | Evidence |
|------|-------|----------|
| path.contract v2 + overlay | A | `core/path-resolve.sh`, `local/path.contract` |
| tool pins + shadow report | A | `core/tool.contract`, verify |
| PLUGIN boundary | A | `PLUGIN.md`, no grok in kernel |
| Agent build env | A | `SHELL_AGENT_BUILD_CMD`, `local/personal.sh` |
| Overlay invariant | A | `bin/check-shell.sh` |
| plugins/ physical split | C | Still monorepo tree |
| direnv phase:project | C | Not wired |
| MCP export | D | Future SN-7 |

## Open SN priority (do not reorder without reason)

1. **SN-1** Dogfood gate — `av` here, no new code
2. **SN-2** direnv `phase:project` fragment in `.envrc`
3. **SN-3** Agent strict PATH (plugin only)
4. **SN-4** `plugins/verification/` modular split
5. **SN-5** Cockpit simplify — **keep** navigators, keymap TSV, SOC themes, golden-ratio tiers
6. **SN-7** MCP surface for manifest (thrive bet)
7. **SN-6** Doc triage 18→3 + skills collapse

## Guardrails (§6)

| Refuse | Build toward 2036 |
|--------|-------------------|
| Hardcode vendor CLIs in kernel | `SHELL_AGENT_BUILD_CMD` pattern |
| Machine paths in `core/path.contract` | `local/path.contract` overlay |
| "Cockpit may die" framing | Bridge evolves; manifest is spacecraft |
| Global direnv replacing path.contract | Per-repo fragments only |

## Key paths (§12 mindmap seed)

`core/path.contract` · `core/path-resolve.sh` · `local/path.contract` · `bin/check-shell.sh` · `bin/agent-build-layout.sh` · `PLUGIN.md` · `arch-design/VERIFICATION.md` · `.agents/verification/`

## Verify commands

```bash
bin/path-contract.test.sh
bin/check-shell.sh
bin/check-template-sync.sh
av   # dogfood SN-1
```

**Expand full doc for:** gantt dates, monitoring §10, done log §11, card file tables.
