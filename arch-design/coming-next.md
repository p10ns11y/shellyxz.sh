# Immediate next actions (from [test-of-travelled-time-from-future.md](test-of-travelled-time-from-future.md))

1. **Create `local/path.contract`** — move all personal `prepend:` lines out of `core/path.contract` (one PR, pure win).
2. **Add `SHELL_AGENT_BUILD_CMD`** — remove hardcoded `grok` from build layout (decouples agent vendor).
3. **Write `arch-design/SPLIT.md`** — kernel vs plugin boundary; even if you don't split repos yet, the doc forces honesty. *(Lightweight version shipped: [`PLUGIN.md`](../PLUGIN.md) at repo root.)*

---

*Last updated: 2026-06-18*
