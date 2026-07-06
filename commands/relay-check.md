---
description: Check relay_state.md after a completion and fire relay-out if the threshold is reached. Called by any relay-compatible command after each atomic unit completes, only when --relay is active.
---

# relay-check

Check relay_state.md after a completion and fire relay-out if the threshold is reached.

## Step 1 — Read relay_state.md

Resolve path: `{current working directory}/relay_state.md`

If relay_state.md does not exist or has no header (no `---` line): print "relay_state.md missing or malformed. Skipping relay check." and stop.

Read both sections:
- Header (above `---`): relay_threshold, relay_trigger, relay_notify, relay_task, session_completions
- Body (below `---`): last_completed, remaining, resume_command

## Step 2 — Increment session_completions

Add 1 to `session_completions` in the header. Write the updated value back to relay_state.md. Do not modify the body.

## Step 3 — Check remaining

If `remaining` is empty or absent: do not fire relay-out. The batch is finishing naturally. Return without action.

## Step 4 — Check threshold

**Count-based** (`relay_trigger: count`):

Compare `session_completions` against `relay_threshold`.

- If `session_completions` is less than `relay_threshold`: do not fire. Return without action.
- If `session_completions` equals `relay_threshold`: proceed to Step 5.
- Reset `session_completions` to 0 in the header before proceeding (the next Worker starts its own count from zero).

**Step-based** (`relay_trigger: step`):

Compare `last_completed` against `relay_threshold` value.

- If they do not match: do not fire. Return without action.
- If they match: proceed to Step 5.

## Step 5 — Notify if configured

If `relay_notify` is not `silent`: print one line:

```
Relay threshold reached after [last_completed]. Handing off. [N] entries remaining.
```

## Step 6 — Fire relay-out

Run `/relay-out`.

relay-out will read relay_state.md to construct standing_orders.md. The `resume_command` field in the body provides the exact command for the Sleeper to run. The `remaining` field provides the entry list.
