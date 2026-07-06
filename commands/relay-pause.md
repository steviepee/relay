---
description: Save all progress and stop without handing off. Resume later with /relay-in.
---

# relay-pause

Save all progress and stop. No handoff to the Sleeper. Resume later with /relay-in.

## Step 1 — Confirm you are at a save point

Same rules as relay-out:
1. Current atomic unit of work is complete
2. All remaining work can be fully described in standing_orders.md
3. All completed work is in its final form and final location

If not at a save point, keep working until you are.

## Step 2 — Write completed work to final locations

Save completed files to their final paths.

## Step 3 — Write standing_orders.md

Resolve path: `{current working directory}/standing_orders.md`

Write full context for resuming:
- Exact standing order (what to do next)
- All context needed to continue without reading other files
- State snapshot for AIL detection

## Step 4 — Update state files

1. session_progress.md
2. Memory log
3. Queue or batch-tracking files (if applicable)
4. Any other project-specific state files

## Step 5 — Write relay.md with status: paused (LAST)

Resolve path: `{current working directory}/relay.md`

```
status: paused
task: [current overarching task]
completed:
- [bullet list of what was done this session]
next: [exact next item, or "see standing_orders.md"]
```

**Note: status: paused does NOT wake the Sleeper.**

## Step 6 — Print resume instructions

Print: "Progress saved. Workflow paused. Run /relay-in to resume."
