---
name: openclaw-audit
description: >-
  Perform a comprehensive, repeatable configuration audit of an OpenClaw
  instance (e.g. openclaw-nia). Produces a timestamped markdown report in
  openclaw-life/docs/ covering crons, Discord channels, delivery targets,
  sessions, security posture, plugins, skills, models, and outstanding issues.
---

# OpenClaw Instance Audit

## Goal

Produce a timestamped snapshot of a single OpenClaw instance's live
configuration so an operator can reason declaratively about desired state
and detect drift over time.

## Identify the Instance

1. Determine the instance name `<NAME>` from context (directory
   `openclaw-<NAME>/`).
2. Verify the container is running:
   ```bash
   docker ps -a --filter "name=openclaw-<NAME>"
   ```
3. Confirm the runtime config path:
   ```bash
   ~/.openclaw-life/data/openclaw-<NAME>/openclaw.json
   ```

## Data Collection

Run the following **inside the container** (`docker exec openclaw-<NAME>`) and
capture stdout/stderr to temporary files on the host for later analysis.

| Data | Command |
|---|---|
| Deep status | `openclaw status --deep` |
| Cron list | `openclaw cron list` |
| Cron details | For each job ID, `openclaw cron show <id>` |
| Channel status | `openclaw channels status` |
| Plugins | `openclaw plugins list` |
| Skills | `openclaw skills list` |
| Sessions | `openclaw sessions list` |
| Security audit | `openclaw security audit` |
| Runtime config | `cat ~/.openclaw-life/data/openclaw-<NAME>/openclaw.json` |

> **Tip:** Redirect container output to files in `/tmp` on the host and read
> them back, rather than trying to parse streaming multi-line output in one
> step.

## Report Structure

Parse the collected data into a markdown report with the following sections.
Use tables where possible for scannability.

### 1. Gateway Health

| Item | Value |
|---|---|
| Status | Reachable / unhealthy / down |
| Version | e.g. 2026.9.1 |
| Update available | Yes / No |
| Dashboard URL | e.g. `http://172.18.0.5:18789/` |
| Sessions | Count |
| Tasks | active / queued / issues |
| Memory | enabled plugin and checked state |
| Backups | recorded / none |

### 2. Discord Configuration

- Channel state (enabled, OK, token masked)
- Guild and channel ID tables from `openclaw.json`
- `requireMention` policy per guild
- User allowlists

### 3. Automations (Crons)

| ID | Name | Schedule | Target | Delivery | Agent | Last | Status |
|---|---|---|---|---|---|---|---|
| `...` | Heartbeat (main) | every 30m | `main` | **not requested** | `main` | 14m ago | ok |
| `...` | Daily Brief | cron `0 7 * * *` | isolated | `announce` → `discord:channel:...` | `main` | 7h ago (delivered) | ok |

Also produce a **delivery map**:

| Channel / User ID | Gets output from |
|---|---|
| `1494337230620066033` | Luna Handoff Sync (mode: `none`) |
| `1495097248407752844` | Daily Comprehensive Brief (mode: `announce`) |
| `866367817964322816` | Trash Reminder DM (mode: `announce`) |

### 4. Models & Providers

| Role | Provider | Model | Context | Reasoning |
|---|---|---|---|---|
| Primary | `inference-server` | `deepseek-ai/...` | 1.0M / 1048576 | yes |
| Fallback | ... | ... | ... | ... |
| Embedding | ... | ... | — | — |

### 5. Skills

Ready vs disabled summary. Call out notable enabled skills and anything stuck
in `needs setup`.

### 6. Plugins

Key enabled plugins (Discord, memory-core, browser, etc.) and any explicitly
disabled ones relevant to the instance's role.

### 7. Active Sessions

Summarize session kinds (direct, group, cron, slash), ages, and the model
backing each.

### 8. Security Audit Findings

| Severity | Finding | Suggested Fix |
|---|---|---|
| 🔴 CRITICAL | `hooks.allowedAgentIds = '*'` | Explicit allowlist |
| 🟡 WARN | No auth rate limit | Add `gateway.auth.rateLimit` |

### 9. Outstanding Issues & Notes

- Automations with no delivery route
- Tasks with issues (`openclaw tasks` when in doubt)
- Missing backups
- Recent crashes (stability bundles in `logs/stability/`)
- Config drift or recent agent edits to runtime `openclaw.json`

## Write the Report

Save to:

```
openclaw-life/openclaw-<NAME>/audits/<NAME>-audit-YYYY-MM-DD.md
```

This places the report in the instance's own workspace directory, which is
naturally excluded from Git by the existing `openclaw-*/` ignore rule.

Use the current UTC date. **Do not overwrite** if a file with that name
already exists; append `-HHMM` or a counter instead.

Example:
```
nia-audit-2026-09-07.md
nia-audit-2026-09-07-1630.md
```

This policy ensures historical snapshots survive and can be diffed.

## Deliverable

1. The markdown file is written to `docs/`.
2. A concise summary (headline table) is presented to the user.
3. If the user wants to proceed to **declare target state**, the audit is
   the baseline for the next step.
