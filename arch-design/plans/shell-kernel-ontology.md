# Shell kernel ontology — plan

**Status:** SN-O0 shipped (Phase 1 graph). **Live graph:** [`.agents/ontology/`](../.agents/ontology/INDEX.md)

*Last updated: 2026-06-21*

---

## Mission

Machine-readable domain graph so agents load **addressable** semantics (kernel vs plugin, PATH layers, public API, invariants) instead of re-inferring from scattered prose each session. Pragmatic YAML/JSON now; JSON-LD export later.

---

## What shipped (SN-O0)

| Asset | Path |
|-------|------|
| Schema | `.agents/ontology/ontology.schema.json` |
| Graph | `.agents/ontology/shell-kernel.graph.yaml` |
| Fusion cache | `.agents/ontology/fusion-state.json` |
| Index | `.agents/ontology/INDEX.md` |

**Phase 1 scope:** `PathContractDomain`, `KernelPluginBoundary`, `LoadOrder`, lexicon links, invariants, public hooks. No verification file paths yet (SN-O1 after SN-4a).

---

## Sequencing vs SN-4

| Order | Item | Notes |
|-------|------|-------|
| 1 | **SN-O0** (this) | Boundary + PATH graph before physical split |
| 2 | **SN-4** | `plugins/verification/` + bin shims; use [INDEX.md](../.agents/ontology/INDEX.md) split checklist |
| 3 | **SN-O1** | VerificationBridge nodes, skill/rule, drift gate |

Ontology **helps** SN-4: `mustNot` / `may_assume` / `PublicHook` nodes route file moves. Do not wait for SN-4 to model boundary semantics.

---

## Remaining phases

### SN-O1 Phase 2 — Verification bridge (after SN-4a)

- Nodes: `ab`, `av`, `at`, `cockpit-mcp`, `cockpit.yaml`, `SHELL_AGENT_STRICT_PATH`
- Remap plugin `Artifact` paths to `plugins/verification/`
- `meta.layout` → `plugins_verification`

### SN-O1 Phase 3 — Skill + rule

- `.agents/skills/shell-kernel-ontology/SKILL.md`
- `.cursor/rules/ontology-router.mdc` (thin subgraph router)
- ai-optimization + fusion-sage overlays

### SN-O1 Phase 4 — Drift gate

- `bin/extract-ontology-facts.sh` → `shell-kernel.extracted.yaml`
- `bin/check-ontology.sh` wired to `check-shell.sh --audit`
- Optional `exports/shell-kernel.jsonld`

---

## Subgraph intents

| Intent | Start node | Human docs |
|--------|------------|------------|
| `path` | `shellyxz:PathContractDomain` | shell-script-readability.md, shell.md |
| `boundary` | `shellyxz:KernelPluginBoundary` | PLUGIN.md |
| `load_order` | `shellyxz:LoadOrder` | shell.md, architecture.md |
| `verify` | *SN-O1* | VERIFICATION.md |

---

## Design constraints

- Prose docs ([architecture.md](architecture.md), [PLUGIN.md](../PLUGIN.md)) stay canonical for humans; graph is the agent index.
- Node ids use `shellyxz:` prefix for future JSON-LD `@id`.
- Fused domains require ≥2 `source_refs`.
- Never compress invariants, `mustNot`, or public `path_contract_*` signatures when loading subgraphs (ai-optimization).

---

## Success signals

| Signal | Healthy |
|--------|---------|
| SN-4 PR | Includes ontology path remap + INDEX checklist |
| Agent edits `core/` | Uses lexicon vars from graph |
| `check-ontology.sh` (SN-O1) | Green on master |

---

## References

- [architecture.md](architecture.md) — current state
- [coming-next.md](coming-next.md) — backlog
- [shell-script-readability.md](shell-script-readability.md) — PATH lexicon
- Fusion Sage `fusion-state.schema.json` — fusion cache shape

*Plain rule: update the graph when boundary shape changes — same discipline as architecture.md.*
