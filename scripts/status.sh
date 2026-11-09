#!/bin/bash

QUEUE_DIR="/var/lib/job-queue"

if [ ! -r "$QUEUE_DIR/pending" ] || [ ! -x "$QUEUE_DIR/pending" ]; then
    echo "Ditolak: akses ditolak, $(id -un) tidak berhak melihat status" >&2
    exit 5
fi

printf '%-36s %-10s %-8s %s\n' "ID_JOB" "STATUS" "PID" "EXIT"
for pasangan in pending:MENUNGGU running:BERJALAN done:BERHASIL failed:GAGAL; do
    DIR="$QUEUE_DIR/${pasangan%%:*}"
    STATUS="${pasangan##*:}"
    for FILE_JOB in $(ls "$DIR" | grep '\.job$' | sort); do
        PID_JOB=$(grep '^PID=' "$DIR/$FILE_JOB" | cut -d= -f2)
        KODE=$(grep '^EXIT=' "$DIR/$FILE_JOB" | cut -d= -f2)
        printf '%-36s %-10s %-8s %s\n' "${FILE_JOB%.job}" "$STATUS" "${PID_JOB:--}" "${KODE:--}"
    done
done
exit 0
