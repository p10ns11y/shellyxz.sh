# Shell kernel — HODA decision hooks (post–SN-4a)

**Load when:** material decisions in `~/.config/shell` (shellyxz kernel + verification plugin).  
**Pairs with:** [shell-kernel.graph.yaml](../../.agents/ontology/shell-kernel.graph.yaml) · [PLUGIN.md](../../PLUGIN.md) · [architecture.md](../architecture.md)

*Last updated: 2026-06-22 (SN-4a shipped, SN-O1 next)*

---

## Critical zones (diagnose first)

| Zone | Material if you touch… | First-principles anchor |
|------|------------------------|-------------------------|
| **PATH contract** | `core/path.contract`, `path-resolve.sh`, phase lines, deny/prepend order | Machine PATH is declarative + verifyable; direnv owns project layer only |
| **Kernel / plugin boundary** | `core/*`, `plugins/verification/*`, `bin/*` shims, `verification_script_path` | Kernel must survive `rm -rf plugins/verification`; plugin calls **PublicHooks only** |
| **Load order** | `env.sh`, `templates/zshrc`, direnv fragments | `path_contract_apply` → presets → hooks → `phase:project` → `path_contract_reassert` |
| **Verification bridge** | `ab`/`av`/`at`, tmux binds, `cockpit-mcp`, per-repo `.agents/verification/` | tmux + MCP share verbs; per-project cockpit stays in each repo |
| **Ontology drift** | New public API, moved paths, invariants | Graph + `check-ontology.sh` must stay aligned with `check-shell.sh` |

---

## Post–SN-4a invariants (do not trade away)

1. **Shim stability** — `Prefix+B/V/T`, aliases `ab`/`av`/`at`, and `bin/agent-*.sh` paths stay stable; implementation may move under `plugins/verification/`.
2. **Resolver, not hardcode** — `core/functions.sh` and shims use `verification_script_path` / `verification_lib_dir`; never reintroduce bare `bin/lib/` assumptions.
3. **Bootstrap parity** — remote install must fetch full `plugins/verification/{bin,lib,data,conf}` or `ab`/`av`/`at` fail silently/wrong.
4. **Kernel forkability** — personal toolchains in `local/path.contract`, never `core/path.contract`.
5. **PLUGIN.md gate** — semantic boundary changes require PLUGIN.md + ontology node update in the same PR.

---

## Consequence prompts (2nd / 3rd order)

Ask for each option:

| Order | Question |
|-------|----------|
| 1st | What breaks on next `source ~/.zshrc` or `cd` into a project? |
| 2nd | What breaks for agents using stable `bin/` paths or MCP headless verbs? |
| 3rd | What breaks on a fresh machine (`migrate` / `bootstrap_from_remote`) with no git history? |
| 4th+ | What breaks when verification moves to SN-4b separate repo while kernel stays forkable? |

---

## Option matrix (common forks)

| Decision | Prefer when | Pre-mortem (order 2+) |
|----------|-------------|------------------------|
| Change in `core/` | PATH, migrate, public hooks, resolver | Plugin accidentally required; overlay rank regression |
| Change in `plugins/verification/` | Cockpit UX, tmux, discover-tests, MCP | Kernel import creep; bootstrap file list incomplete |
| New `bin/` shim only | Stable entrypoint for tmux/IDE | Duplicate logic — shim must `exec` plugin, not fork behavior |
| SN-4b separate repo | Release cadence diverges; external consumers | Bootstrap/version skew; ontology `Artifact` paths multiply |
| Skip ontology update | Trivial typo in prose only | Agents re-infer boundary; SN-O1 drift gate fails later |
| Expand graph before SN-O1 skill | High-traffic verification nodes needed now | Graph hairball without subgraph router |

---

## Antifragile patterns (this repo)

- **`check-shell.sh`** — add invariant before relying on human review for PATH order.
- **Contract lines + lexicon** — new PATH logic gets named locals from [shell-script-readability.md](../shell-script-readability.md).
- **Thin shims + fat plugin** — volatility absorbed in `plugins/verification/`; kernel diff stays small.
- **Per-repo cockpit** — `.agents/verification/` lets projects evolve without kernel releases.
- **Mermaid graph** — [GRAPH.md](../../.agents/ontology/GRAPH.md) + `bin/render-ontology-graph.sh` for cheap visual drift review.

---

## Monitoring signals (leading indicators)

| Signal | Healthy | Investigate when |
|--------|---------|------------------|
| `path_contract_verify` / `check-shell` | Green on master | Any PATH PR without test update |
| `ab --strict` vs full PATH | Both work | Strict mode regresses after plugin move |
| Remote bootstrap | Full plugin tree present | Only README/conf fetched |
| Ontology `meta.layout_variant` | Matches tree (`sn4_4a`) | Files moved but graph stale |
| Agent PRs touching `core/` + `plugins/` | PLUGIN.md cited | Silent boundary cross without hooks |

---

## Invocation

```
/higher-order-decision-architect
Should we {decision} in the shell kernel?
Load arch-design/overlays/shell-kernel-decision-hooks.md
```

Pair with `/fusion-sage` when the decision should emit surplus (new invariant, graph node, or check script).
