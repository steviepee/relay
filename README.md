# Relay Skills — README

A lightweight two-agent handoff system for Claude Code. Lets a Worker agent pass a long-running batch task to a parked Sleeper agent when it reaches a threshold, so work continues across context window limits without manual intervention.

---

## Required Permissions

Add these to your `~/.claude/settings.json` under `permissions.allow`. They are global — the relay skills work in any project, so permissions belong in the user settings file, not a project file.

```json
"Bash(bash ~/.claude/commands/relay_watcher.sh)",
"Bash(sed -i*)"
```

**What each covers:**

| Permission | Used by | Purpose |
|---|---|---|
| `Bash(bash ~/.claude/commands/relay_watcher.sh)` | relay-standby | Background polling process that watches relay.md for the wakeup signal |
| `Bash(sed -i*)` | relay-out | Flips the `status:` line in relay.md in-place. The Write tool cannot be used here — it does an atomic rename that generates a filesystem event on the temp file, not on relay.md itself. |

Write, Edit, and Read tool calls made by the relay skills are typically auto-approved and do not require explicit permission entries.

---

## How It Works

Two Claude Code windows are open simultaneously — one active (Worker), one parked (Sleeper). The Worker processes a queue of items. When it hits a configured threshold (N completions, or a named step), it saves state and signals the Sleeper via a file write. The Sleeper detects the signal, picks up the remaining queue, and continues from exactly where the Worker stopped.

The cycle repeats until the queue is empty. After each handoff, the old Worker clears its window and re-parks as the next Sleeper, so the two windows swap roles on every cycle.

### Signal Detection (two stages)

The Sleeper uses a two-stage wakeup process:

1. **Background shell script** (`relay_watcher.sh`) runs via `Bash(run_in_background: true)`. It polls `relay.md` every 20 seconds. When it finds `status: ready`, it writes `RELAY_READY` to an output file and exits.
2. **Sleeper agent** polls that output file every 2-3 minutes using the Read tool. When it finds `RELAY_READY`, it checks relay.md for `status: done` and either stands down or runs `/relay-in`.

The 20-second poll interval is the watcher script's cadence. The 2-3 minute interval is the Sleeper agent's cadence. Both run independently.

---

## Skills Included

| Skill | Invoked as | Purpose |
|-------|-----------|---------|
| relay-standby | `/relay-standby` | Park a window as the Sleeper. Polls for the wakeup signal. |
| relay-out | `/relay-out` | Save progress and hand off to the Sleeper. Writes the wakeup signal last. |
| relay-in | `/relay-in` | Wake up and continue work. Used automatically by relay-standby. |
| relay-check | `/relay-check` | After each completion, check if the threshold is reached and fire relay-out if so. |
| relay-pause | `/relay-pause` | Save progress and stop without handing off. Resume later with /relay-in. |
| relay-halt | `/relay-halt` | Save progress and stop the workflow entirely. Prompts for confirmation. |

All skills live in `~/.claude/commands/` and are available globally in any project.

---

## Files

### Auto-generated (never create manually)

| File | Written by | Purpose |
|------|-----------|---------|
| `relay.md` | relay-out, relay-pause | Wakeup signal and status. `status: ready` wakes the Sleeper. |
| `relay_state.md` | relay skill (header) + your command (body) | Progress contract between Worker and Sleeper. |
| `standing_orders.md` | relay-out, relay-pause | Full context for the next agent to resume without reading other files. |
| `sleeper.flag` | relay-standby | Signals a Sleeper is parked. Worker checks this before firing relay-out. |
| `worker.flag` | relay-out (writes), relay-in (deletes) | Signals the Worker window is done and ready to be re-parked. relay-in deletes it when the new Worker claims the relay. |

### You provide

| File | Purpose |
|------|---------|
| Queue file (any name) | List of items to process, with status tracking |
| `CLAUDE.md` | Defines your command and includes the Relay Contract block (see below) |

---

## relay.md Status Values

| Status | Meaning |
|--------|---------|
| `working` | A Worker is active. Sleeper will not pick up. |
| `ready` | Worker has handed off. Sleeper wakes and runs /relay-in. |
| `paused` | Work stopped, no handoff. Resume with /relay-in. |
| `halted` | Workflow explicitly stopped. Resume with /relay-in. |
| `done` | Batch complete. Sleeper stands down. |

---

## Porting to a New Project

The skill files use `{current working directory}` and `$(pwd)` throughout — no hardcoded paths. They work from any project directory without modification.

