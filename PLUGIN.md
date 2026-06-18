# Kernel vs plugin boundary

This repo is **two products in one tree**. Read this before architecture reviews, refactors, or new features.

| Layer | Role | Must work without the other |
|-------|------|-----------------------------|
| **Kernel** | Portable shell: PATH, migrate, recover, check | Yes |
| **Plugin** | Agent verification cockpit (`ab`/`av`/`at`, tmux, YAML) | Yes (optional workflow) |

Deep rationale: [arch-design/test-of-travelled-time-from-future.md](arch-design/test-of-travelled-time-from-future.md).

---

## Kernel guarantees

The kernel **must** remain usable if every agent/tmux feature is deleted.

| Guarantees | Location |
|------------|----------|
| POSIX `sh` loaders; bash/zsh interactive modules | `core/lib.sh`, `core/env.sh`, `templates/` |
| Declarative PATH build + runtime verify | `core/path.contract`, `core/path-resolve.sh` |
| Environment presets (`generic` at minimum) | `environments/`, `core/env.sh` |
| Safe secrets + optional overlays | `lib.sh`, `local/personal.sh`, `local/overwrite.sh` |
| Migrate with backup + `revert.sh` | `bin/migrate.sh`, `bin/tasks/` |
| Validation gate | `bin/check-shell.sh` |
| Nuclear recovery | `bin/recover-shell.sh` |

**Kernel must not:**

- Hardcode agent vendor CLIs (`grok`, `cursor agent`, etc.)
- Require tmux, Python, nvim plugins, or Cursor
- Put machine-specific PATH entries in `core/path.contract` (use `local/path.contract` or `environments/<preset>/`)

**Kernel public hooks plugins may call:**

- `verify_workflow_root` / `bin/verify-workflow-root.sh` — git-aware project root
- `SHELL_ROOT`, `SHELL_CONFIG_BIN` — paths to `~/.config/shell`
- `detect_editor_terminal` / `SHELL_IN_EDITOR_TERMINAL` — skip broken integrated terminals

---

## Plugin may assume

The verification plugin **may** assume a richer environment. It is allowed to break or be removed without blocking a working shell.

| May assume | Location |
|------------|----------|
| tmux session active; not in editor integrated terminal | `core/functions.sh` (`_agent_tmux_guard`) |
| Optional tools: lazygit, bat, fzf, yazi, difftastic, rg, dust | `aliases.sh`, layouts, `agent_scan` |
| Per-project cockpit manifests | `.agents/verification/`, `cockpit.yaml` |
| Desktop integration (Omarchy, Ghostty) | `environments/omarchy/`, docs |
| Agent build command via env (target) | `SHELL_AGENT_BUILD_CMD` — **not** hardcoded in kernel |

**Plugin must not:**

- Change kernel load order or PATH contract semantics without updating `check-shell.sh`
- Add required kernel dependencies (e.g. Python mandatory for `source ~/.zshrc`)

---

## Decision rule

| Change touches… | Treat as… | Check |
|-----------------|-----------|-------|
| `core/`, `path.contract`, migrate, recover | **Kernel** | Works on generic Linux + bash/zsh only? |
| `agent-*`, tmux layouts, `.agents/`, cockpit YAML | **Plugin** | Can user delete it and still `source ~/.zshrc`? |
| Both | **Split the PR** or document cross-boundary contract here |

When in doubt: kernel stays boring; plugin stays opinionated.
