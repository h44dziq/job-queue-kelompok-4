
#!/bin/bash

GRACE_PERIOD=5
MAX_TIMEOUT=3600
LOG_FILE="/var/lib/job-queue/queue.log"

if [ "$#" -lt 2 ]; then
    echo "Pemakaian: $0 <batas_detik> <script_job> [parameter]" >&2
    exit 2
fi

TIMEOUT_LIMIT="$1"
shift
JOB_SCRIPT="$1"

if [[ ! "$TIMEOUT_LIMIT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_LIMIT" -lt 1 ] || [ "$TIMEOUT_LIMIT" -gt "$MAX_TIMEOUT" ]; then
    echo "Galat: batas waktu harus 1-$MAX_TIMEOUT detik" >&2
    exit 2
fi

if [ ! -f "$JOB_SCRIPT" ] || [ ! -x "$JOB_SCRIPT" ]; then
    echo "Galat: script tidak ditemukan atau tidak executable: $JOB_SCRIPT" >&2
    exit 1
fi

JOB_NAME="$(basename "$JOB_SCRIPT" .sh)"
PID_FILE="$(mktemp)"

timeout --signal=TERM --kill-after="${GRACE_PERIOD}s" "${TIMEOUT_LIMIT}s" \
    bash -c 'echo "$BASHPID" > "$1"; shift; exec "$@"' _ "$PID_FILE" "$@"
EXIT_CODE=$?

JOB_PID="$(cat "$PID_FILE" 2>/dev/null)"
rm -f "$PID_FILE"

if [ "$EXIT_CODE" -eq 124 ]; then
    KETERANGAN="timeout ${TIMEOUT_LIMIT}s, dihentikan dengan SIGTERM"
elif [ "$EXIT_CODE" -eq 137 ]; then
    KETERANGAN="timeout ${TIMEOUT_LIMIT}s, dihentikan paksa dengan SIGKILL"
else
    KETERANGAN="selesai sebelum batas waktu ${TIMEOUT_LIMIT}s"
fi

echo "$(date '+%Y-%m-%d %H:%M:%S') | PID=${JOB_PID:--} | $(id -un) | $JOB_NAME | $KETERANGAN (exit $EXIT_CODE)" >> "$LOG_FILE" 2>/dev/null
echo "PID=${JOB_PID:--}"
exit "$EXIT_CODE"
