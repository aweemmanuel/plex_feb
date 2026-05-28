#!/bin/bash
# Syncs WebDAV remote to local media directory

REMOTE_NAME="${RCLONE_REMOTE_NAME:-febbox}"
LOCAL_MEDIA_PATH="${LOCAL_MEDIA_PATH:-/data/media}"
LOG_FILE="/var/log/plex-railway/sync.log"

mkdir -p "$LOCAL_MEDIA_PATH"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Starting sync: ${REMOTE_NAME}: → $LOCAL_MEDIA_PATH"

rclone sync "${REMOTE_NAME}:" "$LOCAL_MEDIA_PATH" \
    --transfers 4 \
    --checkers 8 \
    --contimeout 60s \
    --timeout 300s \
    --retries 3 \
    --low-level-retries 10 \
    --stats 1m \
    --log-file "$LOG_FILE" \
    --log-level INFO \
    --progress \
    2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Sync complete"
    # Trigger Plex refresh after successful sync
    if [ -n "$PLEX_TOKEN" ]; then
        /refresh-plex.sh
    fi
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Sync failed (exit code: $EXIT_CODE)"
fi

exit $EXIT_CODE
