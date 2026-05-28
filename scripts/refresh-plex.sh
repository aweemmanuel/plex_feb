#!/bin/bash
# Triggers a Plex library refresh via API

PLEX_HOST="${PLEX_HOST:-localhost}"
PLEX_PORT="${PLEX_PORT:-32400}"
PLEX_TOKEN="${PLEX_TOKEN:-}"

if [ -z "$PLEX_TOKEN" ]; then
    echo "⚠️  PLEX_TOKEN not set — skipping library refresh"
    exit 0
fi

BASE_URL="http://${PLEX_HOST}:${PLEX_PORT}"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔄 Refreshing Plex library..."

# Get all library sections
SECTIONS=$(curl -sf \
    -H "X-Plex-Token: ${PLEX_TOKEN}" \
    -H "Accept: application/json" \
    "${BASE_URL}/library/sections" 2>/dev/null)

if [ -z "$SECTIONS" ]; then
    echo "⚠️  Could not reach Plex API — is it running?"
    exit 1
fi

# Refresh each section
SECTION_IDS=$(echo "$SECTIONS" | jq -r '.MediaContainer.Directory[].key' 2>/dev/null)

if [ -z "$SECTION_IDS" ]; then
    echo "⚠️  No library sections found"
    # Try a global refresh as fallback
    curl -sf \
        "${BASE_URL}/library/sections/all/refresh?X-Plex-Token=${PLEX_TOKEN}" \
        > /dev/null
    echo "✅ Global refresh triggered"
    exit 0
fi

for section_id in $SECTION_IDS; do
    echo "   Refreshing section $section_id..."
    curl -sf \
        "${BASE_URL}/library/sections/${section_id}/refresh?X-Plex-Token=${PLEX_TOKEN}" \
        > /dev/null
done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Library refresh complete"
