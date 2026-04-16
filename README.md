# openclaw-life

This repository is the **orchestration environment** for running one or more OpenClaw instances on a shared VM. It manages the shared infrastructure (reverse proxy, Docker networking). Individual OpenClaw instance repos are cloned independently within it and are not tracked by this repository.

---

## Architecture Overview

```
openclaw-life/                          ← this repo (shared infrastructure)
├── docker-compose.yml                  ← Traefik reverse proxy
│
├── scripts/                            ← helper scripts
│   └── openclaw-life-check             ← verify openclaw-<instance> directory is good
│
├── setup/                              ← setup scripts
│   ├── step-0-setup-system.sh          ← one-time system provisioning (run as root)
│   └── step-1-setup-openclaw-life.sh   ← one-time environment setup (run as user)
│
├── openclaw-<instance-a>/              ← independently cloned instance repo
│   ├── docker-compose.yml              ← instance-specific containers
│   └── ...                             ← openclaw directories tracked by Git
│
├── openclaw-<instance-b>/              ← independently cloned instance repo
│   ├── docker-compose.yml
│   └── ...
│
└── openclaw-sample/                    ← copy this into new openclaw-myclaw
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
sudo ./setup/step-0-setup-system.sh
```

### Step 1 — Environment setup (once, as the service user)

Creates the persistence directory and secures the `traefik-acme.json` file required by Traefik.

```bash
./setup/step-1-setup-openclaw-life.sh
```

### Start the shared infrastructure

```bash
docker compose up -d
```

---


## Adding an OpenClaw Instance

To add a new OpenClaw instance, use the provided helper scripts to create, configure, and check your instance:

1. **Deploy a new instance from the sample template:**

    ```bash
    ./scripts/openclaw-life-deploy
    ```
    This will prompt you for a new instance name and create a directory like `openclaw-<instance>` by copying from `openclaw-sample`.

2. **Configure the new instance:**

    ```bash
    ./scripts/openclaw-life-configure openclaw-<instance>
    ```
    This will walk you through setting up the `.env` file and other configuration for your new instance.

3. **Check the instance setup:**

    ```bash
    ./scripts/openclaw-life-check openclaw-<instance>
    ```
    This verifies that your instance directory is ready to launch.

4. **Start the instance:**

    ```bash
    cd openclaw-<instance>
    docker compose up -d
    ```

Each instance directory will contain its own `docker-compose.yml` and configuration, isolated from other instances but sharing the underlying Docker network and Traefik proxy.

You should optionally create a private Git repo to track this OpenClaw instance to keep its critical agent files backed up.

    ```bash
    cd openclaw-<instance>
    git init
    git remote add ...
    git add -A
    git commit -m ...
    git push remote ...
    ```

---

## Setting Up on a New Machine

Clone this repository, then clone each instance repo alongside it:

```bash
git clone <repo-url> openclaw-life
cd openclaw-life
```

If you have pre-existing OpenClaw Life 'claws you want to deploy on this machine:

```
git clone <instance-repo-url> openclaw-<instance>
```

Rinse and repeat as necessary...  For each OpenClaw instance you deploy, it's recommended to setup a nightly cron using `./scripts/openclaw-life-git-backup` to ensure that you are creating backups of your critical agent files.

---

## Persistence and Backups

Git is used as the primary mechanism for tracking and backing up important OpenClaw directories. Each `openclaw-<instance>` repo should commit changes to any directories that represent meaningful state — configuration files, installed plugins, user settings, etc. Routine `git commit` + `git push` from within the instance directory serves as the backup workflow.  As an example, `./openclaw-sample/scripts/git-workspace-backup.sh` can be added to `crontab` to perform periodic backups of the OpenClaw `workspace` directory.

Traefik certificate state (`traefik-acme.json`) lives outside Git in `~/.openclaw-life/data/` and should be backed up separately if needed.
