#!/bin/bash
# Backs up the Loki data volume to Restic (S3).
# Designed to run via systemd timer.

set -euo pipefail

LOG_PREFIX="[loki-backup]"
CONTAINER_NAME="loki"
VOLUME_NAME="loki_data"
MOUNT_PATH="/tmp/loki-backup"
TAG="loki"
BACKUP_FAILED=false

log_info()  { echo "$LOG_PREFIX [INFO] $1"; }
log_error() { echo "$LOG_PREFIX [ERROR] $1" >&2; }

# Ensure container restarts and temp files are cleaned up on any exit (success or failure)
cleanup() {
  log_info "Cleaning up temporary files..."
  rm -rf "$MOUNT_PATH"
  log_info "Starting $CONTAINER_NAME container after backup..."
  docker start "$CONTAINER_NAME" || log_error "Failed to start $CONTAINER_NAME — manual intervention required"
  if [ "$BACKUP_FAILED" = true ]; then
    log_error "Backup failed — container restored but backup did not complete"
  fi
}
trap cleanup EXIT

# Load Restic environment (repo URL, credentials, password file)
set -a && . /etc/restic/env && set +a

log_info "Starting backup..."

# Stop container to ensure consistent volume snapshot
log_info "Stopping $CONTAINER_NAME container for consistent backup..."
docker stop "$CONTAINER_NAME" || { log_error "Failed to stop $CONTAINER_NAME"; BACKUP_FAILED=true; exit 1; }

# Mount the Docker volume to a temporary path and back it up
mkdir -p "$MOUNT_PATH"
docker run --rm \
  -v ${VOLUME_NAME}:/data:ro \
  -v ${MOUNT_PATH}:/backup \
  alpine tar cf /backup/loki-data.tar -C /data . || { log_error "Failed to create tar archive"; BACKUP_FAILED=true; exit 1; }

# Back up the tar to Restic with a service-specific tag
restic backup "$MOUNT_PATH" --tag "$TAG" || { log_error "Failed to upload backup to Restic"; BACKUP_FAILED=true; exit 1; }

# Prune old snapshots (keep 7 daily, 4 weekly, 2 monthly)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 2 --prune || log_error "Failed to prune old snapshots"

log_info "Backup completed successfully"
