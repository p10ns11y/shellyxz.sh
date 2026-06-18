# Coming next

Backlog from [test-of-travelled-time-from-future.md](test-of-travelled-time-from-future.md). Kernel/plugin boundary: [PLUGIN.md](../PLUGIN.md).

*Last updated: 2026-06-18*

---

## Done (path-contract-v2 PR)

1. **`local/path.contract` overlay** — personal `prepend:` lines moved out of `core/path.contract`; `path-resolve.sh` applies core then local.
2. **`SHELL_AGENT_BUILD_CMD`** — `agent-build-layout.sh` uses env vars; defaults in `local/personal.sh`.
3. **`PLUGIN.md`** — kernel vs plugin boundary (replaces lightweight `SPLIT.md`).

---

## Near-term (next PRs)

- Move verification tree to `plugins/verification/` or separate repo (physical split)
- Freeze `cockpit.yaml` spec — no new pane types without external user
- `environments/omarchy/path.overlay` for Omarchy-only PATH (alternative to `local/path.contract`)
- Collapse `.cursor/skills` → symlink to `.agents/skills`
- README / doc triage toward canonical set (`README.md`, `arch-design/shell.md`, `PLUGIN.md` + plugin docs)

---

## Cockpit scope discipline (not layout UX cuts)

**Constraint:** If tmux layouts stay, navigation infrastructure stays with them.

**Keep as plugin core (do not archive):**

- Keymap menu TSV + `tmux-keymap-menu.sh` (Prefix+? discoverability)
- SOC / tmux themes (visual pane identity)
- Golden-ratio manifest tiers (`cockpit.yaml` / layout geometry)
- `verify_workflow_root`, `ab`/`av`/`at`, `agent_scan`

**Still fair game for simplification (separate from navigators):**

- `parse-project-tests.py` complexity — thin wrapper or sh-only default where possible
- Python optional for shell-repo validation (not required to `source ~/.zshrc`)
- Spec discipline: freeze new manifest fields until external need

---

## Long-term / decision gates

- Physical repo split (`shelly-core` + `verification-cockpit`)
- Drop fish from “supported” → `contrib/fish/`
- Remove `curl | bash` as primary install
- Demote Omarchy preset to private `local/omarchy.sh`
- MCP emit/consume for cockpit instead of custom YAML panes
- **Pivot trigger:** >50% cockpit commits for 6 months while IDE review replaces tmux workflow → execute “minimal kernel only”

---

## Reference

Full 10-year analysis: [test-of-travelled-time-from-future.md](test-of-travelled-time-from-future.md)
