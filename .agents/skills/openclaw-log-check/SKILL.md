---
name: openclaw-log-check
description: >-
  Quickly scan all OpenClaw instance containers for errors, warnings, and
  failures in their logs. Use this skill when the user asks to check agent
  logs, audit for errors, tail logs, or review log health across the fleet.
---

# OpenClaw Log Check

A focused, fast log audit across all running OpenClaw instances. This skill
performs surface-level scanning only — it finds errors and reports them.
If errors are found, the user can escalate to `openclaw-ops` for deep
troubleshooting and repair.

## Fleet Discovery

1. List all `openclaw-*` directories in the project root.
2. **Exclude** `openclaw-sample/` — it is a template, not a running instance.
3. Map remaining directories to their container names (`openclaw-<NAME>`).

## Log Audit Steps

1. **Check container status**
   - Run `docker ps -a --filter "name=openclaw-<NAME>"` for each instance.
   - Note any containers that are `Exited`, `Restarting`, or missing.

2. **Scan logs for errors**
   - For each running container, run:
     ```bash
     docker logs --since "24h" openclaw-<NAME> 2>&1 | \
       grep -iE "error|fail|timeout|connection refused|ECONN|model_not_found|502|503|504"
     ```
   - Adjust `--since` to a shorter window (e.g. `--since "1h"`) if the user
     asks for a recent check only.
   - If a container was recently restarted, also scan logs since the restart
     time to confirm the new run is clean.

3. **Summarize findings**
   - Report per instance concisely:
     - ✅ **Clean** — no error patterns found in the scanned window.
     - ⚠️ **Errors found** — show timestamps, error type, and brief excerpts.
   - Distinguish actual failures from expected noise (e.g. routine Discord
     websocket reconnects are usually harmless).

4. **Escalation**
   - If errors are found and the user wants to investigate root causes, load
     the `openclaw-ops` skill.
