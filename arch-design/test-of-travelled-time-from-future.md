# Test of Travelled Time from the Future

A ruthless 10-year survivability evaluation of `~/.config/shell/` — split personality: iron core + volatile cockpit.

**Date:** 2026-06-18  
**Frameworks applied:** Context Sage, Fusion Sage, Higher-Order Decision Architect

---

🧠 **Fusion Sage v2.0** | Budget: ~18k / 200k (9%) | **Relevance: 97/100** | **Stability: 62/100** (split personality: iron core + volatile cockpit)

## Executive Verdict

**This repo will not survive 10 years as one unified product.** It is two systems welded together: a genuinely portable shell framework (~40% of value, high durability) and an agent-verification cockpit (~60% of recent energy, high obsolescence risk). **Do not stop entirely** — **split or radically demote the cockpit**, keep a ~1,500-line "shell kernel," and treat everything agent/tmux/Cursor-specific as an optional plugin that can die without taking your dotfiles with it.

**Confidence: 68%** on that verdict. Uncertainty is mostly *how fast* IDE-native agents eat terminal-native workflows (3–7 year window, not 10).

---

## Critical Area Identified

**Identity crisis + coupling depth.** README says "portable shell config"; motivation and `cockpit-next` say "terminal-native agent verification platform." Those compete for architecture, docs, PATH contract, and maintenance budget.

---

## First Principles Breakdown

| Invariant (10-year) | Your project | Verdict |
|---------------------|--------------|---------|
| POSIX shell + bash/zsh on every Unix | `core/lib.sh`, `env.sh`, templates | **Strong** |
| PATH is the real API of a dev environment | `path.contract` + `path-resolve.sh` | **Strong** (rare, underrated) |
| Dotfiles must be recoverable when broken | `recover-shell.sh`, `backups/*/revert.sh` | **Strong** |
| Humans review before commit | Timeless | **Goal is right** |
| Specific agent TUIs (Grok), tmux golden-ratio layouts, nvim plugins | `ab`/`av`, default `grok`, external nvim lua | **Fragile** |
| Distro/desktop portability | Omarchy preset, Ghostty notes, `paru` in migrate | **Narrow** |
| "Works on any device" | `path.contract` lists grok, risc0, solana, vite-plus, ROCm | **Personal cruft in core** |

**Binding energy (what actually holds):** declarative PATH contract, `core/` + `environments/` split, migrate-with-revert, `check-shell.sh` as gate.

**Entropy sources (what will rot):** Grok default, Cursor/Ghostty guards, YAML cockpit manifests, duplicated `.agents/` + `.cursor/`, fish+bass parity, 18 design docs, Python test runner dependency.

---

## Consequence Chain

| Order | Effect | P(10y) | Impact | Notes |
|-------|--------|--------|--------|-------|
| 1st | Agents stay IDE-first (Cursor, Claude Code, cloud agents) | ~75% | H | `ab`/`av` niche shrinks to power users |
| 2nd | Grok CLI changes/replaced | ~80% | H | Hardcoded in `agent-build-layout.sh` |
| 3rd | Omarchy evolves or you leave Arch desktop | ~50% | M | Reserved names (`ga`, `gd`, `n`) break |
| 2nd | Nix/home-manager adoption among your future self | ~40% | M | `migrate.sh` becomes legacy for you |
| 2nd | tmux stable but layout YAML feels archaic | ~60% | M | Like Oh My Zsh — works, unfashionable |
| 3rd | `path.contract` becomes the only part you still use | ~55% | **Positive** | Iron-peak abstraction |
| 3rd | fish+bass unmaintained or you stop caring | ~70% | L | Drop fish or accept 2nd-class |
| 3rd | Python required for test cockpits on minimal VPS | ~90% | M | Violates "portable shell" story |

---

## Inversion & Pre-Mortem (2036: "We abandoned shellyxz")

**What went wrong:**

1. **Scope creep** — Every new agent tool got a tmux pane, keymap, and doc. Maintenance > benefit.
2. **Vendor anchors** — Grok, Cursor phantom-tab detection, nvim `verification-workflow.lua` outside repo.
3. **False portability** — README promises bash/zsh/fish + generic containers; reality is Omarchy + Ghostty + tmux + 15 CLI tools.
4. **Documentation debt** — More architecture than implementation. Next maintainer (you) reads 6 MD files before changing PATH.
5. **Core pollution** — Personal toolchain entries in `core/path.contract` make "fork and use" hostile.

