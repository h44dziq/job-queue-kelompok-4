#!/bin/bash

QUEUE_DIR="/var/lib/job-queue"
OUTPUT_DIR="$QUEUE_DIR/output"
LAPORAN="$OUTPUT_DIR/laporan.txt"

if [ ! -w "$OUTPUT_DIR" ]; then
    echo "Ditolak: akses ditolak, $(id -un) tidak berhak membuat laporan" >&2
    exit 5
fi

hitung() {
    ls "$QUEUE_DIR/$1" | grep -c '\.job$'
}

{
    echo "LAPORAN ANTREAN PEKERJAAN"
    echo "Dibuat: $(date '+%Y-%m-%d %H:%M:%S') oleh $(id -un)"
    echo
    echo "MENUNGGU : $(hitung pending)"
    echo "BERJALAN : $(hitung running)"
    echo "BERHASIL : $(hitung done)"
    echo "GAGAL    : $(hitung failed)"
    echo
    printf '%-36s %-9s %-8s %-5s %s\n' "ID_JOB" "STATUS" "PID" "EXIT" "PENGAJU"
    for pasangan in done:BERHASIL failed:GAGAL; do
        DIR="$QUEUE_DIR/${pasangan%%:*}"
        STATUS="${pasangan##*:}"
        for FILE_JOB in $(ls "$DIR" | grep '\.job$' | sort); do
            PID_JOB=$(grep '^PID=' "$DIR/$FILE_JOB" | cut -d= -f2)
            KODE=$(grep '^EXIT=' "$DIR/$FILE_JOB" | cut -d= -f2)
            PENGAJU=$(grep '^PENGAJU=' "$DIR/$FILE_JOB" | cut -d= -f2)
            printf '%-36s %-9s %-8s %-5s %s\n' "${FILE_JOB%.job}" "$STATUS" "${PID_JOB:--}" "${KODE:--}" "${PENGAJU:--}"
        done
    done
} > "$LAPORAN"

echo "Laporan dibuat: $LAPORAN"
exit 0
