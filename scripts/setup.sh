#!/bin/bash

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INSTALL_DIR="/opt/job-queue"
QUEUE_DIR="/var/lib/job-queue"

if [ "$(id -u)" -ne 0 ]; then
    echo "Ditolak: setup.sh harus dijalankan dengan sudo" >&2
    exit 5
fi

for GRUP in jobqueue jobqueueop; do
    getent group "$GRUP" > /dev/null || groupadd "$GRUP"
done

getent passwd operator1 > /dev/null || useradd -m -s /bin/bash -G jobqueue,jobqueueop operator1
getent passwd pengguna1 > /dev/null || useradd -m -s /bin/bash -G jobqueue pengguna1
getent passwd tamu1 > /dev/null || useradd -m -s /bin/bash tamu1

if [ -n "$SUDO_USER" ]; then
    usermod -aG jobqueue,jobqueueop "$SUDO_USER"
fi

mkdir -p "$INSTALL_DIR"
cp -r "$PROJECT_DIR/scripts" "$PROJECT_DIR/config" "$INSTALL_DIR/"
chown -R root:root "$INSTALL_DIR"
chmod -R u=rwX,go=rX "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR"/scripts/*.sh "$INSTALL_DIR"/scripts/jobs/*.sh

mkdir -p "$QUEUE_DIR"/{pending,running,done,failed,output}
touch "$QUEUE_DIR/queue.log" "$QUEUE_DIR/worker.lock"
chown -R root:jobqueue "$QUEUE_DIR"
chmod 2750 "$QUEUE_DIR"
chmod 2770 "$QUEUE_DIR"/{pending,running,done,failed,output}
chmod 660 "$QUEUE_DIR/queue.log"
chown root:jobqueueop "$QUEUE_DIR/worker.lock"
chmod 660 "$QUEUE_DIR/worker.lock"

echo "Setup selesai. Script terpasang di $INSTALL_DIR/scripts"
ls -ld "$QUEUE_DIR" "$QUEUE_DIR"/*
exit 0
