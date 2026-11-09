#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ALLOWED_FILE="$PROJECT_DIR/config/allowed_jobs.txt"
JOBS_DIR="$SCRIPT_DIR/jobs"
QUEUE_DIR="/var/lib/job-queue"
PENDING_DIR="$QUEUE_DIR/pending"
LOG_FILE="$QUEUE_DIR/queue.log"
MAX_PARAM_LEN=10

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | PID=$$ | $1 | $2" >> "$LOG_FILE"
}

if ! mkdir -p "$QUEUE_DIR"/{pending,running,done,failed}; then
    echo "Galat: gagal membuat folder antrean di $QUEUE_DIR" >&2
    exit 1
fi

if [ "$#" -ne 2 ]; then
    echo "Pemakaian: $0 <nama_job> <parameter>" >&2
    exit 2
fi

NAMA_JOB="$1"
PARAM="$2"

if [ ! -f "$ALLOWED_FILE" ]; then
    echo "Galat: file whitelist tidak ditemukan: $ALLOWED_FILE" >&2
    exit 1
fi

DIIZINKAN=0
while IFS= read -r job || [ -n "$job" ]; do
    job="${job%$'\r'}"
    if [ "$job" = "$NAMA_JOB" ]; then
        DIIZINKAN=1
        break
    fi
done < "$ALLOWED_FILE"

if [ "$DIIZINKAN" -ne 1 ]; then
    echo "Ditolak: job '$NAMA_JOB' tidak diizinkan" >&2
    log_msg "$NAMA_JOB" "ditolak (job tidak diizinkan)"
    exit 3
fi

if [ ! -f "$JOBS_DIR/$NAMA_JOB.sh" ]; then
    echo "Ditolak: script job '$NAMA_JOB.sh' tidak ditemukan" >&2
    log_msg "$NAMA_JOB" "ditolak (script tidak ada)"
    exit 3
fi

if [[ ! "$PARAM" =~ ^[0-9]+$ ]]; then
    echo "Ditolak: parameter '$PARAM' harus berupa angka" >&2
    log_msg "$NAMA_JOB" "ditolak (parameter bukan angka)"
    exit 4
fi

if [ "${#PARAM}" -gt "$MAX_PARAM_LEN" ]; then
    echo "Ditolak: parameter terlalu panjang (maks $MAX_PARAM_LEN digit)" >&2
    log_msg "$NAMA_JOB" "ditolak (parameter terlalu panjang)"
    exit 4
fi

PARAM=$((10#$PARAM))

TIMESTAMP="$(date '+%Y%m%d%H%M%S%N')"
FILE_JOB="$PENDING_DIR/${TIMESTAMP}_${NAMA_JOB}.job"

if ! printf 'JOB=%s\nPARAM=%s\n' "$NAMA_JOB" "$PARAM" > "$FILE_JOB"; then
    echo "Galat: gagal menulis file job" >&2
    log_msg "$NAMA_JOB" "galat (gagal menulis file job)"
    exit 1
fi

log_msg "$NAMA_JOB" "menunggu"
echo "Job diterima: $NAMA_JOB (parameter $PARAM)"
exit 0
