#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
JOBS_DIR="$SCRIPT_DIR/jobs"
QUEUE_DIR="/var/lib/job-queue"
PENDING_DIR="$QUEUE_DIR/pending"
RUNNING_DIR="$QUEUE_DIR/running"
DONE_DIR="$QUEUE_DIR/done"
LOCK_FILE="$QUEUE_DIR/worker.lock"
LOG_FILE="$QUEUE_DIR/queue.log"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | PID=$$ | $(id -un) | worker | $1" >> "$LOG_FILE" 2>/dev/null
}

if ! exec 9>>"$LOCK_FILE"; then
    echo "Ditolak: akses ditolak, tidak bisa membuka $LOCK_FILE" >&2
    exit 5
fi

if ! flock -n 9; then
    echo "Ditolak: worker lain sedang berjalan" >&2
    log_msg "ditolak (worker lain sedang berjalan)"
    exit 6
fi

log_msg "mulai"

sleep 15

log_msg "selesai, antrean kosong"
echo "Antrean kosong, worker berhenti."
exit 0
