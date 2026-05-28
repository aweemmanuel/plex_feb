FROM ubuntu:22.04

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    fuse3 \
    cron \
    tzdata \
    wget \
    unzip \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Allow FUSE mounts
RUN echo "user_allow_other" >> /etc/fuse.conf

# Install rclone
RUN curl https://rclone.org/install.sh | bash

# Install Plex Media Server
RUN curl -sS "https://downloads.plex.tv/plex-media-server-new/1.40.1.8227-c0dd5a73e/debian/plexmediaserver_1.40.1.8227-c0dd5a73e_amd64.deb" \
    -o /tmp/plexmediaserver.deb && \
    dpkg -i /tmp/plexmediaserver.deb && \
    rm /tmp/plexmediaserver.deb

# Create directories
RUN mkdir -p \
    /data/media \
    /mnt/febbox \
    /config/plex \
    /transcode \
    /root/.config/rclone \
    /var/log/plex-railway

# Copy scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/generate-rclone-config.sh /generate-rclone-config.sh
COPY scripts/sync-media.sh /sync-media.sh
COPY scripts/refresh-plex.sh /refresh-plex.sh
COPY scripts/healthcheck.sh /healthcheck.sh

# Make scripts executable
RUN chmod +x \
    /entrypoint.sh \
    /generate-rclone-config.sh \
    /sync-media.sh \
    /refresh-plex.sh \
    /healthcheck.sh

# Expose Plex port
EXPOSE 32400

# Volumes are managed via Railway Volumes in railway.toml (/data, /config, /transcode)

# Healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=120s --retries=3 \
    CMD /healthcheck.sh

ENTRYPOINT ["/entrypoint.sh"]
