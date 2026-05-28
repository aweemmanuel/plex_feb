#!/bin/bash
# Do NOT use set -e — we want Plex to start even if ancillary steps warn/fail

LOG=/var/log/plex-railway/startup.log
mkdir -p /var/log/plex-railway
# Tee to log file without replacing the shell (exec tee would prevent later exec)
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

# ── 4. Storage mode variables ────────────────────────────────────────────────
SYNC_MODE="${SYNC_MODE:-sync}"
SYNC_INTERVAL="${SYNC_INTERVAL:-15}"
MOUNT_PATH="${MOUNT_PATH:-/mnt/febbox}"
LOCAL_MEDIA_PATH="${LOCAL_MEDIA_PATH:-/data/media}"
RCLONE_REMOTE_NAME="${RCLONE_REMOTE_NAME:-febbox}"

mkdir -p "$MOUNT_PATH" "$LOCAL_MEDIA_PATH"

if [ "$SYNC_MODE" = "mount" ]; then
    export PLEX_LIBRARY_PATH="$MOUNT_PATH"
else
    export PLEX_LIBRARY_PATH="$LOCAL_MEDIA_PATH"
fi

# ── 5. Plex config setup ─────────────────────────────────────────────────────
PLEX_CONFIG_DIR="${PLEX_CONFIG_DIR:-/config/plex}"
mkdir -p "$PLEX_CONFIG_DIR"

PLEX_PREFS_DIR="$PLEX_CONFIG_DIR/Library/Application Support/Plex Media Server"
mkdir -p "$PLEX_PREFS_DIR"

PLEX_PREFS_FILE="$PLEX_PREFS_DIR/Preferences.xml"
if [ -n "$PLEX_CLAIM" ] && [ ! -f "$PLEX_PREFS_FILE" ]; then
    echo "🎟️  Applying Plex claim token..."
    cat > "$PLEX_PREFS_FILE" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<Preferences
  OldestPreviousVersion="1.40.1.8227"
  ProcessedMachineIdentifier=""
  PlexOnlineToken=""
  TranscoderTempDirectory="${PLEX_TRANSCODE_DIR:-/transcode}"
/>
EOF
fi

export PLEX_MEDIA_SERVER_APPLICATION_SUPPORT_DIR="$PLEX_CONFIG_DIR/Library/Application Support"

# ── 6. Plex environment ───────────────────────────────────────────────────────
export LD_LIBRARY_PATH=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_HOME=/usr/lib/plexmediaserver
export PLEX_MEDIA_SERVER_MAX_PLUGIN_PROCS=6
export PLEX_MEDIA_SERVER_TMPDIR="${PLEX_TRANSCODE_DIR:-/transcode}"

# ── 7. Start rclone / cron in background BEFORE exec ─────────────────────────
# These must be launched before exec replaces this shell process.
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
else
    echo "🔄 Scheduling rclone SYNC mode (every ${SYNC_INTERVAL}m)..."
    # Set up cron for recurring sync
    echo "*/${SYNC_INTERVAL} * * * * /sync-media.sh >> /var/log/plex-railway/sync.log 2>&1" | crontab -
    service cron start || true
    echo "✅ Cron sync job scheduled every ${SYNC_INTERVAL} minutes"

    # Kick off the first sync in the background — Plex will start in parallel
    echo "⏳ Starting initial background sync..."
    /sync-media.sh >> /var/log/plex-railway/sync.log 2>&1 &
    echo "✅ Background sync started (PID: $!)"
fi

echo "============================================"
echo "  ✅ Pre-flight complete — handing off to Plex"
echo "  📺 Plex: http://localhost:32400/web"
echo "  📁 Media: $PLEX_LIBRARY_PATH"
echo "  🔄 Mode: $SYNC_MODE"
echo "============================================"

# ── 8. Exec Plex as PID 1 ────────────────────────────────────────────────────
# Using exec replaces this shell with the Plex process so that:
#   • Plex runs as PID 1 and Docker monitors it directly
#   • SIGTERM/SIGINT from Docker are delivered straight to Plex
#   • The container exits when (and only when) Plex exits
echo "🎬 Starting Plex Media Server (exec → PID 1)..."
exec /usr/lib/plexmediaserver/"Plex Media Server"

