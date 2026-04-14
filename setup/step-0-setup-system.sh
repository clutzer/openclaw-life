#!/bin/bash

# Exit on any error
set -e

echo "--- Preparing System for OpenClaw-Life Orchestration Environment ---"

# 1. Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "[!] Docker not found. Configuring repositories and installing Docker..."
    # Adapted from: https://docs.docker.com/engine/install/ubuntu/
    sudo apt-get update
    # Remove existing docker versions...
    sudo apt remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1)
    # Add Docker's official GPG key:
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # Add the repository to Apt sources:
    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    sudo apt-get update
    sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo docker run hello-world
else
    echo "[ok] Docker is already installed."
fi

# 2. Configure SSH to accept LINODE_TOKEN (Modular Snippet)
SSH_CONF_DIR="/etc/ssh/sshd_config.d"
SSH_OPENCLAW_LIFE_CONF_FILE="$SSH_CONF_DIR/openclaw-life.conf"
SSH_OPENCLAW_LIFE_DATA="AcceptEnv LINODE_TOKEN ACME_EMAIL"

if [ ! -f "$SSH_OPENCLAW_LIFE_CONF_FILE" ]; then
    echo "[+] Creating OpenClaw-Life SSH configuration..."
    echo "$SSH_OPENCLAW_LIFE_DATA" | sudo tee "$SSH_OPENCLAW_LIFE_CONF_FILE" > /dev/null
    echo "[+] Restarting SSH service to apply changes..."
    sudo systemctl restart ssh
else
    # Check if the content is correct
    if ! grep -q "$SSH_OPENCLAW_LIFE_DATA" "$SSH_OPENCLAW_LIFE_CONF_FILE"; then
        echo "[!] Updating existing OpenClaw-Life SSH configuration..."
        echo "$SSH_OPENCLAW_LIFE_DATA" | sudo tee "$SSH_OPENCLAW_LIFE_CONF_FILE" > /dev/null
        sudo systemctl restart ssh
    else
        echo "[ok] OpenClaw-Life SSH configuration is already present."
    fi
fi

# 3. Ensure the Docker network exists
if ! docker network inspect openclaw-life-net >/dev/null 2>&1; then
    echo "[+] Creating external Docker network: openclaw-life-net"
    docker network create openclaw-life-net
else
    echo "[ok] Docker network 'openclaw-life-net' already exists."
fi


echo "--- System Configuration Complete ---"