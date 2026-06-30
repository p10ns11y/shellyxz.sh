# Shell kernel ontology — plan

**Status:** SN-O0 shipped · SN-4a shipped · **SN-O1 shipped** (verification bridge + drift gate). **Live graph:** [`.agents/ontology/`](../.agents/ontology/INDEX.md)

*Last updated: 2026-06-22*

---

## Mission

Machine-readable domain graph so agents load **addressable** semantics (kernel vs plugin, PATH layers, public API, invariants) instead of re-inferring from scattered prose each session. Pragmatic YAML/JSON now; JSON-LD export later.

---

## What shipped

### SN-O0

| Asset | Path |
|-------|------|
| Schema | `.agents/ontology/ontology.schema.json` |
| Graph | `.agents/ontology/shell-kernel.graph.yaml` |
| Fusion cache | `.agents/ontology/fusion-state.json` |
| Index | `.agents/ontology/INDEX.md` |

**Phase 1 scope:** `PathContractDomain`, `KernelPluginBoundary`, `LoadOrder`, lexicon links, invariants, public hooks.

### SN-O1

| Asset | Path |
|-------|------|
| VerificationBridge nodes | `shell-kernel.graph.yaml` (`verify` subgraph) |
| Skill | `.agents/skills/shell-kernel-ontology/SKILL.md` |
| Router rule | `.cursor/rules/ontology-router.mdc` |
| Extract | `bin/extract-ontology-facts.sh` |
| Drift gate | `bin/check-ontology.sh` (wired to `check-shell.sh --audit`) |
| Viz | `GRAPH.md` verify subgraph; `render-ontology-graph.sh --subgraph verify` |

---

## Sequencing vs SN-4

| Order | Item | Notes |
|-------|------|-------|
| 1 | **SN-O0** | Boundary + PATH graph before physical split — **shipped** |
| 2 | **SN-4a** | `plugins/verification/` + bin shims — **shipped** PR #11 |
| 3 | **SN-O1** | VerificationBridge, skill/rule, drift gate — **shipped** |

---

## Subgraph intents

| Intent | Start node | Human docs |
|--------|------------|------------|
| `path` | `shellyxz:PathContractDomain` | shell-script-readability.md, shell.md |
| `boundary` | `shellyxz:KernelPluginBoundary` | PLUGIN.md |
| `load_order` | `shellyxz:LoadOrder` | shell.md, architecture.md |
| `verify` | `shellyxz:VerificationBridge` | VERIFICATION.md |

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
| `check-ontology.sh` | Green on master |
| `check-shell.sh --audit` | Ontology section passes |

---

## References

- [architecture.md](architecture.md) — current state
- [coming-next.md](coming-next.md) — backlog
- [shell-script-readability.md](shell-script-readability.md) — PATH lexicon
- Fusion Sage `fusion-state.schema.json` — fusion cache shape

*Plain rule: update the graph when boundary shape changes — same discipline as architecture.md.*
