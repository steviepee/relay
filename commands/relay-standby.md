---
description: Park this agent as the Sleeper. Waits for Worker to signal, then picks up automatically.
---

# relay-standby

Park this agent as the Sleeper. Starts a background polling process that detects when the Worker writes relay.md with `status: ready`, then picks up immediately.

## Step 1 — Signal your presence

Write `{current working directory}/sleeper.flag` with content `parked`. This tells the Worker a Sleeper is waiting. If the file already exists, overwrite it.

## Step 2 — Start background signal watcher

Run the following Bash command **with `run_in_background: true`**:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/relay_watcher.sh
```

Do NOT pass `$(pwd)` or any other shell substitution as an argument — the script reads `pwd` internally. Shell substitutions cause the Claude Code permission matcher to prompt every run, even when the bare command is on the allow list.

Note the output file path returned in the result. The background process polls relay.md every 20 seconds and exits as soon as it finds `status: ready`. It will run indefinitely until the signal appears — no timeouts, no inotify events needed.

## Step 3 — Poll for completion

Every 2-3 minutes, use the Read tool on the output file path from Step 2. Do not print any status message between polls — poll silently.

- If the file contains `RELAY_READY`: proceed to Step 4.
- If the file is empty or unchanged: wait 2-3 minutes and check again.

Repeat until `RELAY_READY` is detected.

## Step 4 — Check for done signal

Before picking up, read relay.md and check for `status: done`.

- If `status: done`: print "Batch complete. Standing down." Delete `sleeper.flag`. Stop.
- Otherwise: run `/relay-in`.