**Mitigations that actually work:** split repos, plugin boundary, freeze cockpit, local overlays, one agent interface env var.

---

## Fused Abstraction: Two Products, One Repo

```
┌─────────────────────────────────────────────────────────┐
│  SHELL KERNEL (portable, 10y viable)                    │
│  core/*, path.contract, migrate, check-shell, recover   │
│  environments/generic + thin preset hook                │
└───────────────────────────┬─────────────────────────────┘
                            │ optional plugin API
┌───────────────────────────▼─────────────────────────────┐
│  VERIFICATION COCKPIT (workflow product, 3–7y horizon)  │
│  ab/av/at, tmux layouts, cockpit.yaml, Cursor skills    │
│  Grok default, nvim plugin, golden-ratio layouts        │
└─────────────────────────────────────────────────────────┘
```

The kernel is **portable across distros/devices** if you stop treating Omarchy and Grok as defaults. The cockpit is **a workflow opinion** — valuable today, not foundation.

---

## Real Solutions (ranked by regret minimization)

### 1. **SPLIT (recommended)** — highest 10-year survival

| Repo | Keep | Kill/move |
|------|------|-----------|
| **`shelly-core`** (or rename) | `core/`, `templates/`, `bin/{migrate,check-shell,recover-shell,capture-shell-init}`, `environments/generic`, `path.contract` schema | All `agent-*`, tmux theme/keymap scripts, `.agents/`, `.cursor/` |
| **`verification-cockpit`** (optional) | `ab`/`av`, layouts, skill, `cockpit.yaml` spec | Shell PATH, migrate, rc generation |

**Contract between them:** one env var + one function:

```bash
# environments/*/env.sh or local/personal.sh
export SHELL_AGENT_BUILD_CMD="${SHELL_AGENT_BUILD_CMD:-cursor agent}"  # or claude, amp, whatever exists in 2030
```

Cockpit repo depends on shell kernel; kernel has **zero** knowledge of agents.

---

### 2. **PIVOT cockpit → "tmux recipes," not a platform**

Stop building: unified `cockpit.yaml`, Python parser, per-project skill generation, mode-sync nvim bridge.

Keep only:

- `tmux new-window` helpers (3 layouts max: build, verify, test)
- `verify_workflow_root.sh` (git root walk-up — genuinely reusable)
- `agent_scan` as a 30-line function (rg + jq)

**Delete or archive:** `parse-project-tests.py`, `agent-test-layout.sh`, keymap menu TSV, SOC themes, golden-ratio manifest tiers.

**Q gain:** ~40% less code, ~60% less doc rot, cockpit survives agent churn because it doesn't *name* the agent.

---

### 3. **DEBLOAT the kernel (do this even if you don't split)**

| Action | Why |
|--------|-----|
| Move `grok`, `risc0`, `solana`, `vite-plus`, ROCm from `core/path.contract` → `local/path.contract` or `environments/omarchy/path.overlay` | Core must be forkable by strangers |
| Drop **fish** from "supported" → `contrib/fish/` unmaintained | bass is a compatibility tax forever |
| Collapse `.cursor/skills` → symlink to `.agents/skills` only | One distribution surface |
| Reduce docs to **3**: `README.md`, `arch-design/shell.md`, `arch-design/VERIFICATION.md` (or move verify doc to plugin repo) | 18 MD files won't stay accurate |
| Remove `curl \| bash` as primary install; keep clone + `migrate.sh` | Supply-chain + trust decay over decade |
| Make Python **optional** for shell repo; sh-only test runner for default case | VPS/embedded survival |

---

### 4. **STOP the project (if you're honest about time)**

**Don't delete the repo — freeze it.** Archive `cockpit-next`, tag `v1-shell-kernel`.

**Minimal features worth keeping (~15% of current scope):**

```
~/.config/shell/
├── core/
│   ├── lib.sh          # source_if_safe, secrets, environments
│   ├── path.sh         # prepend/append/dedupe
│   ├── path.contract   # YOUR paths in local/ only
│   ├── env.sh          # load contract + generic preset
│   ├── aliases.sh      # ~20 aliases max
│   └── functions.sh    # path_debug, reload, maybe vf
├── local/personal.sh
├── templates/zshrc,bashrc   # thin wrappers
└── bin/
    ├── migrate.sh
    ├── check-shell.sh
    └── recover-shell.sh
```

