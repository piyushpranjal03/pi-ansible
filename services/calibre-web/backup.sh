#!/bin/bash
# Backs up Calibre-Web Automated data directories to Restic (S3).
# Designed to run via systemd timer.

set -euo pipefail

LOG_PREFIX="[cwa-backup]"
CWA_DATA="{{ cwa_dir }}/data"
TAG="calibre-web"
BACKUP_TIMEOUT=600

log_info()  { echo "$LOG_PREFIX [INFO] $1"; }
log_error() { echo "$LOG_PREFIX [ERROR] $1" >&2; }

# Load Restic environment (repo URL, credentials, password file)
set -a && . /etc/restic/env && set +a

log_info "Starting backup..."

# Back up config, library, and plugins directories directly
# Ingest is excluded — it's a temporary drop folder, files are removed after processing
timeout "$BACKUP_TIMEOUT" restic backup \
  "$CWA_DATA/config" \
  "$CWA_DATA/library" \
  "$CWA_DATA/plugins" \
  --tag "$TAG" || { log_error "Failed to upload backup to Restic (timed out or errored after ${BACKUP_TIMEOUT}s)"; exit 1; }

# Prune old snapshots (keep 7 daily, 4 weekly, 2 monthly)
restic forget --tag "$TAG" --keep-daily 7 --keep-weekly 4 --keep-monthly 2 --prune || log_error "Failed to prune old snapshots"

log_info "Backup completed successfully"
