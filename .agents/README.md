# .agents

Agent-facing assets for this repo and distributable templates for other projects.

| Path | Purpose |
|------|---------|
| [skills/](skills/README.md) | Distributable Cursor skills (copy/symlink into target projects) |
| [verification/](verification/README.md) | Dogfood tmux verify cockpit (`av` delegates here) |

## Adopt skills in another project

```bash
mkdir -p /path/to/my-app/.cursor/skills
ln -sfn ~/.config/shell/.agents/skills/verification-cockpit \
  /path/to/my-app/.cursor/skills/verification-cockpit
```

## Adopt verification layout in another project

Run the `verification-cockpit` skill in that workspace, or copy `.agents/verification/` as a starting point.
