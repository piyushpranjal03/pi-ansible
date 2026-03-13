#!/bin/bash
# Monitors frigate container memory usage and restarts it if threshold is exceeded.
# Designed to run as a sidecar container with Docker socket mounted.

CONTAINER_NAME="frigate"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-80}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
LOG_FILE="/app/logs/memory-monitor.log"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') | $1" | tee -a "$LOG_FILE"
}

log "Memory monitor started (threshold: ${MEMORY_THRESHOLD}%, interval: ${CHECK_INTERVAL}s)"

while true; do
  MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemPerc}}" "$CONTAINER_NAME" 2>/dev/null | tr -d '%')

  if [ -z "$MEMORY_USAGE" ]; then
    log "WARNING: Could not read memory stats for ${CONTAINER_NAME}"
    sleep "$CHECK_INTERVAL"
    continue
  fi

  MEMORY_INT=${MEMORY_USAGE%.*}
  log "Memory usage: ${MEMORY_USAGE}%"

  if [ "$MEMORY_INT" -gt "$MEMORY_THRESHOLD" ]; then
    log "Memory ${MEMORY_USAGE}% exceeds ${MEMORY_THRESHOLD}%. Restarting ${CONTAINER_NAME}..."
    docker restart "$CONTAINER_NAME"
    log "Container restarted"
  fi

  sleep "$CHECK_INTERVAL"
done
