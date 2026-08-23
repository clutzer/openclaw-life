# Migrate Bare-Metal Archie to Containerized OpenClaw Life

> Archie is currently running as a bare-metal `openclaw-gateway` process on the host `archie-agent` (accessible as `openclaw@archie`). Its runtime data lives in `~/.openclaw/` on that host. A containerized scaffold for Archie already exists in `openclaw-life/openclaw-archie/` and has been pushed to `github.com:clutzer/openclaw-archie.git`, but it is not yet configured or launched. The runtime data directory `~/.openclaw-life/data/openclaw-archie/` on the orchestrator host exists but is empty. We need to migrate Archie's data, config, and workspace into the containerized environment and cut over traffic.

## Goal

Stop the bare-metal Archie gateway, migrate all runtime data (except workspace) into the orchestrator's runtime path, sync the git-tracked workspace into `openclaw-archie/workspace/`, adapt the runtime `openclaw.json` for container networking and paths, create a valid `.env`, build and launch the container, and finally verify that Discord and WhatsApp channels respond through the new container before permanently retiring the bare-metal process.

## Execution Order

- [x] [Task 1 — Stop bare-metal gateway and sync runtime data](#task-1--stop-bare-metal-gateway-and-sync-runtime-data)
- [x] [Task 2 — Migrate workspace into repo and push](#task-2--migrate-workspace-into-repo-and-push)
- [x] [Task 3 — Adapt openclaw.json for container and update repo reference](#task-3--adapt-openclawjson-for-container-and-update-repo-reference)
- [x] [Task 4 — Create .env and validate docker-compose config](#task-4--create-env-and-validate-docker-compose-config)
- [x] [Task 5 — Build, launch, and verify container health](#task-5--build-launch-and-verify-container-health)
- [x] [Task 6 — Final cutover and channel verification](#task-6--final-cutover-and-channel-verification)

## Execution Rules

1. Tasks run in their defined order.
2. Tasks run one at a time unless the Executor has an explicit instruction or the
   user said something like "allow parallelism". By default: strictly sequential.
3. Each task executes in a fresh sub-agent. The main agent monitors progress.
4. A task is marked `[x]` in the Execution Order list AND in its own heading only
   after it has been completed AND verified against its Success Criteria.
5. If the main agent detects no forward progress from a sub-agent for 5 minutes,
   it must kill/stop that sub-agent and notify the user immediately.
6. If a task fails, retry it exactly once. If it fails a second time, the task is
   FATAL: halt further work on it, wait for any concurrently running tasks to
   finish, skip all remaining tasks, and produce the summary report.

---

### Task 1 — Stop bare-metal gateway and sync runtime data

- **Status**: `[x] Complete`
- **Objective**: Obtain a clean, consistent snapshot of the bare-metal Archie data by stopping the running gateway on `archie-agent`, then copy everything in `~/.openclaw/` except the `workspace/` directory into the orchestrator's runtime path `~/.openclaw-life/data/openclaw-archie/`.
- **Files to attach**: None
- **Prompt**:
  ````markdown
  **Task**: Task 1 — Stop bare-metal gateway and sync runtime data

  **Context**: Archie runs as a bare-metal process on host `archie-agent` (ssh `openclaw@archie`). Its runtime directory is `~/.openclaw/`. We need to stop it cleanly and sync its non-workspace data into the container runtime directory `~/.openclaw-life/data/openclaw-archie/` on the orchestrator host.

  **DO**:
  1. SSH to `openclaw@archie` and stop the `openclaw-gateway` process (`pkill openclaw-gateway` or `kill <pid>`). Verify it is no longer running with `ps aux | grep openclaw-gateway | grep -v grep`.
  2. Create the target directory if it doesn't exist: `mkdir -p ~/.openclaw-life/data/openclaw-archie`.
  3. Rsync the bare-metal `~/.openclaw/` directory into `~/.openclaw-life/data/openclaw-archie/`, explicitly **excluding** `workspace` so we don't accidentally overwrite the bind-mounted repo workspace later.
     Example command:
     ```bash
     rsync -avz --exclude=workspace --delete openclaw@archie:~/.openclaw/ ~/.openclaw-life/data/openclaw-archie/
     ```
  4. Verify that the target directory now contains at least: `openclaw.json`, `memory/`, `credentials/`, `agents/`, `media/`, `completions/`, `flows/`, `tasks/`, `cron/`, `canvas/`, `devices/`, `logs/`, `identity/`, `qqbot/`, `exec-approvals.json`, and `update-check.json`.

  **DO NOT**:
  - Delete the bare-metal `~/.openclaw/` directory (we may need it for rollback).
  - Sync the `workspace/` directory in this step (that is Task 2).
  - Commit any of this data to Git (it is runtime-only and bind-mounted via a named/volume path, not the repo).

  **Success Criteria**:
  - [ ] No `openclaw-gateway` process is running on `openclaw@archie`.
  - [ ] `~/.openclaw-life/data/openclaw-archie/` exists and contains the expected runtime files and directories (excluding `workspace`).
  - [ ] `ls -la ~/.openclaw-life/data/openclaw-archie/openclaw.json` returns the file.

  **Rollback**:
  If anything goes wrong, restart the bare-metal gateway on `archie-agent` by running the same startup command used previously (check `.bash_history` if needed).
  ````
- **Rollback**: Restart the bare-metal `openclaw-gateway` process on `archie-agent`.

---

### Task 2 — Migrate workspace into repo and push

- **Status**: `[x] Complete`
- **Objective**: Replace the placeholder `workspace/` in `openclaw-archie/` with the real workspace content from the bare-metal host, commit it, and push to the remote.
- **Files to attach**:
  - `openclaw-life/openclaw-archie/workspace/README.md` (current placeholder)
- **Prompt**:
  ````markdown
  **Task**: Task 2 — Migrate workspace into repo and push

  **Context**: The local repo `openclaw-life/openclaw-archie/` currently only has a placeholder `workspace/README.md`. The real workspace lives on the bare-metal host at `openclaw@archie:~/.openclaw/workspace/`. We need to sync that content into the repo directory, commit, and push.

  **DO**:
  1. Remove the placeholder `workspace/README.md` from `openclaw-life/openclaw-archie/workspace/`.
  2. Rsync the bare-metal workspace into the repo workspace:
     ```bash
     rsync -avz --delete openclaw@archie:~/.openclaw/workspace/ openclaw-life/openclaw-archie/workspace/
     ```
  3. Verify the repo workspace now contains: `AGENTS.md`, `HEARTBEAT.md`, `IDENTITY.md`, `SOUL.md`, `TOOLS.md`, `USER.md`, `memory/`, `state/`, and `.openclaw/workspace-state.json`.
  4. Stage everything:
     ```bash
     cd openclaw-life/openclaw-archie
     git add workspace/
     git commit -m "Task 2: Migrate archie workspace from bare metal"
     git push origin main
     ```

  **DO NOT**:
  - Sync the `.git` directory from the bare-metal workspace into the repo (the repo already has its own `.git` at the `openclaw-archie` root).
  - Include any secrets or tokens in the commit (the workspace docs should not contain them; if they do, redact first).

  **Success Criteria**:
  - [ ] `openclaw-life/openclaw-archie/workspace/` contains the expected files from the bare-metal host.
  - [ ] `git status` inside `openclaw-archie/` is clean (nothing unstaged/uncommitted).
  - [ ] The latest commit on `origin/main` is the workspace migration commit.

  **Rollback**:
  ```bash
  cd openclaw-life/openclaw-archie
  git revert HEAD --no-edit
  git push origin main
  ```
  ````
- **Rollback**: `git revert HEAD --no-edit` in `openclaw-archie/` and push.

---

### Task 3 — Adapt openclaw.json for container and update repo reference

- **Status**: `[x] Complete`
- **Objective**: Update the runtime `openclaw.json` copied in Task 1 so it works inside the Docker container (user `node`, paths, gateway bind), then copy the adapted file into the repo as a reference and commit.
- **Files to attach**:
  - `openclaw-life/openclaw-archie/docker-compose.yml`
  - `openclaw-life/openclaw-luna/openclaw.json` (reference for containerized config)
- **Prompt**:
  ````markdown
  **Task**: Task 3 — Adapt openclaw.json for container and update repo reference

  **Context**: The bare-metal `openclaw.json` was copied to `~/.openclaw-life/data/openclaw-archie/openclaw.json` in Task 1. It was written for a bare-metal user (`openclaw`) and binds to `loopback`. Inside the container, the user is `node`, `HOME` is `/home/node`, and the gateway must bind to `lan` so Traefik can reach it on port `18789`.

  **DO**:
  1. Read `~/.openclaw-life/data/openclaw-archie/openclaw.json`.
  2. Make the following minimal, precise edits:
     - Change `gateway.bind` to `"lan"`.
     - Ensure `gateway.port` is `18789`.
     - Ensure `gateway.controlUi.allowInsecureAuth` is `true` (required for Traefik WebSocket reverse proxying per `docker-compose.yml` comments).
     - Change `logging.file` from `/home/openclaw/.openclaw/gateway.log` to `/home/node/.openclaw/gateway.log`.
     - If there are any other absolute paths referencing `/home/openclaw/`, change them to `/home/node/`.
     - If `gateway.trustedProxies` is missing or empty, add `["172.18.0.0/16"]` so the Traefik Docker network is trusted.
     - Do NOT change model provider `baseUrl` values unless you verify the container cannot reach `http://10.0.0.2:8080`. If the orchestrator host can reach `10.0.0.2`, the container on the same host should too.
  3. Copy the adapted file into the repo:
     ```bash
     cp ~/.openclaw-life/data/openclaw-archie/openclaw.json openclaw-life/openclaw-archie/openclaw.json
     ```
  4. Commit and push the repo copy:
     ```bash
     cd openclaw-life/openclaw-archie
     git add openclaw.json
     git commit -m "Task 3: Adapt runtime config for containerized archie"
     git push origin main
     ```

  **DO NOT**:
  - Add secrets (API keys, tokens) into the JSON. Keep them as `${ENV_VAR}` references.
  - Break the JSON syntax. Validate with `python3 -m json.tool` or `jq` before saving.

  **Success Criteria**:
  - [ ] Runtime `~/.openclaw-life/data/openclaw-archie/openclaw.json` has `gateway.bind` set to `"lan"`.
  - [ ] Runtime config has `logging.file` pointing to `/home/node/.openclaw/gateway.log`.
  - [ ] `python3 -m json.tool ~/.openclaw-life/data/openclaw-archie/openclaw.json > /dev/null` passes (valid JSON).
  - [ ] Repo copy `openclaw-life/openclaw-archie/openclaw.json` exists, is valid JSON, and has been pushed.

  **Rollback**:
  If a backup `openclaw.json.bak` exists in the runtime directory, restore it:
  ```bash
  cp ~/.openclaw-life/data/openclaw-archie/openclaw.json.bak ~/.openclaw-life/data/openclaw-archie/openclaw.json
  ```
  Then revert the repo commit if it was already pushed.
  ````
- **Rollback**: Restore from `openclaw.json.bak` in the runtime directory if present; otherwise, manually revert the edits. Revert the git commit in the repo if needed.

---

### Task 4 — Create .env and validate docker-compose config

- **Status**: `[x] Complete`
- **Objective**: Create `openclaw-life/openclaw-archie/.env` from the template, populate it with the correct values for Archie, and validate the compose file.
- **Files to attach**:
  - `openclaw-life/openclaw-archie/example.env`
  - `openclaw-life/openclaw-archie/docker-compose.yml`
  - `openclaw-life/openclaw-archie/openclaw.json` (to inspect which env vars are referenced)
- **Prompt**:
  ````markdown
  **Task**: Task 4 — Create .env and validate docker-compose config

  **Context**: The containerized archie needs a `.env` file in `openclaw-life/openclaw-archie/`. It is already `.gitignore`d. We must derive the correct values, especially secrets, and validate that `docker compose config` parses correctly.

  **DO**:
  1. Check whether `openclaw-life/openclaw-archie/.env` already exists on disk. If it does, preserve all existing values and do NOT copy `example.env` over it (that would wipe existing secrets). If it does not exist, copy `openclaw-life/openclaw-archie/example.env` to `openclaw-life/openclaw-archie/.env`.
  2. Ensure the following variables are set (add/update only the ones listed; leave any other existing values untouched):
     - `OPENCLAW_NAME=archie`
     - `OPENCLAW_HOSTNAME=archie.home.teknibauer.com` (already known).
     - `USER_ID` and `GROUP_ID`: Run `id -u` and `id -g` on the orchestrator host and use those values.
     - `TZ=America/New_York` (or whatever matches the existing bare-metal host; check `timedatectl` or `date` on `openclaw@archie` if uncertain).
     - `OPENCLAW_GATEWAY_TOKEN`, `INFERENCE_GATEWAY_TOKEN`, `DISCORD_BOT_TOKEN`: Try to discover these from the bare-metal host. Check:
       - `ssh openclaw@archie 'cat ~/.bashrc ~/.profile 2>/dev/null | grep -E "(TOKEN|token)"'`
       - Any systemd user unit files (`systemctl --user list-unit-files` and inspect units).
       - The process environment (`cat /proc/$(pgrep -f openclaw-gateway)/environ 2>/dev/null | tr '\0' '\n'`) — this may be empty if not root, but try.
       - `.bash_history` for the export command used to start the gateway.
       If you cannot find a value, leave it as an empty assignment and **report the missing variable to the user**.
     - `WHATSAPP_PHONE_ME`: The runtime `openclaw.json` references this variable but `example.env` does not include it. Add `WHATSAPP_PHONE_ME=` to `.env` and populate it if you can find the value on the bare-metal host.
  3. Ensure `.env` is NOT added to git.
  4. Validate the compose configuration:
     ```bash
     cd openclaw-life/openclaw-archie
     docker compose config > /dev/null
     ```

  **DO NOT**:
  - Commit `.env`.
  - Invent fake tokens or hostnames.

  **Success Criteria**:
  - [ ] `openclaw-life/openclaw-archie/.env` exists and contains `OPENCLAW_NAME=archie` and `OPENCLAW_HOSTNAME=archie.home.teknibauer.com`.
  - [ ] `docker compose config` exits with code 0.
  - [ ] All referenced `${...}` environment variables in `docker-compose.yml` have a corresponding line in `.env` (even if empty).
  - [ ] Any variables that could not be discovered are explicitly reported to the user.

  **Rollback**:
  Delete `.env`:
  ```bash
  rm openclaw-life/openclaw-archie/.env
  ```
  ````
- **Rollback**: Delete `openclaw-archie/.env`.

---

### Task 5 — Build, launch, and verify container health

- **Status**: `[x] Complete`
- **Objective**: Build the Docker image, start the `openclaw-archie` container, and verify it passes its healthcheck and starts without fatal config errors.
- **Files to attach**:
  - `openclaw-life/openclaw-archie/docker-compose.yml`
- **Prompt**:
  ````markdown
  **Task**: Task 5 — Build, launch, and verify container health

  **Context**: All data, config, and secrets are in place. We need to build the custom image (which fixes UID/GID) and start the container.

  **DO**:
  1. Build and start the container:
     ```bash
     cd openclaw-life/openclaw-archie
     docker compose up -d --build
     ```
  2. Wait ~30 seconds, then check container status:
     ```bash
     docker ps --filter "name=openclaw-archie" --format "table {{.Names}}\t{{.Status}}\t{{.Health}}"
     ```
  3. Read the last ~100 lines of logs:
     ```bash
     docker logs --tail 100 openclaw-archie
     ```
     Look for:
     - "gateway listening"
     - "healthcheck" passes
     - No fatal configuration parse errors
     - No provider connection errors (warnings are okay if transient)
  4. Verify the health endpoint from inside the container network:
     ```bash
     docker exec openclaw-archie node -e "fetch('http://127.0.0.1:18789/healthz').then(r => console.log(r.status, r.ok)).catch(e => console.error(e))"
     ```

  **DO NOT**:
  - Run `docker compose up -d` without `--build` on the first launch (the image needs the UID/GID build args).
  - Restart or edit the bare-metal host in this task.

  **Success Criteria**:
  - [ ] `docker ps` shows `openclaw-archie` as `Up` and `healthy` (or at least `Up`).
  - [ ] `docker logs` shows the gateway starting without fatal errors.
  - [ ] The healthcheck fetch returns `200 true`.

  **Rollback**:
  ```bash
  cd openclaw-life/openclaw-archie
  docker compose down
  ```
  ````
- **Rollback**: `docker compose down` in `openclaw-archie/`.

---

### Task 6 — Final cutover and channel verification

- **Status**: `[x] Complete`
- **Objective**: Ensure the bare-metal gateway cannot restart, and verify that the containerized Archie actually responds to real traffic (Discord, WhatsApp, Gateway UI).
- **Files to attach**:
  - `openclaw-life/openclaw-archie/openclaw.json`
  - `openclaw-life/openclaw-archie/docker-compose.yml`
- **Prompt**:
  ````markdown
  **Task**: Task 6 — Final cutover and channel verification

  **Context**: The container is running. We must make the cutover permanent and verify end-to-end functionality.

  **DO**:
  1. SSH to `openclaw@archie` and confirm `openclaw-gateway` is not running. If it is, stop it again.
  2. Remove any autostart mechanism so it doesn't come back on reboot:
     - Check for a systemd user service (`systemctl --user list-unit-files | grep openclaw`). If found, disable and stop it.
     - Check `~/.bashrc`, `~/.profile`, or cron (`crontab -l`) for startup commands. Remove or comment them out.
  3. Verify DNS / routing:
     - Confirm that the `OPENCLAW_HOSTNAME` defined in `.env` resolves to the host running the `openclaw-life` Traefik proxy. If unsure, check with the user.
  4. Verify channels:
     - **Discord**: Send a message in an allowed channel. The bot should respond via the container. Check `docker logs --tail 50 openclaw-archie` for activity.
     - **WhatsApp**: If configured, send a message to the allowed number and verify a response.
     - **Gateway UI**: Open `https://<OPENCLAW_HOSTNAME>` in a browser and confirm the Control UI loads.
  5. If all channels respond, the migration is complete.

  **DO NOT**:
  - Delete the bare-metal `~/.openclaw/` directory yet (keep it as a cold backup for a few days).

  **Verification Results (Automated)**:
  - [x] Container `openclaw-archie` is `Up` and reports `healthy`.
  - [x] Health endpoint `http://127.0.0.1:18789/healthz` returns `200 true`.
  - [x] Traefik router `archie@docker` is `enabled` on `websecure` with TLS certresolver `linode-resolver`.
  - [x] Traefik service `archie@docker` is `enabled` with server `http://172.18.0.5:18789` status `UP`.
  - [x] Docker network `openclaw-life-net` subnet `172.18.0.0/16` matches `gateway.trustedProxies`.
  - [x] Discord provider connected successfully (`logged in to discord as 1491545421775114431 (Archie)`).
  - [~] WhatsApp session requires re-authentication (see action items below).

  **Manual Action Items Remaining**:
  - [x] **Bare-metal cleanup**: Verified — no `openclaw-gateway` process running; autostart disabled.
  - [x] **WhatsApp has been FULLY REMOVED from the container configuration** (per user request). This action item is no longer applicable.
    - WhatsApp channel block removed from `openclaw.json` (runtime + repo).
    - WhatsApp env var and comment removed from `.env`.
    - WhatsApp credential directory `credentials/whatsapp/` deleted.
    - WhatsApp session entries purged from `agents/main/sessions/sessions.json`.
    - Container restarted; `gateway ready` now shows 6 plugins (was 7; `whatsapp` absent).
  - [x] **Discord live test**: Verified — bot responds to messages using `inference-server/deepseek-ai/deepseek-v4-flash-0731`.
  - [x] **Gateway UI test**: Verified — `https://archie.home.teknibauer.com` loads the Control UI.

  **Success Criteria**:
  - [x] No `openclaw-gateway` process on `openclaw@archie`.
  - [x] No autostart mechanism remains on the bare-metal host.
  - [x] Discord bot responds to a test message.
  - [x] Gateway Control UI is reachable via the public hostname.

  **Rollback**:
  If verification fails and the bare-metal data is intact, you can stop the container (`docker compose down` in `openclaw-archie/`) and restart the bare-metal gateway on `archie-agent`. Fix the issue and re-run Tasks 4–6.
  ````
- **Rollback**: Stop the container (`docker compose down`), and restart the bare-metal `openclaw-gateway` process.

---

## Summary of Expected Final State

- The bare-metal host `archie-agent` no longer runs an `openclaw-gateway` process and has no autostart for it.
- `~/.openclaw-life/data/openclaw-archie/` contains all migrated runtime data (memory DB, credentials, agents, media, etc.) with an `openclaw.json` adapted for the container.
- `openclaw-life/openclaw-archie/workspace/` contains the migrated workspace docs, committed and pushed to `origin/main`.
- `openclaw-life/openclaw-archie/openclaw.json` is a valid, tracked reference copy in the repo.
- `openclaw-life/openclaw-archie/.env` exists, is gitignored, and contains all required variables.
- `openclaw-archie` container is `Up (healthy)` on the `openclaw-life-net` network, reachable via Traefik at its public hostname.
- Discord and WhatsApp channels route through the container and Archie responds to messages.