The one constraint: both the Sleeper (Window A) and the Worker (Window B) must be launched from the same project root. The Sleeper's background polling process captures `$(pwd)` at spawn time. If the two windows start from different directories, they write and watch different paths and the handoff fails silently.

---

## Setting Up in a New Project

### Step 1 — Define your queue file

Create a queue file with entries in this format (or adapt to your needs):

```
## Entry 1: [Subject Name]
**Source:** [URL or reference]
**Notes:** [anything relevant]
```

Add a status line after research completes:

```
**Status:** PROCESSED (YYYY-MM-DD)
```

### Step 2 — Create a minimal CLAUDE.md

relay-out's Step 4 reads your CLAUDE.md to know which state files to update before handing off. At minimum, your command definition needs to list its state files and include the relay-compatible step.

relay-out also checks `MEMORY.md` for a memory log path and appends a session entry there as the *first* state update before touching any other files. If your project uses the Claude auto-memory system, make sure `MEMORY.md` exists and points to a session log file. If not, relay-out will skip that step silently.

**Bare-bones example for a research batch:**

```markdown
## Commands

### `run research` (Process one queue entry)

State files this command writes to:
- `queue.md` — mark entry PROCESSED when done
- `research_log.md` — append a summary line after each entry

1. Read the next unprocessed entry from queue.md
2. Fetch and analyze the subject
3. Write findings to `research/[subject].md`
4. Mark entry as PROCESSED in queue.md
5. Append a one-line summary to research_log.md
6. If `--relay` is active: write to relay_state.md below the `---` line, then run /relay-check.

### `mass run research`

Runs `run research` on every unprocessed entry in sequence. Supports --relay.

---

[Paste full Relay Contract block here — see below]
```

That is the minimum relay-out needs. Everything else in CLAUDE.md can be built out later.

### Step 3 — Add the Relay Contract to your CLAUDE.md

Paste the full Relay Contract block (below) into your project's `CLAUDE.md` where indicated in the example above.

### Step 4 — Run the workflow

In Window 1 (Sleeper): `/relay-standby`

In Window 2 (Worker): run your batch command with `--relay`

---

## Relay Contract

Paste this block into your project's `CLAUDE.md` verbatim. It defines the configuration phase, the relay_state.md format, and the one rule that makes any command relay-compatible.

---

### Relay Contract (`--relay`)

The `--relay` flag makes any batch or sequential command relay-compatible. The relay skill handles all handoff mechanics. The command only needs to write state.

#### Configuration Phase

When a command is invoked with `--relay` (no N provided), ask the user:

1. **Trigger type:** Relay after N completions, or at a named step?
2. **[Skill reads task structure and reports]** — Queue size or pipeline steps. Suggests a conservative default N or natural step cut points based on where the work is concentrated.
3. **N or step name:** User confirms or overrides the suggestion.
4. **[If sequential command with distinct phases]** — Same threshold for all phases, or configure per phase?
5. **Notification:** Silent relay or notify at each handoff?
6. **[Skill checks sleeper.flag silently]** — If no Sleeper detected: "No Sleeper detected. Park a second agent with /relay-standby before starting, or disable relay."

If `--relay N` is passed directly (delegated from a parent command), skip all config questions and proceed with that N.

#### relay_state.md Format

The relay skill writes the header once at run start. The command writes the body after each completion.

```
---
relay_threshold: 3
relay_trigger: count
relay_notify: silent
relay_task: [your batch command name]
session_completions: 0
---
last_completed: [Subject or entry name]
remaining:
  - [remaining entry 1]
  - [remaining entry 2]
resume_command: [your batch command] --relay [N]
```

For step-based triggers, `relay_threshold` holds a step name instead of a number, and `relay_trigger: step`. `/relay-check` fires when `last_completed` matches the threshold value.

#### Command Contract

Any command becomes relay-compatible by adding one conditional step to its definition:

> If `--relay` is active: write `last_completed`, `remaining`, and `resume_command` to `relay_state.md` below the `---` line, then run `/relay-check`.

This step is additive. All existing state writes the command performs remain unchanged. `relay_state.md` is only written when relay is active. If relay is not active, the command behaves exactly as it did before.

`/relay-check` handles all counting, threshold comparison, and relay-out firing. The command needs no other relay logic.

#### Skip Entries

Before asking whether skipped entries count toward the threshold, the config phase checks whether the command being run has documented skip logic. If it does not, the question is omitted.

---

## Making a Command Relay-Compatible

Here is a minimal example. Your command definition in `CLAUDE.md` should look like this:

