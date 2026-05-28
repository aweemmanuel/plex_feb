#!/bin/bash
set -e

LOG=/var/log/plex-railway/startup.log
mkdir -p /var/log/plex-railway
exec > >(tee -a "$LOG") 2>&1

echo "============================================"
echo "  🎬 Plex Railway Startup — $(date)"
echo "============================================"

# ── 1. Timezone ──────────────────────────────────────────────────────────────
TZ="${TZ:-Africa/Lagos}"
ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
echo "$TZ" > /etc/timezone
echo "✅ Timezone: $TZ"

# ── 2. Validate required ENV vars ────────────────────────────────────────────
REQUIRED_VARS="WEBDAV_URL WEBDAV_USER WEBDAV_PASS"
for var in $REQUIRED_VARS; do
    if [ -z "${!var}" ]; then
        echo "❌ ERROR: Required environment variable $var is not set."
        exit 1
    fi
done
echo "✅ Environment variables validated"

# ── 3. Generate rclone config ────────────────────────────────────────────────
echo "🔧 Generating rclone configuration..."
/generate-rclone-config.sh
echo "✅ rclone config ready"

# ── 4. Storage mode setup ────────────────────────────────────────────────────
SYNC_MODE="${SYNC_MODE:-sync}"
SYNC_INTERVAL="${SYNC_INTERVAL:-15}"
MOUNT_PATH="${MOUNT_PATH:-/mnt/febbox}"
LOCAL_MEDIA_PATH="${LOCAL_MEDIA_PATH:-/data/media}"
RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-febbox}"

mkdir -p "$MOUNT_PATH" "$LOCAL_MEDIA_PATH"

if [ "$SYNC_MODE" = "mount" ]; then
    echo "🔗 Starting rclone MOUNT mode..."
    rclone mount "${RCLONE_REMOTE_NAME}:" "$MOUNT_PATH" \
        --allow-other \
        --vfs-cache-mode full \
        --vfs-cache-max-size 2G \
        --vfs-read-chunk-size 32M \
        --vfs-read-chunk-size-limit 256M \
        --buffer-size 64M \
        --poll-interval 60s \
        --dir-cache-time 5m \
        --log-file /var/log/plex-railway/rclone-mount.log \
        --log-level INFO \
        --daemon
    echo "✅ rclone mount started at $MOUNT_PATH"

    # Point Plex at mounted path
    export PLEX_LIBRARY_PATH="$MOUNT_PATH"
else
    echo "🔄 Starting rclone SYNC mode (every ${SYNC_INTERVAL}m)..."

    # Initial sync before Plex starts
    echo "⏳ Running initial sync..."
    /sync-media.sh || echo "⚠️  Initial sync had issues, continuing..."
    echo "✅ Initial sync complete"

    # Set up cron for recurring sync
    echo "*/${SYNC_INTERVAL} * * * * /sync-media.sh >> /var/log/plex-railway/sync.log 2>&1" | crontab -
    service cron start
    echo "✅ Cron sync job scheduled every ${SYNC_INTERVAL} minutes"

    export PLEX_LIBRARY_PATH="$LOCAL_MEDIA_PATH"
fi

# ── 5. Plex config setup ─────────────────────────────────────────────────────
PLEX_CONFIG_DIR="${PLEX_CONFIG_DIR:-/config/plex}"
mkdir -p "$PLEX_CONFIG_DIR"

# Link plex preferences directory
PLEX_PREFS_DIR="$PLEX_CONFIG_DIR/Library/Application Support/Plex Media Server"
mkdir -p "$PLEX_PREFS_DIR"

# Apply claim token if provided and not already claimed
PLEX_PREFS_FILE="$PLEX_PREFS_DIR/Preferences.xml"
if [ -n "$PLEX_CLAIM" ] && [ ! -f "$PLEX_PREFS_FILE" ]; then
    echo "🎟️  Applying Plex claim token..."
    cat > "$PLEX_PREFS_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Preferences
  OldestPreviousVersion="1.40.1.8227"
  ProcessedMachineIdentifier=""
  PlexOnlineToken=""
  TranscoderTempDirectory="$PLEX_TRANSCODE_DIR"
/>
EOF
fi

# Set env for linuxserver-style plex
export PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="$PLEX_CONFIG_DIR/Library/Application Support"

# ── 6. Start Plex ────────────────────────────────────────────────────────────
echo "🎬 Starting Plex Media Server..."
export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6
export PLEX_MEDIA_SERVER_TMPDIR="${PLEX_TRANSCODE_DIR:-/transcode}"

if [ -n "$PLEX_CLAIM" ]; then
    export PLEX_CLAIM="$PLEX_CLAIM"
fi

# Start Plex in background
/usr/lib/plexmediaserver/Plex\ Media\ Server &
PLEX_PID=$!
echo "✅ Plex started (PID: $PLEX_PID)"

# ── 7. Wait for Plex to become ready ─────────────────────────────────────────
echo "⏳ Waiting for Plex to come online..."
MAX_WAIT=120
WAITED=0
while ! curl -sf "http://localhost:32400/identity" > /dev/null 2>&1; do
    sleep 5
    WAITED=$((WAITED + 5))
    if [ $WAITED -ge $MAX_WAIT ]; then
        echo "⚠️  Plex didn't respond in ${MAX_WAIT}s, continuing anyway..."
        break
    fi
done
echo "✅ Plex is online"

# ── 8. Trigger initial library refresh ───────────────────────────────────────
if [ -n "$PLEX_TOKEN" ]; then
    echo "🔄 Triggering initial library refresh..."
    /refresh-plex.sh || echo "⚠️  Library refresh failed, will retry on next sync"
fi

echo "============================================"
echo "  ✅ Setup Complete!"
echo "  📺 Plex: http://localhost:32400/web"
echo "  📁 Media: $PLEX_LIBRARY_PATH"
echo "  🔄 Mode: $SYNC_MODE"
echo "============================================"

# ── 9. Keep container alive, monitor Plex ────────────────────────────────────
wait $PLEX_PID
