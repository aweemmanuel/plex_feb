#!/bin/bash
# Healthcheck: verifies Plex is responding

curl -sf http://localhost:32400/identity > /dev/null 2>&1
exit $?
