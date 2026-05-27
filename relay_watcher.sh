#!/bin/bash
# Usage: relay_watcher.sh [project_dir]
#
# Prefer calling with NO argument. The script falls back to $(pwd) internally,
# which lets callers (e.g. the relay-standby skill) invoke it as a bare command:
#   bash ~/.claude/commands/relay_watcher.sh
# The Claude Code permission matcher refuses to match allow patterns when the
# invocation contains shell substitution like "$(pwd)" (treated as untrusted),
# so passing the path as an arg causes a permission prompt every run even when
# Bash(bash ~/.claude/commands/relay_watcher.sh:*) is allowed. Resolving $(pwd)
# inside the script avoids the prompt entirely.
RELAY_FILE="${1:-$(pwd)}/relay.md"
while true; do
  grep -q "^status: ready" "$RELAY_FILE" 2>/dev/null && echo "RELAY_READY" && break
  sleep 20
done
