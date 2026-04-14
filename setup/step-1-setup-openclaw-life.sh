#!/bin/bash

# Exit on any error
set -e

echo "--- Setting Up OpenClaw-Life Orchestration Environment ---"

# 1. Ensure the Docker network exists
if ! docker network inspect openclaw-life-net >/dev/null 2>&1; then
    echo "[!] Docker network 'openclaw-life-net' not found. Please run step-0-setup-system.sh as root first!"
    exit 1
else
    echo "[ok] Docker network 'openclaw-net' already exists."
fi

# 2. Define and create the persistence directory structure
DATA_DIR="$HOME/.openclaw-life/data"
ACME_FILE="$DATA_DIR/traefik-acme.json"

if [ ! -d "$DATA_DIR" ]; then
    echo "[+] Creating data directory: $DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# 3. Create and secure the acme.json file
if [ ! -f "$ACME_FILE" ]; then
    echo "[+] Creating $ACME_FILE"
    touch "$ACME_FILE"
    chmod 600 "$ACME_FILE"
else
    echo "[ok] $ACME_FILE already exists."
    chmod 600 "$ACME_FILE"
fi

# 4. Final verification of the token
if [ -z "$LINODE_TOKEN" ]; then
    echo "---"
    echo "WARNING: LINODE_TOKEN is not currently visible in this shell."
    echo "If you just updated the SSH config, you may need to reconnect."
    echo "---"
else
    echo "[ok] LINODE_TOKEN detected in environment."
fi

echo "--- OpenClaw-Life Orchestration EnvironmentSetup Complete ---"