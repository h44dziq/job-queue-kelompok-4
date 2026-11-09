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

while true; do
    FILE_JOB=$(ls "$PENDING_DIR" | grep '\.job$' | sort | head -n 1)
    if [ -z "$FILE_JOB" ]; then
        break
    fi

    ID_JOB="${FILE_JOB%.job}"
    if ! mv "$PENDING_DIR/$FILE_JOB" "$RUNNING_DIR/$FILE_JOB"; then
        log_msg "$ID_JOB galat (gagal dipindah ke running)"
        exit 1
    fi

    JOB=$(grep '^JOB=' "$RUNNING_DIR/$FILE_JOB" | cut -d= -f2)
    PARAM=$(grep '^PARAM=' "$RUNNING_DIR/$FILE_JOB" | cut -d= -f2)

    echo "Menjalankan $ID_JOB"
    log_msg "$ID_JOB berjalan"
    bash "$JOBS_DIR/$JOB.sh" "$PARAM" > "$RUNNING_DIR/$ID_JOB.out" 2>&1

    mv "$RUNNING_DIR/$FILE_JOB" "$RUNNING_DIR/$ID_JOB.out" "$DONE_DIR/"
    log_msg "$ID_JOB selesai"
done

log_msg "selesai, antrean kosong"
echo "Antrean kosong, worker berhenti."
exit 0
