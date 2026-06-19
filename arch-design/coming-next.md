# Coming next — shellyxz shell

**Backlog only** — short. **Current architecture:** [architecture.md](architecture.md) · **Shipped epics:** [../planned-features/done/](../planned-features/done/)

*Last updated: 2026-06-19 (SN-TS + SN-8 on branch sn-ts-sn-8)*

**Next:** [SN-4](#sn-4--modular-pluginsverification) only.

---

## Next up

### SN-4 · Modular `plugins/verification/`

**Problem:** One repo, two bays — clarify for forks; version kernel and cockpit independently.

| Phase | Work |
|-------|------|
| 4a | `plugins/verification/` + shims in `bin/` |
| 4b | Optional separate repo; cockpit installs beside kernel |

```mermaid
flowchart LR
  K[kernel] <-->|MCP manifest| C[verification cockpit]
```

Detail when scheduled: [sprint archive template](../planned-features/done/sprint-jun-2026-pr8.md).

---

## Recently done (last 10)

| # | Item | PR / commit |
|---|------|-------------|
| 1 | SN-TS per-project tmux `ts` | branch `sn-ts-sn-8` |
| 2 | SN-8 unified `discover_tests` JSON + allowlist | branch `sn-ts-sn-8` |
| 3 | PR #8 merge close-out (strict PATH docs + backlog) | [#8](https://github.com/p10ns11y/shellyxz.sh/pull/8) `876abf0` |
| 4 | capture-shell-init false-positive fix | #8 `c0496d9` |
| 5 | Mermaid fix in shell.md | #8 `0d204d2` |
| 6 | Doc split architecture / planned-features | #8 `4bfedc6` |
| 7 | SN-7 cockpit-mcp headless verbs | #8 `c589765` |
| 8 | SN-5 sh test discovery | #8 `50f4e52` |
| 9 | SN-3 agent strict PATH | #8 `2c76358` |
| 10 | SN-2 direnv `phase:project` | #8 `afb4fc0` |

Full blueprint cards + diagrams: [planned-features/done/](../planned-features/done/).

---

## Monitoring

| Signal | Healthy | Invest when |
|--------|---------|-------------|
| `path_contract_verify` failures | Rare | Spike → `capture-shell-init` |
| Agent vs kernel commits | Both grow | Cockpit only → SN-TS / MCP depth |
| IDE + tmux both in use | Hybrid | Expected — bridge hosts multiply |

---

## References

| Doc | Use |
|-----|-----|
| [architecture.md](architecture.md) | **Current state** (update on structural merges) |
| [shell.md](shell.md) | PATH / load order detail |
| [VERIFICATION.md](VERIFICATION.md) | ab/av/at / cockpit-mcp |
| [PLUGIN.md](../PLUGIN.md) | Kernel boundary |
| [stellar-roadmap skill](../.agents/skills/stellar-roadmap/SKILL.md) | Backlog doc format |

*Plain rule: update `architecture.md` when shape changes; append `planned-features/done/` when an epic ships; keep this file short.*
