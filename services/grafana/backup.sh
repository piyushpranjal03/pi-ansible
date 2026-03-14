#!/bin/bash
# Backs up Grafana and Loki data volumes to Restic (S3).
# Designed to run via systemd timer.

set -euo pipefail

LOG_PREFIX="[grafana-backup]"
MOUNT_PATH="/tmp/grafana-backup"
TAG="grafana"

# Load Restic environment (repo URL, credentials, password file)
set -a && . /etc/restic/env && set +a

echo "$LOG_PREFIX Starting backup..."

mkdir -p "$MOUNT_PATH"

# Back up Grafana data (dashboards, users, alert rules, preferences)
docker run --rm \
  -v grafana_data:/data:ro \
  -v ${MOUNT_PATH}:/backup \
  alpine tar cf /backup/grafana-data.tar -C /data .

# Back up Loki data (stored logs and index)
docker run --rm \
  -v loki_data:/data:ro \
  -v ${MOUNT_PATH}:/backup \
  alpine tar cf /backup/loki-data.tar -C /data .

# Send both tars to Restic
restic backup "$MOUNT_PATH" --tag "$TAG"

# Clean up temporary files
rm -rf "$MOUNT_PATH"

# Prune old snapshots (keep 7 daily, 4 weekly, 2 monthly)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 2 --prune

echo "$LOG_PREFIX Backup completed successfully"
