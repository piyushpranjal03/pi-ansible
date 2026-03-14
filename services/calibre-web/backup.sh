#!/bin/bash
# Backs up Calibre-Web Automated data directories to Restic (S3).
# Designed to run via systemd timer.

set -euo pipefail

LOG_PREFIX="[cwa-backup]"
CWA_DATA="/opt/calibre-web/data"
TAG="calibre-web"

# Load Restic environment (repo URL, credentials, password file)
set -a && . /etc/restic/env && set +a

echo "$LOG_PREFIX Starting backup..."

# Back up config, library, and plugins directories directly
# Ingest is excluded — it's a temporary drop folder, files are removed after processing
restic backup \
  "$CWA_DATA/config" \
  "$CWA_DATA/library" \
  "$CWA_DATA/plugins" \
  --tag "$TAG"

# Prune old snapshots (keep 7 daily, 4 weekly, 2 monthly)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 2 --prune

echo "$LOG_PREFIX Backup completed successfully"
