---
name: openclaw-health-check
description: >-
  Perform a quick health check across all OpenClaw instance containers.
  Use this skill when the user asks to check agent health, status, or logs,
  audit for errors, or review whether the fleet is running cleanly.
---

# OpenClaw Fleet Health Check

A focused, fast health check across all OpenClaw instances. Verifies that
containers are running and scans their recent logs for errors, warnings,
and failures. This skill performs surface-level scanning only — it reports
what it finds. If errors are present, the user can escalate to `openclaw-ops`
for deep troubleshooting and repair.

## Fleet Discovery

1. List all `openclaw-*` directories in the project root.
2. **Exclude** `openclaw-sample/` — it is a template, not a running instance.
3. Map remaining directories to their container names (`openclaw-<NAME>`).

## Health Check Steps

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
     - ✅ **Healthy** — container is running and no error patterns found.
     - ⚠️ **Degraded** — container is running but errors were found in logs.
     - ❌ **Down/Unhealthy** — container is stopped, restarting, or missing.
   - Distinguish actual failures from expected noise (e.g. routine Discord
     websocket reconnects are usually harmless).

4. **Escalation**
   - If errors are found and the user wants to investigate root causes, load
     the `openclaw-ops` skill.
