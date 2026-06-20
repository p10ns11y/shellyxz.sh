# .agents

Agent-facing assets for this repo and distributable templates for other projects.

| Path | Purpose |
|------|---------|
| [skills/](skills/README.md) | Dogfood copy of distributable skills (canonical: [agent skills library](https://github.com/p10ns11y/skills)) |
| [verification/](verification/README.md) | Dogfood tmux verify cockpit (`av` delegates here) |

## Adopt skills in another project

```bash
SKILLS_ROOT=~/skills
mkdir -p /path/to/my-app/.cursor/skills
ln -sfn "$SKILLS_ROOT/verification-cockpit" /path/to/my-app/.cursor/skills/verification-cockpit
```

## Adopt verification layout in another project

Run the `verification-cockpit` skill in that workspace, or copy `.agents/verification/` as a starting point.
