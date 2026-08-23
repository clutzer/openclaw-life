# OpenClaw Archie — Template Sync Task List

> **Context**: `openclaw-archie` was originally deployed from `openclaw-sample`. Since then the sample template has evolved (newer gogcli, updated UID/GID convention, removal of self-signed cert mounts, re-added `OPENCLAW_HOSTNAME`, etc.). This work stream realigns the instance’s tracked files with the current sample template.
>
> **Goal**: Bring `openclaw-archie/` into parity with `openclaw-sample/` for all shared boilerplate files, while leaving instance-specific runtime data (`openclaw.json`, `workspaces/`, workspace state) untouched.
>
> **Current state to migrate from**: Archie still uses gogcli v0.12.0, the older `UID`/`GID` env naming, references the upstream `ghcr.io/openclaw/openclaw:latest` image, mounts extra volumes (`workspaces`, custom CA certs), and is missing the `README.md` hardening section.

---

## Execution Order

Run these in order. Each task should be executed in a fresh Zed thread with the indicated files attached.

When the agent makes a git commit for changes done in a task thread, the commit message **must** reference the task that started the thread.

- [x] [Task 1 — Update Archie Dockerfile to match sample template](#task-1--update-archie-dockerfile-to-match-sample-template)
- [x] [Task 2 — Update Archie docker-compose.yml to match sample template](#task-2--update-archie-docker-composeyml-to-match-sample-template)
- [x] [Task 3 — Update Archie example.env to match sample template](#task-3--update-archie-exampleenv-to-match-sample-template)
- [x] [Task 4 — Add missing Hardening section to Archie README.md](#task-4--add-missing-hardening-section-to-archie-readmemd)

---

### Task 1 — Update Archie Dockerfile to match sample template

- [x] Completed

**Files to attach**:
- `openclaw-sample/Dockerfile`
- `openclaw-archie/Dockerfile`

**Prompt**:
````markdown
**Task**: Task 1 — Update Archie Dockerfile to match sample template

**Current deployed reality**:
- `openclaw-archie/Dockerfile` downloads `gogcli_0.12.0_linux_amd64.tar.gz` from the `steipete/gogcli` release.
- It skips any validation that the `USER_ID` and `GROUP_ID` build arguments are actually provided.
- `openclaw-sample/Dockerfile` has been bumped to `gogcli_0.25.0_linux_amd64.tar.gz` and includes an explicit validation/logging `RUN` step.

**Changes to make**:
1. In `openclaw-archie/Dockerfile`, change the `curl` line to download `https://github.com/steipete/gogcli/releases/download/v0.25.0/gogcli_0.25.0_linux_amd64.tar.gz`.
2. Insert the following block immediately before the existing `USER root` line (preserving indentation and line breaks exactly as shown):
   ```dockerfile
   # Log the IDs being used for the build
   RUN if [ -z "$USER_ID" ] || [ -z "$GROUP_ID" ]; then \
           echo "❌ Error: USER_ID or GROUP_ID is not set. Please run the health check script first: ../scripts/openclaw-life-check"; \
           exit 1; \
       fi && \
       echo "Building image with USER_ID=${USER_ID} and GROUP_ID=${GROUP_ID}"
   ```
3. Do not alter any other stage, label, or `COPY` instruction.

**Constraints**:
- Keep the existing base image line (`FROM ghcr.io/openclaw/openclaw:2026.4.12`) unchanged.
- Do not remove the `COPY --from=gog-builder /gog /usr/local/bin/gog` step.
- Ensure the build remains deterministic by pinning the gogcli version exactly.
````

**Rationale**: The sample bumped the GOG CLI version and added a guard to fail fast when build args are missing; Archie needs both improvements before any future image rebuilds.

---

### Task 2 — Update Archie docker-compose.yml to match sample template

- [x] Completed

**Files to attach**:
- `openclaw-sample/docker-compose.yml`
- `openclaw-archie/docker-compose.yml`

**Prompt**:
````markdown
**Task**: Task 2 — Update Archie docker-compose.yml to match sample template

**Current deployed reality**:
- `openclaw-archie/docker-compose.yml` currently:
  - Uses `image: ghcr.io/openclaw/openclaw:latest`
  - Declares build `args:` as a YAML list with fallbacks (`USER_ID=${USER_ID:-1000}`)
  - Sets the container user via `"${UID:-1000}:${GID:-1000}"`
  - Injects `NODE_EXTRA_CA_CERTS: /etc/inference-server/certs/ca.crt`
  - Mounts `./workspaces:/home/node/.openclaw/workspaces`
  - Mounts `${HOME}/.openclaw-life/certs:/etc/inference-server/certs:ro`
  - Omits the `OPENCLAW_HOSTNAME` env var
  - Omits the gogcli env vars (`GOG_HOME`, `GOG_KEYRING_BACKEND`, `GOG_KEYRING_PASSWORD`, `GOG_ACCOUNT`)
- `openclaw-sample/docker-compose.yml` follows the newer template style:
  - Uses `image: openclaw-life:latest`
  - Declares build `args:` as a YAML map without fallbacks (`USER_ID: ${USER_ID}`)
  - Uses `"${USER_ID:-1000}:${GROUP_ID:-1000}"` for the user string
  - Includes `OPENCLAW_HOSTNAME` and the gogcli block
  - Does not mount `workspaces` or custom CA certs

**Changes to make**:
1. Change the `image:` line to `openclaw-life:latest`.
2. Replace the build `args:` block with the map-style declaration exactly as in the sample:
   ```yaml
   args:
     USER_ID: ${USER_ID}
     GROUP_ID: ${GROUP_ID}
   ```
3. Add `OPENCLAW_HOSTNAME: ${OPENCLAW_HOSTNAME}` in the `environment:` section, placed immediately after `OPENCLAW_NAME: ${OPENCLAW_NAME}`.
4. Remove the `NODE_EXTRA_CA_CERTS` line from `environment:`.
5. Re-add the gogcli block after `INFERENCE_GATEWAY_TOKEN:` exactly as shown in the sample:
   ```yaml
       # gogcli (Google CLI) configuration — populated by scripts/openclaw-life-gog-auth
       GOG_HOME: ${GOG_HOME:-}
       GOG_KEYRING_BACKEND: ${GOG_KEYRING_BACKEND:-}
       GOG_KEYRING_PASSWORD: ${GOG_KEYRING_PASSWORD:-}
       GOG_ACCOUNT: ${GOG_ACCOUNT:-}
   ```
6. Change the `user:` line to `"${USER_ID:-1000}:${GROUP_ID:-1000}"`.
7. Remove the `./workspaces:/home/node/.openclaw/workspaces` volume mount.
8. Remove the `${HOME}/.openclaw-life/certs:/etc/inference-server/certs:ro` volume mount.
9. Leave the `traefik` labels, `healthcheck`, `command`, `networks`, and the standard `workspace` + named data volumes untouched.

**Constraints**:
- Preserve the exact YAML indentation and blank-line style from the sample file.
- If Archie currently depends on the custom CA cert mount or the extra `workspaces` mount, those will be removed; the operator should confirm those features are no longer needed before bringing the container down.
- Do not touch `.env` or `example.env` in this task.
````

**Rationale**: The sample switched to a locally built image, standardised on `USER_ID`/`GROUP_ID`, and removed the self-signed-cert workaround; Archie needs to follow the same pattern to remain maintainable.

---

### Task 3 — Update Archie example.env to match sample template

- [x] Completed

**Files to attach**:
- `openclaw-sample/example.env`
- `openclaw-archie/example.env`

**Prompt**:
````markdown
**Task**: Task 3 — Update Archie example.env to match sample template

**Current deployed reality**:
- `openclaw-archie/example.env` names the UID/GID overrides as `UID=` and `GID=`, and does not include the gogcli configuration block.
- `openclaw-sample/example.env` uses `USER_ID=` / `GROUP_ID=` and documents the optional gogcli variables.

**Changes to make**:
1. Rename the final two lines from `UID=` to `USER_ID=` and from `GID=` to `GROUP_ID=`.
2. Insert the gogcli block before the `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=` line, exactly as in the sample:
   ```env
   # gogcli (Google CLI) — populated automatically by scripts/openclaw-life-gog-auth.
   # When set, the OpenClaw container can interact with Gmail, Calendar, Drive, etc.
   # GOG_HOME=                   # defaults to /home/node/.openclaw/gogcli when configured
   # GOG_KEYRING_BACKEND=        # set to "file" for container use
   # GOG_KEYRING_PASSWORD=       # generated by the setup script; injected at runtime
   # GOG_ACCOUNT=                # default Google account email for gog commands
   ```
3. Ensure the rest of the file remains identical to the sample—do not drop existing variables (`OPENCLAW_HOSTNAME=`, `OPENCLAW_NAME=`, provider credentials, etc.).

**Constraints**:
- Keep the file as an example template; never commit real secrets.
- Do not re-order unrelated sections.
````

**Rationale**: The sample normalised on `USER_ID`/`GROUP_ID` and added gogcli documentation; Archie’s `.env` skeleton should match so that future re-runs of `openclaw-life-configure` behave predictably.

---

### Task 4 — Add missing Hardening section to Archie README.md

- [x] Completed

**Files to attach**:
- `openclaw-sample/README.md`
- `openclaw-archie/README.md`

**Prompt**:
````markdown
**Task**: Task 4 — Add missing Hardening section to Archie README.md

**Current deployed reality**:
- `openclaw-archie/README.md` ends after the Memory code block and is missing the `## Hardening` section that exists in the sample.
- `openclaw-sample/README.md` includes a hardening snippet useful for production deployments.

**Changes to make**:
1. Append the exact `## Hardening` section from the sample to the end of `openclaw-archie/README.md`:
   ```markdown
   ## Hardening

   ```
   openclaw config set session.dmScope per-channel-peer
   openclaw config set tools.profile messaging
   openclaw config set tools.deny '["gateway", "cron", "sessions_spawn", "sessions_send"]'
   openclaw config set tools.fs.workspaceOnly true
   openclaw config set tools.exec.security deny
   ```
   ```
2. Ensure the final file ends with a newline.

**Constraints**:
- Do not modify existing sections (Overview, Quality of Life, Memory).
- Match the exact markdown formatting and indentation from the sample.
````

**Rationale**: The sample added a recommended hardening guide post-deployment; Archie should have the same documentation footprint.

---

## Summary of Expected Final State

After all tasks are complete, the system should behave as follows:

1. `openclaw-archie/Dockerfile` is identical to the sample template regarding gogcli version (v0.25.0) and build-arg validation.
2. `openclaw-archie/docker-compose.yml` uses `image: openclaw-life:latest`, map-style build args, includes `OPENCLAW_HOSTNAME` and the gogcli environment variables, uses `"${USER_ID:-1000}:${GROUP_ID:-1000}"`, and no longer mounts `./workspaces` or the custom CA certs directory.
3. `openclaw-archie/example.env` uses `USER_ID` / `GROUP_ID` and documents the gogcli options.
4. `openclaw-archie/README.md` contains the hardening instructions.
5. Instance-specific artifacts (`openclaw.json`, `workspaces/`, and runtime workspace state files under `workspace/`) remain untouched because they are intentionally per-instance and not part of the shared template.
