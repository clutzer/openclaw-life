# Modernize Archie's openclaw.json for OpenClaw Life Infrastructure

> **Completed**: 2026-08-23

> Archie's containerized `openclaw.json` was migrated from bare-metal but still uses the legacy `vllm` provider at `http://10.0.0.2:8080`. The modern OpenClaw Life stack uses `inference-server` at `https://inference.labs.ai.linode.com/v1`, structured agent model declarations, cloud-hosted embedding, and a minimal config surface. Luna's config already reflects this modern shape. We need to bring Archie's runtime and repo reference configs into alignment without changing instance-specific Discord channels or security settings.

## Goal

Align Archie's config with OpenClaw Life inference-server topology and verify clean boot.

## Execution Order

- [x] [Task 1 — Replace vLLM provider and modernize model architecture](#task-1--replace-vllm-provider-and-modernize-model-architecture)
- [x] [Task 2 — Update memory search to cloud endpoint and add memorybackend](#task-2--update-memory-search-to-cloud-endpoint-and-add-memorybackend)
- [x] [Task 3 — Standardize gatewaycontroluiallowedorigins](#task-3--standardize-gatewaycontroluiallowedorigins)
- [x] [Task 4 — Validate commit restart and verify](#task-4--validate-commit-restart-and-verify)

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

### Task 1 — Replace vLLM provider and modernize model architecture

- **Status**: `[x] Complete`
- **Files to attach**:
  - `data/openclaw-archie/openclaw.json`
  - `data/openclaw-luna/openclaw.json`
  - `openclaw-archie/openclaw.json`
- **Prompt**:
  ````markdown
  **Task**: Task 1 — Replace vLLM provider and modernize model architecture

  **Context**: Archie's runtime config at `data/openclaw-archie/openclaw.json` still uses:
  - `models.mode: "merge"`
  - `models.providers.vllm` pointing to `http://10.0.0.2:8080/v1/brain`
  - `agents.defaults.model` as a plain string `"vllm/gemma-4-31b-it"`
  - `plugins.entries.vllm.enabled: true`

  Luna's modern config (`data/openclaw-luna/openclaw.json`) uses `models.providers.inference-server` at `https://inference.labs.ai.linode.com/v1`, with two models (DeepSeek primary, Gemma fallback), structured agent model declarations, and `plugins.entries.google.enabled: true`.

  **DO**:
  1. Read `data/openclaw-luna/openclaw.json` to confirm the exact target structure for `models.providers.inference-server`, `agents.defaults.model`, and `plugins`.
  2. Edit `data/openclaw-archie/openclaw.json` using a Python script via `terminal` so JSON syntax is preserved. Make these exact changes:
     - Remove the top-level key `models.mode` entirely.
     - Replace the `models.providers.vllm` block with `models.providers.inference-server`, copying the exact shape from Luna including baseUrl `https://inference.labs.ai.linode.com/v1`, auth `api-key`, apiKey `${INFERENCE_GATEWAY_TOKEN}`, api `openai-completions`, and both model definitions (DeepSeek V4 Flash and Gemma 4 31B IT NVFP4) with cost blocks.
     - Replace `agents.defaults.model` (currently the string `"vllm/gemma-4-31b-it"`) with a structured object:
       ```json
       "agents": {
         "defaults": {
           "model": {
             "primary": "inference-server/google/gemma-4-31b-it-nvfp4",
             "fallbacks": [
               "inference-server/deepseek-ai/deepseek-v4-flash-0731"
             ]
           }
         }
       }
       ```
       This preserves Archie's current primary model family while enabling the fallback mechanism.
     - In `plugins.entries`, remove `vllm` and add `google` with `"enabled": true`.
  3. Validate the modified runtime JSON:
     ```bash
     python3 -m json.tool data/openclaw-archie/openclaw.json > /dev/null
     ```
  4. Copy the validated file to the repo reference:
     ```bash
     cp data/openclaw-archie/openclaw.json openclaw-archie/openclaw.json
     ```
  5. Validate the repo copy too.

  **DO NOT**:
  - Change Discord channel configuration (`channels.discord`).
  - Change `gateway.bind`, `gateway.port`, `gateway.trustedProxies`, `gateway.auth`, or `gateway.mode`.
  - Remove `tools`, `commands`, `session`, `discovery`, `logging`, or `wizard` sections.
  - Touch `.env` or any secrets.

  **Success Criteria**:
  - [ ] `data/openclaw-archie/openclaw.json` contains `models.providers.inference-server` and does NOT contain `models.providers.vllm`.
  - [ ] `data/openclaw-archie/openclaw.json` does NOT contain `models.mode`.
  - [ ] `agents.defaults.model` is a structured object with `primary` and `fallbacks` keys.
  - [ ] `plugins.entries.google.enabled` is `true` and `plugins.entries.vllm` is absent.
  - [ ] Both JSON files parse successfully with `python3 -m json.tool`.

  **Rollback**:
  ```bash
  cp data/openclaw-archie/openclaw.json.bak data/openclaw-archie/openclaw.json 2>/dev/null || echo "No .bak found"
  # If no .bak exists, revert from the repo copy:
  git checkout openclaw-archie/openclaw.json
  cp openclaw-archie/openclaw.json data/openclaw-archie/openclaw.json
  ```
  ````
- **Rollback**: Restore from `data/openclaw-archie/openclaw.json.bak` if present; otherwise `git checkout openclaw-archie/openclaw.json` and copy back to runtime.

---

### Task 2 — Update memory search to cloud endpoint and add memory.backend

- **Status**: `[x] Complete`
- **Files to attach**:
  - `data/openclaw-archie/openclaw.json`
  - `data/openclaw-luna/openclaw.json`
- **Prompt**:
  ````markdown
  **Task**: Task 2 — Update memory search to cloud endpoint and add memory.backend

  **Context**: Archie's current `agents.defaults.memorySearch` points to `http://10.0.0.2:8080/v1/memory` with model `qwen3-embedding-8b` and a hardcoded `"not-required"` API key. Luna uses `https://inference.labs.ai.linode.com/v1`, model `qwen/qwen3-embedding-8b-fp16`, and `${INFERENCE_GATEWAY_TOKEN}`. Additionally, Luna has `memory.backend: "builtin"`, which Archie lacks.

  **DO**:
  1. Edit `data/openclaw-archie/openclaw.json` using a Python script via `terminal`:
     - Change `agents.defaults.memorySearch.remote.baseUrl` to `https://inference.labs.ai.linode.com/v1`.
     - Change `agents.defaults.memorySearch.remote.apiKey` from `"not-required"` to `"${INFERENCE_GATEWAY_TOKEN}"`.
     - Change `agents.defaults.memorySearch.model` from `"qwen3-embedding-8b"` to `"qwen/qwen3-embedding-8b-fp16"`.
     - Add a top-level `memory` object with `"backend": "builtin"` (sibling to `models`, `agents`, etc.).
  2. Validate the modified JSON:
     ```bash
     python3 -m json.tool data/openclaw-archie/openclaw.json > /dev/null
     ```
  3. Copy the validated file to the repo reference:
     ```bash
     cp data/openclaw-archie/openclaw.json openclaw-archie/openclaw.json
     ```
  4. Validate the repo copy.

  **DO NOT**:
  - Change any other part of the config (this task only touches memory search and the new `memory` key).
  - Touch `.env`.

  **Success Criteria**:
  - [ ] `agents.defaults.memorySearch.remote.baseUrl` is `https://inference.labs.ai.linode.com/v1`.
  - [ ] `agents.defaults.memorySearch.remote.apiKey` is `"${INFERENCE_GATEWAY_TOKEN}"`.
  - [ ] `agents.defaults.memorySearch.model` is `"qwen/qwen3-embedding-8b-fp16"`.
  - [ ] Top-level `memory.backend` is `"builtin"`.
  - [ ] Both JSON files parse successfully.

  **Rollback**:
  ```bash
  cp data/openclaw-archie/openclaw.json.bak data/openclaw-archie/openclaw.json 2>/dev/null || echo "No .bak found"
  git checkout openclaw-archie/openclaw.json
  cp openclaw-archie/openclaw.json data/openclaw-archie/openclaw.json
  ```
  ````
- **Rollback**: Restore from `.bak` or repo copy.

---

### Task 3 — Standardize gateway.controlUi.allowedOrigins

- **Status**: `[x] Complete`
- **Files to attach**:
  - `data/openclaw-archie/openclaw.json`
  - `data/openclaw-luna/openclaw.json`
- **Prompt**:
  ````markdown
  **Task**: Task 3 — Standardize gateway.controlUi.allowedOrigins

  **Context**: Archie's `gateway.controlUi.allowedOrigins` currently lists `http://localhost:18789` and `http://127.0.0.1:18789`. Luna uses `["https://${OPENCLAW_HOSTNAME}"]`. Since Traefik routes external traffic through the public hostname, matching this pattern is cleaner for a containerized deployment.

  **DO**:
  1. Edit `data/openclaw-archie/openclaw.json` using a Python script via `terminal`:
     - Change `gateway.controlUi.allowedOrigins` from the localhost list to `["https://${OPENCLAW_HOSTNAME}"]`.
     - Leave `gateway.controlUi.allowInsecureAuth` as `true`.
  2. Validate and copy to repo reference:
     ```bash
     python3 -m json.tool data/openclaw-archie/openclaw.json > /dev/null
     cp data/openclaw-archie/openclaw.json openclaw-archie/openclaw.json
     python3 -m json.tool openclaw-archie/openclaw.json > /dev/null
     ```

  **DO NOT**:
  - Change `gateway.bind`, `gateway.port`, `gateway.trustedProxies`, `gateway.auth`, `gateway.mode`, or `gateway.reload`.

  **Success Criteria**:
  - [ ] `gateway.controlUi.allowedOrigins` is `["https://${OPENCLAW_HOSTNAME}"]`.
  - [ ] `gateway.controlUi.allowInsecureAuth` remains `true`.
  - [ ] Both JSON files parse successfully.

  **Rollback**:
  ```bash
  git checkout openclaw-archie/openclaw.json
  cp openclaw-archie/openclaw.json data/openclaw-archie/openclaw.json
  ```
  ````
- **Rollback**: Restore from repo copy.

---

### Task 4 — Validate, commit, restart, and verify

- **Status**: `[x] Complete`
- **Files to attach**:
  - `openclaw-archie/openclaw.json`
  - `openclaw-archie/docker-compose.yml`
- **Prompt**:
  ````markdown
  **Task**: Task 4 — Validate, commit, restart, and verify

  **Context**: The runtime config has been aligned with modern OpenClaw Life. Now it must be committed, the container restarted, and the boot logs verified to confirm the gateway loads `inference-server`, resolves models, connects to Discord, and does not attempt to load the deprecated `vllm` provider.

  **DO**:
  1. Ensure the repo copy `openclaw-archie/openclaw.json` is the validated current state.
  2. Verify `.env` contains `INFERENCE_GATEWAY_TOKEN` (grep it; if missing, report to the user and halt):
     ```bash
     grep "^INFERENCE_GATEWAY_TOKEN=" openclaw-archie/.env
     ```
  3. Commit and push the repo copy:
     ```bash
     cd openclaw-archie
     git add openclaw.json
     git commit -m "Task 4: Modernize archie openclaw.json for inference-server"
     git push origin main
     ```
  4. Restart the container:
     ```bash
     cd openclaw-archie
     docker compose up -d
     ```
  5. Wait ~20 seconds, then check logs:
     ```bash
     docker logs --tail 50 openclaw-archie
     ```
     Look for:
     - "gateway ready" with a plugin count that does NOT include `whatsapp` (it was removed earlier)
     - A model reference that includes `inference-server/` (e.g. `inference-server/google/gemma-4-31b-it-nvfp4`)
     - Discord provider logged in successfully (`logged in to discord as 1491545421775114431`)
     - No errors about `vllm`, `10.0.0.2`, or provider connection failures
  6. Verify health endpoint:
     ```bash
     docker exec openclaw-archie node -e "fetch('http://127.0.0.1:18789/healthz').then(r => console.log(r.status, r.ok)).catch(e => console.error(e.message))"
     ```

  **DO NOT**:
  - Restart the bare-metal host.
  - Modify `.env` unless `INFERENCE_GATEWAY_TOKEN` is confirmed missing.

  **Success Criteria**:
  - [ ] `git status` in `openclaw-archie/` is clean (no uncommitted changes).
  - [ ] Latest commit on `origin/main` is the modernization commit.
  - [ ] `docker ps` shows `openclaw-archie` as `Up` and `healthy`.
  - [ ] Health endpoint returns `200 true`.
  - [ ] Logs show the gateway ready without `vllm` errors and with an `inference-server/` model loaded.
  - [ ] Discord connects successfully.

  **Rollback**:
  ```bash
  cd openclaw-archie
  docker compose down
  git revert HEAD --no-edit
  git push origin main
  ```
  ````
- **Rollback**: `docker compose down`, `git revert HEAD`, and push. Then restore runtime config from the pre-restart backup if needed.

---

## Summary of Expected Final State

- `data/openclaw-archie/openclaw.json` and `openclaw-archie/openclaw.json` are identical, valid JSON, and reflect the modern OpenClaw Life topology.
- `models` contains ONLY `providers.inference-server` (no `vllm`, no `models.mode`).
- `agents.defaults.model` is a structured object with `primary` and `fallbacks`.
- `agents.defaults.memorySearch` points to the cloud embedding endpoint with the fully-qualified model name.
- Top-level `memory.backend` is `"builtin"`.
- `plugins.entries.google.enabled` is `true`; `vllm` plugin entry is gone.
- `gateway.controlUi.allowedOrigins` is `["https://${OPENCLAW_HOSTNAME}"]`.
- The commit "Task 4: Modernize archie openclaw.json for inference-server" is on `origin/main`.
- The `openclaw-archie` container is `Up (healthy)`, loads the `inference-server` provider, and Discord responds to messages.
