#!/bin/bash
# Backs up the Prometheus data volume to Restic (S3).
# Designed to run via systemd timer.

set -euo pipefail

LOG_PREFIX="[prometheus-backup]"
VOLUME_NAME="prometheus_data"
MOUNT_PATH="/tmp/prometheus-backup"
TAG="prometheus"

# Load Restic environment (repo URL, credentials, password file)
set -a && . /etc/restic/env && set +a

echo "$LOG_PREFIX Starting backup..."

# Mount the Docker volume to a temporary path and back it up
mkdir -p "$MOUNT_PATH"
docker run --rm \
  -v ${VOLUME_NAME}:/data:ro \
  -v ${MOUNT_PATH}:/backup \
  alpine tar cf /backup/prometheus-data.tar -C /data .

# Back up the tar to Restic with a service-specific tag
restic backup "$MOUNT_PATH" --tag "$TAG"

# Clean up temporary files
rm -rf "$MOUNT_PATH"

# Prune old snapshots (keep 7 daily, 4 weekly, 2 monthly)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 2 --prune

echo "$LOG_PREFIX Backup completed successfully"
