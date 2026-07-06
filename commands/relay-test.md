---
description: Self-contained relay handoff test. Runs a synthetic 4-item batch (Alpha, Beta, Gamma, Delta) with no queue dependencies and no lasting artifacts. Supports --relay flag like any other batch command.
---

# relay-test

Self-contained relay handoff test. The "work" per item is trivial — a timestamped line appended to `/tmp/relay_test_log.txt`. Supports `--relay` to trigger the full Worker → Sleeper handoff flow.

## Items

Fixed list: Alpha, Beta, Gamma, Delta (in that order).

---

## Flow — without `--relay`

Run all 4 items sequentially in this session:

1. For each item (Alpha → Beta → Gamma → Delta):
   - Print: `Processing: [item]`
   - Run: `date "+%Y-%m-%d %H:%M:%S"` and append `Completed: [item] — [timestamp]` to `/tmp/relay_test_log.txt`
   - Print: `Done: [item]`
2. When all 4 are done:
   - Print the contents of `/tmp/relay_test_log.txt`
   - Print: `relay-test complete. No relay active.`

---

## Flow — with `--relay`

### Step 1 — Configuration phase

If `--relay N` was passed directly (e.g. `--relay 2`): skip questions, use that N.

Otherwise ask the user:

1. **Threshold:** How many items should this Worker complete before handing off? (Suggest 1 for fastest handoff, 2 to test relay-check counting)
2. **Notify:** Silent relay or print a message at each handoff?
3. **[Check sleeper.flag silently]** — If `{current working directory}/sleeper.flag` does not exist: print "No Sleeper detected. Park a second agent with /relay-standby before starting, or run without --relay." and stop.

### Step 2 — Initialize relay_state.md

Write `{current working directory}/relay_state.md` with this structure:

```
---
relay_threshold: [N]
relay_trigger: count
relay_notify: [silent|notified]
relay_task: relay-test
session_completions: 0
---
last_completed:
remaining:
  - Alpha
  - Beta
  - Gamma
  - Delta
resume_command: relay-test --relay [N]
```

### Step 3 — Process items

For each item in the remaining list (in order):

1. Print: `Processing: [item]`
2. Append `Completed: [item] — [timestamp]` to `/tmp/relay_test_log.txt`
3. Update relay_state.md body:
   ```
   last_completed: [item]
   remaining:
     - [all items not yet completed]
   resume_command: relay-test --relay [N]
   ```
4. Run `/relay-check`

If `/relay-check` fires relay-out: stop here. Worker is done. Do not continue to the next item.

### Step 4 — Natural completion (no relay fired)

If all 4 items are processed without a relay firing:

1. Delete `relay_state.md`
2. Write relay.md with `status: done`, task: relay-test
3. Print the contents of `/tmp/relay_test_log.txt`
4. Print: `relay-test complete.`

---

## Flow — `--continue` (Sleeper pickup via relay-in → standing_orders.md)

When relay-out writes standing_orders.md, it instructs the Sleeper to run `relay-test --relay [N]` and provides the remaining list. The Sleeper's relay-in reads standing_orders.md and continues from there.

The Sleeper picks up relay_state.md (which still exists with the remaining items), resets session_completions to 0, and processes the remaining items using the same Step 3 loop above.

When remaining is empty after a relay-check call (relay-check Step 3 will skip firing): delete relay_state.md, write relay.md status: done, print the full log, print "relay-test complete."

---

## Verification

After the full run (both windows):

```bash
cat /tmp/relay_test_log.txt
```

Should show all 4 entries: Alpha, Beta, Gamma, Delta — each with a timestamp.

Clean state indicators:
- `relay_state.md` deleted
- `relay.md` status: done
- `standing_orders.md` absent
- `sleeper.flag` and `worker.flag` absent
