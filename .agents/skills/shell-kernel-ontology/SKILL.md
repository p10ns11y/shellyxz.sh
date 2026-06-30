---
name: shell-kernel-ontology
description: >-
  Load and maintain the shellyxz shell kernel ontology graph — PATH contract,
  kernel/plugin boundary, load order, and verification bridge (ab/av/at).
  Use when editing core/, plugins/verification/, bin shims, moving files across
  the kernel boundary, or answering where a concept lives in the tree.
---

# Shell Kernel Ontology

**Mission:** Route agents to **addressable** semantics instead of re-inferring from scattered prose. Canonical graph: [`.agents/ontology/shell-kernel.graph.yaml`](../../ontology/shell-kernel.graph.yaml).

**Pairs with:** [fusion-state.json](../../ontology/fusion-state.json) · [GRAPH.md](../../ontology/GRAPH.md) · [HODA overlay](../../../arch-design/overlays/shell-kernel-decision-hooks.md)

---

## When to use

- Edit `core/`, `plugins/verification/`, `bin/*` shims, or `path.contract` layers
- Move files across kernel vs verification plugin boundary
- Add or rename public hooks (`path_contract_*`, `verify_workflow_root`, resolver)
- User asks: "where does X live?", "kernel or plugin?", "update ontology"
- After structural PR: run drift gate before merge

**Do not use for:** per-project `.agents/verification/` cockpits in other repos — use `verification-cockpit` skill there.

---

## Subgraph router (load by intent)

| Intent | Start node | Load when |
|--------|------------|-----------|
| `path` | `shellyxz:PathContractDomain` | PATH contract, `path-resolve.sh`, lexicon locals |
| `boundary` | `shellyxz:KernelPluginBoundary` | Kernel vs plugin, `must_not` / `may_assume`, PLUGIN.md |
| `load_order` | `shellyxz:LoadOrder` | env.sh, zshrc tail, direnv `phase:project` |
| `verify` | `shellyxz:VerificationBridge` | ab/av/at, shims, resolver, cockpit-mcp, strict PATH |

**Index:** [INDEX.md](../../ontology/INDEX.md) · **Viz:** [GRAPH.md](../../ontology/GRAPH.md)

```bash
bin/render-ontology-graph.sh --subgraph verify
bin/render-ontology-graph.sh --subgraph boundary
```

---

## Never compress (ai-optimization)

When loading a subgraph, **always retain**:

- Invariant nodes (`shellyxz:Inv_*`) tied to your edit
- `must_not` / `may_assume` on boundary nodes
- Public `path_contract_*` signatures and resolver function names
- `source_refs` for nodes you cite in the PR

---

## Verification bridge (SN-O1)

| Verb | Function | Resolver target |
|------|----------|-----------------|
| `ab` | `agent_build` | `verification_script_path agent-build-layout.sh` |
| `av` | `agent_verify` | `verification_script_path agent-verify-layout.sh` |
| `at` | `agent_test` | `verification_script_path agent-test-layout.sh` |

- **Implementation:** `plugins/verification/` · **Stable entry:** `bin/*` shims
- **Headless:** `bin/cockpit-mcp.sh` (plugin copy is canonical)
- **Per-repo manifest:** `.agents/verification/cockpit.yaml` (not in kernel tree)
- **Strict PATH:** `SHELL_AGENT_STRICT_PATH=1` or `ab --strict`

---

## Maintenance workflow

Structural change in one PR:

1. Update code + `PLUGIN.md` / `architecture.md` if boundary semantics shift
2. Update `shell-kernel.graph.yaml` (nodes, `source_refs`, Artifact `path`)
3. Refresh [INDEX.md](../../ontology/INDEX.md) checklist row if needed
4. Run drift gate:

```bash
bin/check-ontology.sh
bin/check-shell.sh --audit
```

5. Optional: regen Mermaid — `bin/render-ontology-graph.sh --subgraph all`

Extract-only facts file (local, gitignored): `bin/extract-ontology-facts.sh`

---

## Decision hooks (HODA)

Material kernel/plugin choices: [shell-kernel-decision-hooks.md](../../../arch-design/overlays/shell-kernel-decision-hooks.md)

| Decision class | Ontology signal |
|----------------|-----------------|
| File move | Remap `Artifact` paths + keep shims |
| New public API | Add `Function` or `Hook` node + invariant if needed |
| Skip graph update | Drift gate fails on next `--audit` |

---

## Companion skills

| Skill | Role |
|-------|------|
| [verification-cockpit](../verification-cockpit/SKILL.md) | Per-project tmux layouts (not kernel ontology) |
| [stellar-roadmap](../stellar-roadmap/SKILL.md) | Backlog cards SN-* after ontology ships |
| fusion-sage (global) | Fused abstractions in `fusion-state.json` |

*Plain rule: graph and tree move together — same discipline as `architecture.md`.*
