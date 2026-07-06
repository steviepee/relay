---
description: Wake up and continue work after the polling watcher fires, or resume manually after a pause.
---

# relay-in

Wake up and continue work after the polling watcher fires, or resume manually after a pause.

## Step 1 — Read relay.md

Resolve path: `{current working directory}/relay.md`

Check status:
- `working` — print "Agent still working. Wait for relay signal." and stop
- `halted` — print "Workflow was halted. Check standing_orders.md and relay.md before continuing." and stop
- `done` — print "Batch complete. Standing down." and stop
- `ready` or `paused` — continue

## Step 2 — Claim the relay

Immediately update relay.md status to `working`. This prevents double-pickup if both agents somehow fire at once.

## Step 3 — Delete sleeper.flag and worker.flag

Delete `{current working directory}/sleeper.flag` if it exists. You are no longer the Sleeper.
Delete `{current working directory}/worker.flag` if it exists. The previous Worker's window has been cleared.

## Step 4 — Check for standing orders

Resolve path: `{current working directory}/standing_orders.md`

If standing_orders.md exists: read it and execute the standing order. The file contains everything needed — do not read other files for orientation unless explicitly directed to by the standing order itself.

If no standing_orders.md: read relay.md `next` field and continue the overarching work from there.

## Step 5 — Confirm pickup

Print one line: "Picking up: [task description]"

Then continue working immediately. No re-consent, no re-orientation, no summary of prior work.
