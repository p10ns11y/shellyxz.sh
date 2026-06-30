# Ontology graph — visualization

**Source:** [shell-kernel.graph.yaml](shell-kernel.graph.yaml) · **Index:** [INDEX.md](INDEX.md) · **Schema:** [ontology.schema.json](ontology.schema.json)

*Last updated: 2026-06-22*

---

## Best way to view (this repo)

| Method | When to use | Renders where |
|--------|-------------|---------------|
| **This file (curated Mermaid)** | Reading architecture, PR review, agents | GitHub, Cursor markdown preview |
| **`bin/render-ontology-graph.sh`** | After graph edits; drift gate (`check-ontology.sh`) | stdout → paste or pipe to file |
| **INDEX.md tables** | Lookup concept → files without diagram | Everywhere |

**Why Mermaid:** already used in [architecture.md](../../arch-design/architecture.md) and [coming-next.md](../../arch-design/coming-next.md); zero install; diffs stay readable. Full auto-layout of 40+ nodes is a hairball — use **subgraph views** below, not one mega-chart.

**Regenerate:**

```bash
bin/render-ontology-graph.sh --subgraph boundary
bin/render-ontology-graph.sh --subgraph path
bin/render-ontology-graph.sh --subgraph load_order
bin/render-ontology-graph.sh --subgraph verify
bin/render-ontology-graph.sh --subgraph all > .agents/ontology/graph.generated.mmd
bin/check-ontology.sh
```

---

## Boundary subgraph (kernel vs plugin)

```mermaid
flowchart TB
  subgraph boundary["boundary"]
    KPB["Kernel vs Verification Plugin Boundary<br/><small>Domain</small>"]
    K["Kernel<br/><small>Boundary</small>"]
    VP["Verification Plugin<br/><small>Boundary</small>"]
    PH_vwr["verify_workflow_root<br/><small>Hook</small>"]
    PH_root["SHELL_ROOT / SHELL_CONFIG_BIN<br/><small>Hook</small>"]
    PH_det["detect_editor_terminal<br/><small>Hook</small>"]
    Inv_del["kernel works if plugin deleted<br/><small>Invariant</small>"]
  end

  KPB -.->|doc| K
  KPB -.->|doc| VP
  K --> KPB
  VP -.->|depends| K
  K -.->|mustNot| VP
  K --> PH_vwr
  K --> PH_root
  K --> PH_det
  Inv_del -->|enforces| K
```

**Post–SN-4a:** implementation lives in `plugins/verification/`; `bin/*` shims + `verification_script_path` keep stable entrypoints.

---

## PATH subgraph (contract domain)

```mermaid
flowchart TB
  subgraph path["path"]
    PCD["Path Contract Domain<br/><small>Domain</small>"]
    PC["Path Contract File<br/><small>Concept</small>"]
    PP["Path Phase<br/><small>Concept</small>"]
    Pre["prepend line<br/><small>Concept</small>"]
    App["append line<br/><small>Concept</small>"]
    Den["deny line<br/><small>Concept</small>"]
    EG["Environment Gate<br/><small>Concept</small>"]
    Lex["PATH Readability Lexicon<br/><small>Concept</small>"]
    Core["core/path.contract<br/><small>Artifact</small>"]
    Local["local/path.contract<br/><small>Artifact</small>"]
    Proj["repo .path.contract<br/><small>Artifact</small>"]
    Tool["core/tool.contract<br/><small>Artifact</small>"]
    Fn_apply["path_contract_apply<br/><small>Function</small>"]
    Fn_proj["path_contract_apply_project<br/><small>Function</small>"]
    Fn_re["path_contract_reassert<br/><small>Function</small>"]
    Inv_local["local wins core on which<br/><small>Invariant</small>"]
    Inv_dir["direnv owns project PATH<br/><small>Invariant</small>"]
    Inv_re["path_contract_reassert at zshrc tail<br/><small>Invariant</small>"]
  end

  PCD --> PC
  PC --> PP
  PP --> Pre
  PP --> App
  PP --> Den
  Pre -->|resolves| EG
  Pre -->|lexicon| Lex
  Den -->|lexicon| Lex
  PCD --> Core
  PCD --> Local
  PCD --> Proj
  PCD --> Tool
  Fn_apply -->|resolves| Core
  Fn_apply -->|resolves| Local
  Fn_proj -->|resolves| Proj
  Inv_local -->|enforces| Local
  Inv_dir -->|enforces| Proj
  Inv_re -->|enforces| Fn_re
```

---

## Load order subgraph

```mermaid
flowchart LR
  subgraph load_order["load_order"]
    LO["Shell Load Order<br/><small>Domain</small>"]
    Fn_apply["path_contract_apply<br/><small>Function</small>"]
    Fn_re["path_contract_reassert<br/><small>Function</small>"]
  end

  LO -->|before| Fn_apply
  LO -->|before| Fn_re
```

Detail sequence: [architecture.md § PATH precedence](../../arch-design/architecture.md#path-precedence).

---

## Verify subgraph (ab/av/at bridge)

```mermaid
flowchart TB
  subgraph verify["verify"]
    VB["Verification Bridge<br/><small>Domain</small>"]
    Vab["ab (agent build)<br/><small>Concept</small>"]
    Vav["av (agent verify)<br/><small>Concept</small>"]
    Vat["at (agent test)<br/><small>Concept</small>"]
    Fn_ab["agent_build<br/><small>Function</small>"]
    Fn_av["agent_verify<br/><small>Function</small>"]
    Fn_at["agent_test<br/><small>Function</small>"]
    Res["verification_script_path<br/><small>Function</small>"]
    Plug["plugins/verification/<br/><small>Artifact</small>"]
    Shim_b["bin/agent-build-layout.sh<br/><small>Artifact</small>"]
    Shim_v["bin/agent-verify-layout.sh<br/><small>Artifact</small>"]
    Shim_t["bin/agent-test-layout.sh<br/><small>Artifact</small>"]
    Mcp["bin/cockpit-mcp.sh<br/><small>Artifact</small>"]
    Strict["SHELL_AGENT_STRICT_PATH<br/><small>Concept</small>"]
  end

  VB --> Vab
  VB --> Vav
  VB --> Vat
  Vab -->|resolves| Fn_ab
  Vav -->|resolves| Fn_av
  Vat -->|resolves| Fn_at
  Fn_ab -->|resolves| Res
  Fn_av -->|resolves| Res
  Fn_at -->|resolves| Res
  Res -->|resolves| Plug
  Shim_b -->|resolves| Plug
  Shim_v -->|resolves| Plug
  Shim_t -->|resolves| Plug
  VB --> Mcp
  VB --> Strict
  Strict -->|enforces| Fn_ab
```

**Drift gate:** `bin/check-ontology.sh` compares [shell-kernel.graph.yaml](shell-kernel.graph.yaml) to `bin/extract-ontology-facts.sh` output. Wired into `check-shell.sh --audit`.

---

## Decision overlay

Material kernel/plugin choices: [shell-kernel-decision-hooks.md](../../arch-design/overlays/shell-kernel-decision-hooks.md) (HODA).
