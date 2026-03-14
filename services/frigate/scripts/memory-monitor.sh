#!/bin/bash
# Monitors frigate container memory usage and restarts it if threshold is exceeded.
# Designed to run as a sidecar container with Docker socket mounted.
# Logs go to stdout → Docker logs → Promtail → Loki.

CONTAINER_NAME="frigate"
MEMORY_THRESHOLD="${MEMORY_THRESHOLD:-80}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
LOG_PREFIX="[memory-monitor]"

log_info()  { echo "$LOG_PREFIX [INFO] $1"; }
log_warn()  { echo "$LOG_PREFIX [WARN] $1"; }
log_error() { echo "$LOG_PREFIX [ERROR] $1" >&2; }

log_info "Memory monitor started (threshold: ${MEMORY_THRESHOLD}%, interval: ${CHECK_INTERVAL}s)"

while true; do
  MEMORY_USAGE=$(docker stats --no-stream --format "{{.MemPerc}}" "$CONTAINER_NAME" 2>/dev/null | tr -d '%')

  if [ -z "$MEMORY_USAGE" ]; then
    log_warn "Could not read memory stats for ${CONTAINER_NAME}"
    sleep "$CHECK_INTERVAL"
    continue
  fi

  MEMORY_INT=${MEMORY_USAGE%.*}
  log_info "Memory usage: ${MEMORY_USAGE}%"

  if [ "$MEMORY_INT" -gt "$MEMORY_THRESHOLD" ]; then
    log_warn "Memory ${MEMORY_USAGE}% exceeds ${MEMORY_THRESHOLD}%. Restarting ${CONTAINER_NAME}..."
    docker restart "$CONTAINER_NAME" && log_info "Container restarted successfully" || log_error "Failed to restart ${CONTAINER_NAME}"
  fi

  sleep "$CHECK_INTERVAL"
done
