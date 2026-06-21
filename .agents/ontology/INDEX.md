# Shell kernel ontology index

**Graph:** [shell-kernel.graph.yaml](shell-kernel.graph.yaml) · **Schema:** [ontology.schema.json](ontology.schema.json) · **Fusion cache:** [fusion-state.json](fusion-state.json)

**Plan:** [arch-design/plans/shell-kernel-ontology.md](../../arch-design/plans/shell-kernel-ontology.md) · **Human docs:** [PLUGIN.md](../../PLUGIN.md) · [architecture.md](../../arch-design/architecture.md)

*SN-O0 (Phase 1): path + boundary + load order. Verification file paths after SN-4a (SN-O1).*

---

## Subgraphs (load by intent)

| Intent | Start nodes | Human docs |
|--------|-------------|------------|
| `path` | `shellyxz:PathContractDomain` | [shell-script-readability.md](../../arch-design/shell-script-readability.md), [shell.md](../../arch-design/shell.md) |
| `boundary` | `shellyxz:KernelPluginBoundary`, `shellyxz:Kernel`, `shellyxz:VerificationPlugin` | [PLUGIN.md](../../PLUGIN.md) |
| `load_order` | `shellyxz:LoadOrder` | [shell.md](../../arch-design/shell.md), [architecture.md](../../arch-design/architecture.md) |
| `verify` | *deferred SN-O1* | [VERIFICATION.md](../../arch-design/VERIFICATION.md) |

---

## Concept → files

| Concept ID | Files |
|------------|-------|
| Path contract | `core/path.contract`, `local/path.contract`, `core/path-resolve.sh` |
| Tool pins | `core/tool.contract` |
| Project PATH | repo `.path.contract`, `bin/path-contract-project.sh`, direnv `.envrc` |
| Public hooks | `core/functions.sh` (`verify_workflow_root`, `detect_editor_terminal`), `core/env.sh` (`SHELL_ROOT`) |
| Invariants gate | `bin/check-shell.sh` |

---

## Contract line → lexicon

| Line type | Variables |
|-----------|-----------|
| `phase:*` | `phase_name`, `phase_filter` |
| `prepend:TOKEN` | `path_token`, `resolved_directory`, `pending_prepend_dirs` |
| `prepend:TOKEN:gate` | + `environment_gate` |
| `deny:PATTERN` | `deny_pattern`, `resolved_directory` |
| `append:TOKEN` | `path_token`, `resolved_directory` |

Full table: [shell-script-readability.md](../../arch-design/shell-script-readability.md).

---

## SN-4 split checklist (use boundary subgraph)

When moving verification to `plugins/verification/`:

1. **Stay kernel:** `core/`, `templates/core/`, `path.contract`, migrate/recover/check
2. **Move plugin:** `bin/agent-*`, `.agents/verification/`, cockpit layouts, tmux verify scripts
3. **Keep hooks stable:** `verify_workflow_root`, `SHELL_ROOT`, `detect_editor_terminal`
4. **Update graph:** `meta.layout` → `plugins_verification`; remap plugin `Artifact` paths
5. **Do not:** change `path_contract_apply` order or require plugin for `source ~/.zshrc`

---

*Expand a fused concept: read the matching entry in `fusion-state.json` or grep `id: shellyxz:…` in the graph.*