**Explicitly remove from "minimal":**

- `ab` / `av` / `at` and all tmux layout scripts
- `.agents/verification/` local stress-test layout
- Cursor agent definitions
- `starship`/`yazi`/`git.ex.config` scaffolding in migrate (copy examples to wiki, not migrate)
- Omarchy as built-in preset → `local/omarchy.sh` you maintain privately

**You still get:** portable PATH, safe secrets, recoverability, multi-shell entrypoints. **You lose:** agent cockpit — use IDE + `git diff` + `lazygit` ad hoc.

---

### 5. **CONTINUE as-is (not recommended)**

| 1st order | 2nd order | 3rd order |
|-----------|-----------|-----------|
| More cockpit features | More docs, tests, Python | Kernel changes break cockpit; neither gets polish |
| Grok → X → Y agent migrations | Rewrite layout scripts each time | You maintain a product nobody else can install |

**Only continue unified if** this is explicitly a *personal* dotfiles repo, not a portable framework — then rename it and delete "Audience: advanced portable" from README.

---

## Trend Lens (every angle, blunt)

| Trend | Impact on this project |
|-------|------------------------|
| **IDE agents** | Cockpit value ↓ unless IDE terminals get tmux-equivalent persistence |
| **Devcontainers / Nix** | `migrate.sh` less relevant; `path.contract` *more* relevant as runtime verifier |
| **Wayland / new terminals** | tmux survives; Ghostty-specific docs won't |
| **POSIX shell** | Still here in 2036. Your sh loaders are the right bet |
| **fish** | Nice UX, wrong portability bet for core |
| **MCP / standardized agent tools** | Cockpit should emit/consume MCP, not custom YAML panes |
| **AI code review bots** | Partial substitute for human verify cockpit |
| **Single-maintainer open source** | 5.6k LOC shell + platform = burnout in ~2–3 years |

---

## Recommended Decision

**Split mentally today, physically next month:**

1. **Declare `shelly-core`** — PATH contract + migrate + check + recover + generic environment. No agent words in README.
2. **Demote verification** to `plugins/verification/` or separate repo; **remove Grok default** → `SHELL_AGENT_BUILD_CMD`.
3. **Purge personal PATH from core** — move to `local/path.contract`.
4. **Freeze cockpit YAML spec** at current `cockpit.yaml`; no new pane types until an external user asks.

**Rationale:** The kernel uses primitives that outlive vendors (sh, PATH, git, tmux). The cockpit bets on vendors (Grok, Cursor, nvim plugin, Omarchy). Separating them lets the cockpit die without killing the foundation.

---

## Confidence & Leading Indicators

| Assumption | Monitor |
|------------|---------|
| You are primary/only maintainer | Months between cockpit commits vs kernel commits |
| Terminal-native review stays valuable | You still open tmux after agent runs (weekly?) |
| Omarchy stays your desktop | Reserved-name conflicts in `check-shell.sh` |
| Portable story matters | External clones/issues (if zero in 12mo, go personal-only) |

**Watch for pivot trigger:** If >50% of commits are cockpit/agent for 6 months while you use Cursor's built-in review more → **execute "minimal kernel only."**

---

## Immediate Next Actions (max 3)

1. **Create `local/path.contract`** and move all personal `prepend:` lines out of `core/path.contract` (one PR, pure win).
2. **Add `SHELL_AGENT_BUILD_CMD`** and remove hardcoded `grok` from build layout (decouples agent vendor).
3. **Write `arch-design/SPLIT.md`** with kernel vs plugin boundary — even if you don't split repos yet, the doc forces honesty.

---

## ⚡ Fusion Surplus (Q ≈ 1.4)

This evaluation would have cost ~25% fewer tokens with a single **`PLUGIN.md` boundary file** at repo root: "kernel guarantees / plugin may assume." Suggested diff: ~40 lines, saves repeated re-discovery of the two-product problem on every architecture review.

---

## Bottom Line

The foundation (`path.contract`, `core/`, migrate/revert/check) is worth keeping and could port across distros and devices for a decade. The verification cockpit is a **2025–2028 workflow product** baked into a **2036 infrastructure repo** — that mismatch is the existential risk. Split or shrink; don't nurture both at full size unless you want a personal dotfiles tomb, not a portable system.
