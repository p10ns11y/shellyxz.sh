# Plugins

Optional features that extend the shell kernel without changing core load order. Each plugin lives in its own directory under `plugins/`.

**Kernel boundary:** [PLUGIN.md](../PLUGIN.md) — what must work without any plugin installed.

| Plugin | Purpose | Docs |
|--------|---------|------|
| [verification/](verification/README.md) | Agent verification cockpit (`ab` / `av` / `at`), tmux layouts, headless `cockpit-mcp` | [plugins/verification/README.md](verification/README.md) |

Stable entrypoints stay at `~/.config/shell/bin/*` (thin shims). Plugin scripts resolve via `verification_script_path` in `core/lib.sh`.
