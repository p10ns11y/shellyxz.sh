# Coming next — status

Items from PR #5 follow-up review. **Implemented** in cockpit-next work (see git log).

## Done

- **Unified `cockpit.yaml`** — `.agents/verification/cockpit.yaml` with `cockpits.verify` + `cockpits.test`; parsers prefer it over `manifest.yaml` / `tests.yaml`.
- **Per-test `watch_command`** — `run-project-tests.sh --watch` execs first `watch_command` when present; else interval polling.
- **Safer test execution** — `run_manifest_command` in `project-tests.sh` (allowlist + `bash -c`, no bare `eval`).
- **Empty GIT pane** — lazygit missing → placeholder echo in verify layouts.
- **tmux Prefix+T** — `tmux.verify.conf.ex` binds `T` → `agent-test-layout.sh`; keymap menu updated.
- **`at --run`** — re-sends test command to TEST pane when layout exists.
- **Unit tests** — `bin/test/parse-project-tests.test.sh`.
- **Python-free fallback** — `bin/lib/parse-project-tests.sh` awk reader for `tests.yaml` when `python3` absent.
- **Docs** — `human-in-the-loop-workflow.md` nvim note; skill templates ship `cockpit.yaml`.

## Legacy files (still supported)

| File | Role |
|------|------|
| `manifest.yaml` | Verify pane map (superseded by `cockpit.yaml` cockpits.verify) |
| `tests.yaml` | Test runners (superseded by `cockpit.yaml` cockpits.test) |

---

*Last updated: 2026-06-17*
