#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ALLOWED_FILE="$PROJECT_DIR/config/allowed_jobs.txt"
JOBS_DIR="$SCRIPT_DIR/jobs"
QUEUE_DIR="/var/lib/job-queue"
PENDING_DIR="$QUEUE_DIR/pending"
LOG_FILE="$QUEUE_DIR/queue.log"
PENGAJU="$(id -un)"

log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') | PID=$$ | $PENGAJU | $1 | $2" >> "$LOG_FILE" 2>/dev/null
}

tolak() {
    echo "Ditolak: $3" >&2
    log_msg "$2" "ditolak ($3)"
    exit "$1"
}

if [ "$#" -ne 2 ]; then
    echo "Pemakaian: $0 <nama_job> <parameter>" >&2
    exit 2
fi

NAMA_JOB="$1"
PARAM="$2"

if [ ! -d "$PENDING_DIR" ] || [ ! -w "$PENDING_DIR" ]; then
    echo "Ditolak: akses ditolak, $PENGAJU tidak berhak mengajukan job" >&2
    exit 5
fi

if [ ! -f "$ALLOWED_FILE" ]; then
    echo "Galat: file whitelist tidak ditemukan: $ALLOWED_FILE" >&2
    exit 1
fi

RENTANG=""
while read -r job min maks || [ -n "$job" ]; do
    if [ "$job" = "$NAMA_JOB" ]; then
        RENTANG="$min ${maks%$'\r'}"
        break
    fi
done < "$ALLOWED_FILE"

if [ -z "$RENTANG" ] || [ ! -f "$JOBS_DIR/$NAMA_JOB.sh" ]; then
    tolak 3 "$NAMA_JOB" "job '$NAMA_JOB' tidak diizinkan"
fi
read -r MIN MAKS <<< "$RENTANG"

if [[ ! "$PARAM" =~ ^[0-9]{1,6}$ ]]; then
    tolak 4 "$NAMA_JOB" "parameter '$PARAM' harus berupa angka"
fi

PARAM=$((10#$PARAM))

if [ "$PARAM" -lt "$MIN" ] || [ "$PARAM" -gt "$MAKS" ]; then
    tolak 4 "$NAMA_JOB" "parameter $PARAM di luar rentang $MIN-$MAKS"
fi

ID_JOB="$(date '+%Y%m%d%H%M%S%N')_${NAMA_JOB}"
FILE_TMP="$PENDING_DIR/.$ID_JOB.tmp"

if ! printf 'JOB=%s\nPARAM=%s\nPENGAJU=%s\n' "$NAMA_JOB" "$PARAM" "$PENGAJU" > "$FILE_TMP" \
    || ! mv "$FILE_TMP" "$PENDING_DIR/$ID_JOB.job"; then
    rm -f "$FILE_TMP"
    echo "Galat: gagal menulis file job" >&2
    log_msg "$NAMA_JOB" "galat (gagal menulis file job)"
    exit 1
fi

log_msg "$NAMA_JOB" "menunggu ($ID_JOB)"
echo "Job diterima: $ID_JOB (parameter $PARAM)"
exit 0
