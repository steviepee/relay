---
description: Explicitly stop the workflow. All progress is saved first. Pause always precedes halt.
---

# relay-halt

Explicitly stop the workflow. All progress is saved first. Pause always precedes halt.

## Step 1 — Check if already paused

Read relay.md status.

- If `paused`: skip to Step 3
- If `working`: run the full /relay-pause sequence first (Steps 1-5 of relay-pause), then continue here

**Halt never happens before pause. If halt is triggered mid-work, pause fires automatically.**

## Step 2 — Confirm pause completed

Verify relay.md now has `status: paused` and standing_orders.md exists with full context.

## Step 3 — Ask the user

Print exactly:
"Progress saved. Stop workflow?"

Wait for user response.
- If yes: continue to Step 4
- If no: print "Workflow remains paused. Run /relay-in to resume." and stop

## Step 4 — Write relay.md with status: halted

Resolve path: `{current working directory}/relay.md`

Update status field only — preserve all other content:
```
status: halted
```

## Step 5 — Print halt summary

Print a brief summary:
- What was completed
- What is saved in standing_orders.md
- How to resume: "Run /relay-in to restart from the halt point."
