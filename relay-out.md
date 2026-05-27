---
description: Save all progress and hand off to the Sleeper agent. Writing relay.md with `status: ready` wakes the Sleeper's polling watcher. **relay.md is always written last.**
---

# relay-out

Save all progress and hand off to the Sleeper agent. Writing relay.md with `status: ready` wakes the Sleeper's polling watcher. **relay.md is always written last.**

## Step 1 — Confirm you are at a save point

Do not proceed until ALL are true:
1. The current atomic unit of work is complete (finish the current entry, section, or file — do not stop mid-item)
2. All remaining work can be fully described in standing_orders.md without the Sleeper needing any other files
3. All completed work is in its final form and final location

If not at a save point, keep working until you are.

## Step 2 — Write completed work to final locations

Save any completed files to their final paths. If a file is only partially complete, save only the finished sections to a temp file and reference it in standing_orders.md.

## Step 3 — Update standing_orders.md

Resolve the path: `{current working directory}/standing_orders.md`

- If a standing order was just completed: delete standing_orders.md
- If work is unfinished: write standing_orders.md with:
  - The exact standing order (what the next Worker should do)
  - All context needed to continue without reading other files
  - A state snapshot for AIL detection (copy of key progress indicators)
  - **For hold_pos batches specifically:** list every remaining entry by full name/company (e.g. "- Acme Corp — Senior Engineer"), not by count or general direction. The new Worker counts its own completions from zero — it needs an explicit list to work from, not "continue the batch."

**AIL check:** Compare the new standing_orders.md content to what was there before this cycle. If unchanged (no progress made), do not relay-out. Instead run /relay-pause and flag the user:
"Possible AIL (Agentic Infinite Loop) detected. This task may exceed the token budget. Progress saved. Stop workflow?"

## Step 4 — Update state files

In this order:
1. Memory log — append session entry (check MEMORY.md for correct file path)
2. Update any state files defined by your current command — queue files, phase handoff docs, session logs, etc. Your project's CLAUDE.md command contract lists these explicitly. If no CLAUDE.md contract exists, update any files you actively wrote to this session.
3. Write `worker.flag` with content `ready_to_sleep` — signals this window is done and should be cleared and re-parked

## Step 5 — Verify a Sleeper is parked

Check if `{current working directory}/sleeper.flag` exists.

- If it exists: continue to Step 6.
- If it does not exist: do NOT write relay.md with `status: ready`. Run /relay-pause instead and print: "No Sleeper detected. Workflow paused. Start a second agent and run /relay-standby before resuming."

## Step 6 — Write relay.md with status: ready (LAST)

Resolve path: `{current working directory}/relay.md`

**Do NOT use the Write tool for this step.** The Write tool uses an atomic rename (temp file → rename) which generates `MOVED_TO` on the temp filename, not on `relay.md`. Use the Edit tool to change only the `status:` line, or use a Bash `sed -i` command. Both write directly to the file and generate a `CLOSE_WRITE` or `MOVED_TO relay.md` event that the Sleeper's inotifywait will catch.

First update the `completed:` and `next:` fields using the Edit tool, then flip the status line with:
```bash
sed -i 's/^status: .*/status: ready/' "$(pwd)/relay.md"
```

The relay.md structure should be:
```
status: ready
task: [current overarching task]
completed:
- [bullet list of what was done this session]
next: [exact next item, or "see standing_orders.md"]
```

## Step 7 — Stop and prompt the user

Print this block exactly:

```
--- HANDOFF COMPLETE ---
Sleeper has been signaled. This Worker's session is done.
worker.flag written — this window is ready to sleep.

1. /clear this window
2. Run /relay-standby to re-park it as the next Sleeper
--- END ---
```

Then stop. Do not run any further commands. Do not run /relay-standby yourself.
