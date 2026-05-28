#!/bin/bash
# Generates rclone.conf from environment variables

RCLONE_CONFIG_DIR="/root/.config/rclone"
RCLONE_CONFIG_FILE="$RCLONE_CONFIG_DIR/rclone.conf"
REMOTE_NAME="${RCLONE_REMOTE_NAME:-febbox}"
VENDOR="${WEBDAV_VENDOR:-other}"

mkdir -p "$RCLONE_CONFIG_DIR"

cat > "$RCLONE_CONFIG_FILE" <<EOF
[$REMOTE_NAME]
type = webdav
url = ${WEBDAV_URL}
vendor = ${VENDOR}
user = ${WEBDAV_USER}
pass = $(rclone obscure "${WEBDAV_PASS}")
EOF

echo "rclone config written to $RCLONE_CONFIG_FILE"
echo "Remote name: $REMOTE_NAME"
echo "WebDAV URL: ${WEBDAV_URL}"
echo "Vendor: $VENDOR"

# Test connection
echo "Testing rclone connection..."
if rclone lsd "${REMOTE_NAME}:" --timeout 30s > /dev/null 2>&1; then
    echo "✅ WebDAV connection successful"
else
    echo "⚠️  WebDAV connection test failed — check your credentials"
    echo "    URL: ${WEBDAV_URL}"
    echo "    User: ${WEBDAV_USER}"
fi
