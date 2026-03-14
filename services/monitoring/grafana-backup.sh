#!/bin/bash
# Backs up the Grafana data volume to Restic (S3).
# Designed to run via systemd timer.

set -euo pipefail

LOG_PREFIX="[grafana-backup]"
CONTAINER_NAME="grafana"
VOLUME_NAME="grafana_data"
MOUNT_PATH="/tmp/grafana-backup"
TAG="grafana"

# Ensure container restarts and temp files are cleaned up on any exit (success or failure)
cleanup() {
  echo "$LOG_PREFIX Cleaning up temporary files..."
  rm -rf "$MOUNT_PATH"
  echo "$LOG_PREFIX Starting $CONTAINER_NAME container after backup..."
  docker start "$CONTAINER_NAME" || echo "$LOG_PREFIX WARNING: Failed to start $CONTAINER_NAME"
}
trap cleanup EXIT

# Load Restic environment (repo URL, credentials, password file)
set -a && . /etc/restic/env && set +a

echo "$LOG_PREFIX Starting backup..."

# Stop container to ensure consistent volume snapshot
echo "$LOG_PREFIX Stopping $CONTAINER_NAME container for consistent backup..."
docker stop "$CONTAINER_NAME"

# Mount the Docker volume to a temporary path and back it up
mkdir -p "$MOUNT_PATH"
docker run --rm \
  -v ${VOLUME_NAME}:/data:ro \
  -v ${MOUNT_PATH}:/backup \
  alpine tar cf /backup/grafana-data.tar -C /data .

# Back up the tar to Restic with a service-specific tag
restic backup "$MOUNT_PATH" --tag "$TAG"

# Prune old snapshots (keep 7 daily, 4 weekly, 2 monthly)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 2 --prune

echo "$LOG_PREFIX Backup completed successfully"
