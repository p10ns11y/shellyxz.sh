# Coming next (follow-up PRs)

Deferred from [PR #5 — Improve verify layout](https://github.com/p10ns11y/shellyxz.sh/pull/5) review. Not blocking merge.

## Architecture

### Unified `cockpit.yaml` manifest

Today:

- `manifest.yaml` — verify pane map (`av`)
- `tests.yaml` — priority test runners (`at`)

**Proposal:** single `.agents/verification/cockpit.yaml` with `cockpits.verify` and `cockpits.test` sections — each defining a **layout** (pane arrangement), not a raw tmux window:

```yaml
# sketch — names TBD
cockpits:
  verify:
    layout: golden-4phi-r    # matches verify-layout.sh vocabulary
    panes: [...]             # today: manifest.yaml
  test:
    layout: btop-test        # btop 62% left + TEST pane right
    tests: [...]             # today: tests.yaml (max_run, priority)
```

The verification-cockpit skill generates both layout scripts in one pass. tmux still creates/focuses windows named `verify` and `test`; the manifest describes **layouts** (geometry + pane roles), not tmux primitives.

**Terminology:** prefer `layout` / `cockpit` over `window` in manifests and docs — aligns with `verify-layout.sh`, `golden-4phi-r layout`, and the existing verification-cockpit skill. Reserve `window` for tmux runtime only (e.g. “focuses the `test` window”).

**Why:** fewer agent tokens per scaffold, one source of truth for ab/av/at workflow.

### Per-test `watch_command`

`tests.yaml` supports `watch_command` but `run-project-tests.sh` only loops full `run_once` in `--watch` mode.

**Proposal:** honor `watch_command` per entry when present (e.g. `pnpm test --watch` vs `cargo watch -x test`).

## Safety & robustness

### Safer test execution than `eval`

`run-project-tests.sh` uses `eval "$cmd"` on manifest commands (trusted, repo-local YAML).

**Proposal:** run via `bash -c` with quoted manifest fields, or a small allowlist of runner prefixes (`bin/`, `pnpm`, `cargo`, `pytest`).

### Empty GIT pane when lazygit missing

Verify layout allocates 62% left column for GIT; without `lazygit`, pane 0 is blank but passes geometry checks.

**Proposal:** launch a placeholder (`echo 'install lazygit'`) or collapse to 3-pane layout when GIT unavailable.

## UX & keymaps

### tmux Prefix bind for `at`

Shell alias `at` exists; no Prefix+T (or similar) in `tmux.verify.conf.ex` yet.

**Proposal:** `bind T run-shell '.../agent-test-layout.sh "#{pane_current_path}"'` + keymap menu entry (partially done in `tmux-keymaps.tsv`).

### Re-run tests on existing `test` cockpit

`at` is idempotent — focuses the tmux `test` window without re-running tests.

**Proposal:** `at --run` sends test command to TEST pane when the layout already exists.

## Testing & docs

### Unit tests for test runner

Add `bin/test/parse-project-tests.test.sh` or pytest for `parse-project-tests.py` (manifest parse, auto-discover, `max_run` slicing).

### `human-in-the-loop-workflow.md` nvim pane

Doc still references nvim in verify CMD pane; many users run nvim in a separate window. Optional: add `eff` / Omarchy nvim split to ritual table.

### Python-free fallback

For minimal environments without `python3`, parse `tests.yaml` with a constrained awk/bash reader or ship manifest as JSON.

---

*Last updated: 2026-06-17 — terminology: layouts + cockpits (not windows in manifests).*
