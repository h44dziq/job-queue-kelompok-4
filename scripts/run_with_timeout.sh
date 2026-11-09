
#!/bin/bash

# SISTEM ANTREAN PEKERJAAN LINUX
# Anggota 4: Timeout dan Penghentian
# ==========================================

GRACE_PERIOD=5
MAX_TIMEOUT=3600

# Lokasi project dan log
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
LOG_FILE="$LOG_DIR/timeout.log"

mkdir -p "$LOG_DIR"

# Validasi argumen
if [ "$#" -lt 2 ]; then
    echo "Pemakaian: $0 <batas_detik> <script_job> [parameter]"
    exit 2
fi

TIMEOUT_LIMIT="$1"
shift

JOB_SCRIPT="$1"

# Validasi timeout
if [[ ! "$TIMEOUT_LIMIT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_LIMIT" -lt 1 ]; then
    echo "ERROR: Batas waktu harus minimal 1 detik."
    exit 2
fi

if [ "$TIMEOUT_LIMIT" -gt "$MAX_TIMEOUT" ]; then
    echo "ERROR: Batas waktu maksimal $MAX_TIMEOUT detik."
    exit 2
fi

# Validasi script
if [ ! -f "$JOB_SCRIPT" ] || [ ! -x "$JOB_SCRIPT" ]; then
    echo "ERROR: Script tidak ditemukan atau tidak executable."
    exit 2
fi

JOB_NAME="$(basename "$JOB_SCRIPT")"

# File sementara untuk menyimpan PID pekerjaan
PID_FILE="$(mktemp)"

echo "=========================================="
echo "Memulai pekerjaan: $JOB_NAME"
echo "PID wrapper: $$"
echo "Batas waktu: $TIMEOUT_LIMIT detik"
echo "Grace period: $GRACE_PERIOD detik"
echo "=========================================="

# Menjalankan pekerjaan dan menangkap PID proses sebenarnya
timeout \
    --signal=TERM \
    --kill-after="${GRACE_PERIOD}s" \
    "${TIMEOUT_LIMIT}s" \
    bash -c '
        echo "$BASHPID" > "$1"
        shift
        exec "$@"
    ' _ "$PID_FILE" "$@" &

TIMEOUT_PID=$!

# Menunggu proses selesai
wait "$TIMEOUT_PID"
EXIT_CODE=$?

# Membaca PID pekerjaan
if [ -s "$PID_FILE" ]; then
    JOB_PID="$(cat "$PID_FILE")"
else
    JOB_PID="Tidak tersedia"
fi

rm -f "$PID_FILE"

# Menentukan status pekerjaan
if [ "$EXIT_CODE" -eq 0 ]; then
    STATUS="SUCCESS"
    KETERANGAN="Pekerjaan berhasil diselesaikan"

elif [ "$EXIT_CODE" -eq 124 ] || [ "$EXIT_CODE" -eq 137 ]; then
    STATUS="TIMEOUT"

    if [ "$EXIT_CODE" -eq 137 ]; then
        KETERANGAN="Dihentikan paksa menggunakan SIGKILL"
    else
        KETERANGAN="Dihentikan setelah SIGTERM"
    fi

else
    STATUS="FAILED"
    KETERANGAN="Pekerjaan gagal dengan exit status $EXIT_CODE"
fi

# Mencatat hasil pekerjaan
WAKTU="$(date '+%Y-%m-%d %H:%M:%S')"

echo "$WAKTU | JOB=$JOB_NAME | PID=$JOB_PID | TIMEOUT=${TIMEOUT_LIMIT}s | STATUS=$STATUS | EXIT=$EXIT_CODE | $KETERANGAN" >> "$LOG_FILE"

# Menampilkan hasil
echo "------------------------------------------"
echo "Nama pekerjaan : $JOB_NAME"
echo "PID pekerjaan : $JOB_PID"
echo "STATUS        : $STATUS"
echo "Keterangan    : $KETERANGAN"
echo "Exit status   : $EXIT_CODE"
echo "Log           : $LOG_FILE"
echo "------------------------------------------"

exit "$EXIT_CODE"
