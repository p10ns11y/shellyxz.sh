# Coming next — shellyxz shell

**Backlog only** — short. **Current architecture:** [architecture.md](architecture.md) · **Shipped epics:** [../planned-features/done/](../planned-features/done/)

*Last updated: 2026-06-19 (PR #9 SN-TS + SN-8)*

**Next:** [SN-4](#sn-4--modular-pluginsverification) only. **Shipped:** [sn-ts-sn8-pr9.md](../planned-features/done/sn-ts-sn8-pr9.md).

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
| 1 | SN-TS + SN-8 (`ts`, discover_tests, ab --strict fix) | [#9](https://github.com/p10ns11y/shellyxz.sh/pull/9) |
| 2 | PR #8 merge close-out (strict PATH docs + backlog) | [#8](https://github.com/p10ns11y/shellyxz.sh/pull/8) `876abf0` |
| 3 | capture-shell-init false-positive fix | #8 `c0496d9` |
| 4 | Mermaid fix in shell.md | #8 `0d204d2` |
| 5 | Doc split architecture / planned-features | #8 `4bfedc6` |
| 6 | SN-7 cockpit-mcp headless verbs | #8 `c589765` |
| 7 | SN-5 sh test discovery | #8 `50f4e52` |
| 8 | SN-3 agent strict PATH | #8 `2c76358` |
| 9 | SN-2 direnv `phase:project` | #8 `afb4fc0` |
| 10 | PATH contract v2 + overlay | [#6](https://github.com/p10ns11y/shellyxz.sh/pull/6) |

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
