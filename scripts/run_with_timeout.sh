
#!/bin/bash


# SISTEM ANTREAN PEKERJAAN LINUX
# Anggota 4: Timeout dan Penghentian
# ==========================================

# Konfigurasi
GRACE_PERIOD=5
MAX_TIMEOUT=3600

# Validasi jumlah argumen
if [ "$#" -lt 2 ]; then
    echo "Pemakaian: $0 <batas_detik> <script_job> [parameter]"
    exit 2
fi

TIMEOUT_LIMIT="$1"
shift

JOB_SCRIPT="$1"

# Validasi batas waktu
if [[ ! "$TIMEOUT_LIMIT" =~ ^[0-9]+$ ]] || [ "$TIMEOUT_LIMIT" -lt 1 ]; then
    echo "ERROR: Batas waktu harus berupa angka minimal 1 detik."
    exit 2
fi

if [ "$TIMEOUT_LIMIT" -gt "$MAX_TIMEOUT" ]; then
    echo "ERROR: Batas waktu maksimal $MAX_TIMEOUT detik."
    exit 2
fi

# Validasi script pekerjaan
if [ ! -f "$JOB_SCRIPT" ]; then
    echo "ERROR: Script pekerjaan tidak ditemukan: $JOB_SCRIPT"
    exit 2
fi

if [ ! -x "$JOB_SCRIPT" ]; then
    echo "ERROR: Script pekerjaan tidak memiliki izin eksekusi."
    exit 2
fi

echo "=========================================="
echo "Memulai pekerjaan: $JOB_SCRIPT"
echo "PID wrapper: $$"
echo "Batas waktu: $TIMEOUT_LIMIT detik"
echo "Grace period: $GRACE_PERIOD detik"
echo "=========================================="

# Menjalankan pekerjaan dengan timeout
timeout \
    --signal=TERM \
    --kill-after="${GRACE_PERIOD}s" \
    "${TIMEOUT_LIMIT}s" \
    "$@"

EXIT_CODE=$?

echo "------------------------------------------"

# Memeriksa hasil pekerjaan
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "STATUS: SUCCESS"
    echo "Pekerjaan selesai sebelum timeout."

elif [ "$EXIT_CODE" -eq 124 ]; then
    echo "STATUS: TIMEOUT"
    echo "Pekerjaan melewati batas waktu."
    echo "Sinyal SIGTERM telah dikirim."

elif [ "$EXIT_CODE" -eq 137 ]; then
    echo "STATUS: TIMEOUT"
    echo "Proses melewati batas waktu."
    echo "Proses dihentikan paksa dengan SIGKILL."

else
    echo "STATUS: FAILED"
    echo "Pekerjaan gagal dengan exit status: $EXIT_CODE"
fi

echo "Exit status: $EXIT_CODE"
echo "------------------------------------------"

exit "$EXIT_CODE"
