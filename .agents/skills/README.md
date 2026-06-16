# Skills (distributable + dogfood)

Cursor agent skills shipped with this shell repo under `.agents/skills/`.

| Skill | Use in |
|-------|--------|
| [verification-cockpit](verification-cockpit/SKILL.md) | Any repo using the `av` workflow — **including this one** as a stress test |

## Dogfood (this repo)

Reference verification layout: [`.agents/verification/`](../verification/README.md). Run `av` here to stress-test delegation and tiered launches.

## Adopt in another project

```bash
mkdir -p /path/to/my-app/.cursor/skills
ln -sfn ~/.config/shell/.agents/skills/verification-cockpit \
  /path/to/my-app/.cursor/skills/verification-cockpit
# or: cp -a ~/.config/shell/.agents/skills/verification-cockpit /path/to/my-app/.cursor/skills/
```

Then run the skill in that workspace to generate `.agents/verification/*`.

Requires: `av` / `agent_verify`, `~/.config/shell/bin/lib/verify-launch.sh`, Ghostty + tmux.
