# Skills (dogfood copy)

Canonical source: **[agent skills library](https://github.com/p10ns11y/skills)** (`~/skills` or your clone path).

This repo vendors copies under `.agents/skills/` for dogfood and offline use. Prefer installing from the skills library and symlinking into projects.

| Skill | Use in |
|-------|--------|
| [verification-cockpit](verification-cockpit/SKILL.md) | Any repo using the `av` workflow — **including this one** as a stress test |
| [stellar-roadmap](stellar-roadmap/SKILL.md) | Architecture backlog docs (`coming-next.md`, blueprint cards SN-*) — pairs with ai-optimization, fusion-sage, higher-order-decision-architect |

## Dogfood (this repo)

Reference verification layout: [`.agents/verification/`](../verification/README.md). Run `av` here to stress-test delegation and tiered launches.

Shell-specific overlays (live paths): skills library `examples/overlays/shellyxz-shell-kernel.md` and `shell-av-workflow.md`.

## Adopt in another project

```bash
SKILLS_ROOT=~/skills
mkdir -p /path/to/my-app/.cursor/skills
ln -sfn "$SKILLS_ROOT/verification-cockpit" /path/to/my-app/.cursor/skills/verification-cockpit
# or: cp -a "$SKILLS_ROOT/verification-cockpit" /path/to/my-app/.cursor/skills/
```

Then run the skill in that workspace to generate `.agents/verification/*`.

Requires: `av` / `agent_verify`, host shell workflow (`verify-launch.sh`), Ghostty + tmux. See overlay `examples/overlays/shell-av-workflow.md` in the skills library.
