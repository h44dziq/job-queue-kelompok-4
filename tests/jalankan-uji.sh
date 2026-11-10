#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
EVIDENCE_DIR="$PROJECT_DIR/evidence"
BIN="/opt/job-queue/scripts"
QUEUE_DIR="/var/lib/job-queue"
LOG_FILE="$QUEUE_DIR/queue.log"
IMAGE="alpine:3.20"

if [ "$(id -u)" -ne 0 ]; then
    echo "Ditolak: jalankan dengan sudo" >&2
    exit 5
fi

if [ ! -x "$BIN/submit.sh" ] || [ ! -d "$QUEUE_DIR" ]; then
    echo "Galat: jalankan sudo ./scripts/setup.sh dulu" >&2
    exit 1
fi

mkdir -p "$EVIDENCE_DIR"

jalankan() {
    echo "\$ $*"
    "$@" 2>&1
    echo "exit=$?"
    echo
}

kosongkan() {
    rm -f "$QUEUE_DIR"/{pending,running,done,failed}/*
}

mulai() {
    kosongkan
    BARIS_LOG=$(wc -l < "$LOG_FILE")
    echo "== $1 | $(date '+%Y-%m-%d %H:%M:%S') | $(hostname)"
    echo
}

log_baru() {
    echo "\$ potongan queue.log"
    tail -n +"$((BARIS_LOG + 1))" "$LOG_FILE"
    echo
}

lingkungan() {
    echo "== Lingkungan | $(date '+%Y-%m-%d %H:%M:%S')"
    echo
    jalankan lsb_release -d
    jalankan uname -r
    jalankan nproc
    jalankan free -h
    jalankan bash -c 'echo "$BASH_VERSION"'
    jalankan docker --version
    jalankan docker image ls "$IMAGE"
    jalankan id operator1 pengguna1 tamu1
}

u1() {
    mulai "U1 Pengajuan pekerjaan"
    echo "-- Positif"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_ringan 5
    jalankan ls "$QUEUE_DIR/pending"
    echo "-- Negatif"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" rm 5
    jalankan ls "$QUEUE_DIR/pending"
    log_baru
    kosongkan
}

u2() {
    mulai "U2 Antrean FIFO dan lock worker"
    echo "-- Positif"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_ringan 1
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_gagal 2
    jalankan sudo -u operator1 "$BIN/worker.sh"
    log_baru
    echo "-- Negatif"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_lama 5
    echo "\$ sudo -u operator1 $BIN/worker.sh &"
    sudo -u operator1 "$BIN/worker.sh" > /dev/null 2>&1 &
    PID_WORKER=$!
    sleep 1
    jalankan sudo -u operator1 "$BIN/worker.sh"
    wait "$PID_WORKER"
    log_baru
    kosongkan
}

u3() {
    mulai "U3 Status dan exit status"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_ringan 1
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_gagal 3
    jalankan sudo -u operator1 "$BIN/worker.sh"
    echo "-- Positif"
    jalankan sh -c "cat $QUEUE_DIR/done/*.job"
    echo "-- Negatif"
    jalankan sh -c "cat $QUEUE_DIR/failed/*.job"
    jalankan sudo -u pengguna1 "$BIN/status.sh"
    log_baru
    kosongkan
}

u4() {
    mulai "U4 Timeout dan penghentian"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_lama 3
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_lama 20
    echo "\$ date +%T"
    date +%T
    echo
    jalankan sudo -u operator1 "$BIN/worker.sh"
    echo "\$ date +%T"
    date +%T
    echo
    echo "-- Positif: job_lama 3 selesai sebelum batas 10 detik"
    echo "-- Negatif: job_lama 20 dihentikan setelah 10 detik"
    jalankan sudo -u pengguna1 "$BIN/status.sh"
    log_baru
    kosongkan
}

u5() {
    mulai "U5 Akses, laporan, dan Docker"
    echo "-- Pembatasan akses"
    jalankan sudo -u tamu1 "$BIN/submit.sh" job_ringan 1
    echo "-- Laporan"
    jalankan sudo -u pengguna1 "$BIN/submit.sh" job_ringan 1
    jalankan sudo -u operator1 "$BIN/worker.sh"
    jalankan sudo -u operator1 "$BIN/laporan.sh"
    echo "-- Docker positif"
    jalankan docker run --rm --mount type=bind,src="$QUEUE_DIR/output",dst=/data,readonly "$IMAGE" cat /data/laporan.txt
    echo "-- Docker negatif"
    jalankan sha256sum "$QUEUE_DIR/output/laporan.txt"
    jalankan docker run --rm --mount type=bind,src="$QUEUE_DIR/output",dst=/data,readonly "$IMAGE" sh -c 'echo "uji perubahan" >> /data/laporan.txt'
    jalankan sha256sum "$QUEUE_DIR/output/laporan.txt"
    kosongkan
}

monitor() {
    mulai "Monitoring CPU dan memori"
    for DETIK in 3 8; do
        echo "-- Beban job_ringan $DETIK detik"
        jalankan uptime
        jalankan sudo -u pengguna1 "$BIN/submit.sh" job_ringan "$DETIK"
        sudo -u operator1 "$BIN/worker.sh" > /dev/null 2>&1 &
        PID_WORKER=$!
        sleep 1
        jalankan "$BIN/monitor.sh" "$((DETIK - 1))"
        wait "$PID_WORKER"
        jalankan uptime
        kosongkan
    done
}

lingkungan > "$EVIDENCE_DIR/lingkungan.txt"
u1 > "$EVIDENCE_DIR/U1-pengajuan.txt"
u2 > "$EVIDENCE_DIR/U2-fifo-lock.txt"
u3 > "$EVIDENCE_DIR/U3-status-exit.txt"
u4 > "$EVIDENCE_DIR/U4-timeout.txt"
u5 > "$EVIDENCE_DIR/U5-akses-laporan-docker.txt"
monitor > "$EVIDENCE_DIR/monitor.txt"

if [ -n "$SUDO_USER" ]; then
    chown -R "$SUDO_USER": "$EVIDENCE_DIR"
fi

echo "Bukti tersimpan di $EVIDENCE_DIR"
ls -l "$EVIDENCE_DIR"
exit 0
