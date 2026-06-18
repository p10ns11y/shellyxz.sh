# Coming next — shellyxz shell

**Backlog only** — short. **Current architecture:** [architecture.md](architecture.md) · **Shipped epics:** [../planned-features/done/](../planned-features/done/)

*Last updated: 2026-06-18*

---

## Next up

### SN-TS · Per-project tmux session (`ts`)

**Problem:** Omarchy `t` → one session (`Work`). Multi-repo work hijacks shared `build`/`verify` windows.

| File | Work |
|------|------|
| `core/functions.sh` | `ts()` attach-or-create from git basename |
| `arch-design/VERIFICATION.md` | Document `t` vs `ts` |
| `local/personal.sh` | Optional alias |

**Done when:** `ts` from repo A and B → two sessions; isolated `ab`/`av`/`at`.

**Deferred:** `tls` — only if `tmux ls` insufficient.

---

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
| 1 | SN-7 cockpit-mcp headless verbs | [#8](https://github.com/p10ns11y/shellyxz.sh/pull/8) `c589765` |
| 2 | SN-5 sh test discovery | #8 `50f4e52` |
| 3 | `which` aliases/functions fix | #8 `1891f57` |
| 4 | SN-3 agent strict PATH | #8 `2c76358` |
| 5 | SN-6 doc triage + omarchy overlay | #8 `f7dafb1` |
| 6 | SN-2 direnv `phase:project` | #8 `afb4fc0` |
| 7 | SN-1 dogfood gate | #8 (manual) |
| 8 | PLUGIN.md + overlay invariant | [#6](https://github.com/p10ns11y/shellyxz.sh/pull/6) `6b24738` |
| 9 | PATH contract v2 + local overlay | #6 `d52e40e` |
| 10 | check-shell overlay order guard | #6 `76b8073` |

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
