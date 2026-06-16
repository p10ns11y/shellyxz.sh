# Verification cockpit — shell (dogfood)

Golden-ratio layout for **shell config verification** — every pane surfaces a concrete failure mode. No file browser or system monitor clutter.

## Layout (φ 62% / 38%)

```
+---------------------------+------------+
| CMD (38% h)               |            |
|---------------------------|  GIT 38% w |
| CHECK:watch (~38% h)      |  full h    |
|---------------------------|            |
| SYNC (~24% h)             |            |
+---------------------------+------------+
     insight column ~62% w
```

Pane indices: `0=CMD` `1=CHECK:watch` `2=SYNC` `3=GIT` (tmux reindexes during splits).

| Title | Prio | Space | What you learn |
|-------|------|-------|----------------|
| CHECK:watch | 1 | scroll | `check-shell-watch.sh` — full run first, then every 90s (no clear; scroll up for errors) |
| CMD | 2 | interactive | `agent_scan`, `gdf`, manual checks |
| GIT | 3 | tui-side | Uncommitted agent changes |
| SYNC | 4 | confirm | Managed template drift (`[y/N]` to run) |

**Dropped:** `yazi` and `btop` — useful elsewhere, not post-agent verification.

**CHECK pane:** `check-shell-watch.sh` (same as `shellyhow`) runs once in full, then appends every 90s — **does not clear** like `watch(1)`. Scroll up (`Prefix` `[`) to read the first run including shellcheck errors.

## Commands

```bash
av                  # this layout (delegates from agent-verify-layout.sh)
av --scan           # + agent_scan in CMD
av --generic        # skip dogfood layout
```

## Regenerate

Re-run `verification-cockpit` skill when verify workflow changes. Reference: `.agents/skills/verification-cockpit/`.
