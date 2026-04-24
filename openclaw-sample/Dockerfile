# This Dockerfile is designed to create a custom OpenClaw image with a user that matches the host's UID and GID.
# This is important for file permissions when mounting volumes from the host.
#
# To build this image, you can use the following command, which passes the current user's UID and GID as build arguments:
#
# docker build --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) .

# --- STAGE 1: The GOG Downloader ---
FROM alpine:latest AS gog-builder
RUN apk add --no-cache curl
RUN curl -Lsf https://github.com/steipete/gogcli/releases/download/v0.12.0/gogcli_0.12.0_linux_amd64.tar.gz | \
    tar -zxv gog

# --- STAGE 2: Final Image Construction ---
#FROM ghcr.io/openclaw/openclaw:latest
FROM ghcr.io/openclaw/openclaw:2026.4.12

# Metadata only (Does not set the image name!)
LABEL maintainer="OpenClaw Life Team <christiaan.lutzer@gmail.com>"
LABEL description="OpenClaw with synced permissions and extra client tools..."

# Define IDs (these can be overridden at build time with --build-arg)
ARG USER_ID=1000
ARG GROUP_ID=1000

USER root

# Setup User
RUN groupmod -g ${GROUP_ID} node && \
    usermod -u ${USER_ID} -g ${GROUP_ID} node && \
    chown -R node:node /home/node

# Add gogcli from the builder stage
# This is a clean "COPY" layer—no junk, no apt-get needed here.
COPY --from=gog-builder /gog /usr/local/bin/gog
RUN chmod +x /usr/local/bin/gog

# Add your next app here easily:
# COPY --from=other-builder /some-tool /usr/local/bin/

WORKDIR /app

USER node
