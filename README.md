# openclaw-life

This repository is the **orchestration environment** for running one or more OpenClaw instances on a shared VM. It manages the shared infrastructure (reverse proxy, Docker networking). Individual OpenClaw instance repos are cloned independently within it and are not tracked by this repository.

---

## Architecture Overview

```
openclaw-life/                          ← this repo (shared infrastructure)
├── docker-compose.yml                  ← Traefik reverse proxy
├── step-0-setup-system.sh              ← one-time system provisioning (run as root)
├── step-1-setup-openclaw-life.sh       ← one-time environment setup (run as user)
│
├── openclaw-<instance-a>/              ← independently cloned instance repo
│   ├── docker-compose.yml              ← instance-specific containers
│   └── ...                             ← openclaw directories tracked by Git
│
└── openclaw-<instance-b>/              ← independently cloned instance repo
    ├── docker-compose.yml
    └── ...
```

Each `openclaw-<instance>` subdirectory is an independent Git repository cloned directly into this directory. It is not tracked by this repository. This keeps instance-specific configuration, data, and revision history isolated while sharing the underlying Docker network and Traefik proxy.

---

## Shared Infrastructure

### Docker Network

All containers — Traefik and every instance — communicate over the external bridge network `openclaw-life-net`. This network is created once by `step-0-setup-system.sh` and must exist before any `docker compose up` calls are made.

### Traefik (Reverse Proxy)

`docker-compose.yml` in this root directory runs a single [Traefik](https://traefik.io/) instance that handles:

- Automatic HTTPS via Let's Encrypt DNS-01 challenge (Linode DNS provider)
- HTTP → HTTPS redirect
- Routing to individual instance containers via Docker labels

ACME certificate state is persisted to `~/.openclaw-life/data/traefik-acme.json`.

**Required environment variables** (passed through SSH or set in the shell):

| Variable | Purpose |
|---|---|
| `LINODE_TOKEN` | Linode API token for DNS-01 ACME challenge |
| `ACME_EMAIL` | Email address registered with Let's Encrypt |

---

## Initial Setup

### Step 0 — System provisioning (once, as root or with sudo)

Installs Docker, configures SSH to forward `LINODE_TOKEN` and `ACME_EMAIL` from your local machine, and creates the shared Docker network.

```bash
sudo ./step-0-setup-system.sh
```

### Step 1 — Environment setup (once, as the service user)

Creates the persistence directory and secures the `acme.json` file required by Traefik.

```bash
./step-1-setup-openclaw-life.sh
```

### Start the shared infrastructure

```bash
docker compose up -d
```

---

## Adding an OpenClaw Instance

Each instance lives in its own Git repository named `openclaw-<instance>`. Clone it directly into this directory:

```bash
git clone <repo-url> openclaw-<instance>
```

Inside `openclaw-<instance>/`, the instance repo is expected to contain:

- A `docker-compose.yml` that defines the instance's containers, joins `openclaw-life-net`, and declares appropriate Traefik labels for routing.
- Volume mounts pointing at the directories within the submodule that should be revision-controlled (e.g. configuration, user data, plugins).

Start an instance:

```bash
cd openclaw-<instance>
docker compose up -d
```

---

## Setting Up on a New Machine

Clone this repository, then clone each instance repo alongside it:

```bash
git clone <repo-url> openclaw-life
cd openclaw-life
git clone <instance-repo-url> openclaw-<instance>
```

Then re-run the setup steps above.

---

## Updating an Instance

Each instance is an independent repo. Pull updates from within the instance directory:

```bash
cd openclaw-<instance>
git pull
```

---

## Persistence and Backups

Git is used as the primary mechanism for tracking and backing up important OpenClaw directories. Each `openclaw-<instance>` repo should commit changes to any directories that represent meaningful state — configuration files, installed plugins, user settings, etc. Routine `git commit` + `git push` from within the instance directory serves as the backup workflow.

Traefik certificate state (`acme.json`) lives outside Git in `~/.openclaw-life/data/` and should be backed up separately if needed.