```
### `run research` (Process one queue entry)

1. Read the next unprocessed entry from queue.md
2. Fetch and analyze the subject
3. Write output to `research/[subject].md`
4. Update queue.md — mark entry status as PROCESSED
5. If `--relay` is active: write to relay_state.md below the `---` line:
   last_completed: [Subject]
   remaining:
     - [all remaining unprocessed entries]
   resume_command: mass run research --relay [N]
   Then run /relay-check.

### `mass run research` (Batch version)

Runs `run research` on every unprocessed entry in sequence.
Supports --relay flag.
```

That is the entire integration. The relay skills handle everything else.

---

## Typical Session Flow

```
Window A (Sleeper):   /relay-standby
                      [writes sleeper.flag]
                      [launches relay_watcher.sh in background — polls relay.md every 20s]
                      [Sleeper agent polls watcher output file every 2-3 min]

Window B (Worker):    mass run research --relay
                      [config phase: set N=3, silent, threshold confirmed]
                      [processes entry 1] → /relay-check (session_completions: 1, no fire)
                      [processes entry 2] → /relay-check (session_completions: 2, no fire)
                      [processes entry 3] → /relay-check (session_completions: 3 = threshold)
                      [relay-out fires: saves memory, updates state files, writes standing_orders.md]
                      [sed flips relay.md to status: ready]
                      --- HANDOFF COMPLETE ---
                      [Worker: /clear this window, then /relay-standby to re-park]

Window A (Sleeper):   [watcher detects status: ready, writes RELAY_READY to output file]
                      [Sleeper agent reads RELAY_READY on next poll]
                      [checks relay.md — not done, runs /relay-in]
                      Picking up: mass run research --relay 3
                      [deletes sleeper.flag and worker.flag, sets relay.md to working]
                      [processes entries 4, 5, 6 — now acting as Worker]
                      [relay-check fires after entry 6 — hands off to re-parked Window B]

                      [cycle continues, windows swap roles each handoff]
                      [last agent: remaining is empty, relay-check does not fire]
                      [last agent writes relay.md status: done, deletes relay_state.md]
                      Batch complete.

Window B (re-parked): [watcher detects status: done]
                      Batch complete. Standing down.
```

### relay-check: call once per completion

`/relay-check` increments `session_completions` by exactly 1 per call. If you batch two completions before calling it, the counter only reaches 1 — the threshold check fires at the wrong count or misses entirely. Call `/relay-check` immediately after every individual entry completes, without batching.

---

## Recovery Scenarios

### Sleeper arrives after relay-out was blocked

If no `sleeper.flag` was present when the Worker hit its threshold, relay-out aborts and runs `/relay-pause` instead. `relay.md` is left at `status: paused`. All progress is saved to `standing_orders.md`.

To recover:
1. Park a new Sleeper: `/relay-standby` (this writes `sleeper.flag`)
2. In the Sleeper window, run `/relay-in` manually — do not wait for the watcher signal, since `status: paused` will not trigger it automatically
3. The new Sleeper picks up from `standing_orders.md` and continues the batch

The batch is not lost. It just requires a manual `/relay-in` to restart rather than an automatic wakeup.

### Sleeper flag deleted mid-session

If `sleeper.flag` is deleted while a Sleeper is actively parked (e.g., a second agent stood down and took the flag with it), the Sleeper's background watcher is unaffected — it polls `relay.md`, not `sleeper.flag`. The Sleeper will still wake correctly when `status: ready` appears.

The risk is on the Worker side: if the Worker completes its threshold before `sleeper.flag` is restored, it will abort to `/relay-pause` as above.

Fix: re-write `sleeper.flag` with content `parked` before the Worker reaches its next threshold.

---

## AIL Protection

relay-out compares the new `standing_orders.md` against the previous version before writing the wakeup signal. If no progress was made (content unchanged), it does not hand off. Instead it runs `/relay-pause` and flags the user:

> "Possible AIL (Agentic Infinite Loop) detected. This task may exceed the token budget. Progress saved. Stop workflow?"

This prevents agents from endlessly handing off a task that isn't actually advancing.

---

## Queue States (Reference Pattern)

Your queue file should use a consistent status convention. This project uses:

| State | Meaning | Set by |
|-------|---------|--------|
| (none) | Fresh, unprocessed entry | User or discovery |
| `Accessed` | In-progress or researched, awaiting next step | Research command |
| `PROCESSED` | Fully complete | Final command in pipeline |

Adapt the labels to your domain. The relay system does not depend on specific status names — it only reads `remaining` from `relay_state.md`.
