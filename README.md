# Sistem Antrean Pekerjaan dan Monitoring Proses Linux


## Anggota

| No | Nama | NIM | Tanggung jawab |
|----|------|-----|----------------|
| 1 | Muhammad Hadziq | 2510512031 | Pengajuan pekerjaan |
| 2 | Arvin Maulana | 2510512021 | Antrean dan lock |
| 3 | Radhitya | ... | Status dan exit status |
| 4 | Erlang Yudantara | 2510512001 | Timeout dan penghentian |
| 5 | Andika | 2510512016 | Monitoring, akses, laporan, dan Docker |

## Lingkungan

| Komponen | Versi |
|----------|-------|
| OS | Ubuntu Server 22.04 LTS di VirtualBox |
| VM | 3 CPU, RAM 3 GB, disk 15 GB |
| Shell | bash 5.1 |
| Docker | docker.io dari repository Ubuntu, image `alpine:3.20` |

Hasil pemeriksaan lengkap ada di `evidence/lingkungan.txt`.

## Struktur repository

```
scripts/        submit.sh, worker.sh, run_with_timeout.sh, status.sh, monitor.sh, laporan.sh, setup.sh
scripts/jobs/   job dummy yang diizinkan: job_ringan, job_gagal, job_lama
config/         daftar job yang diizinkan beserta rentang parameternya
tests/          skenario uji per anggota dan kumpulkan-bukti.sh
evidence/       hasil uji dari VM
docs/           rancangan sistem dan analisis konsep
```

Rancangan lengkap (alur, struktur direktori, matriks akses, exit status) ada di `docs/rancangan.md`.

## Instalasi

```bash
sudo apt install -y git docker.io
```

```bash
git clone https://github.com/h44dziq/job-queue-kelompok-4.git && cd job-queue-kelompok-4
```

```bash
sudo ./scripts/setup.sh
```

`setup.sh` membuat group `jobqueue` dan `jobqueueop`, akun uji `operator1`, `pengguna1`, `tamu1`, memasang script ke `/opt/job-queue`, dan membuat `/var/lib/job-queue` dengan permission yang sesuai. Akun yang menjalankan `sudo` ikut dimasukkan ke kedua group, jadi logout lalu login lagi setelah setup.

## Cara menjalankan

Mengajukan job

```bash
sudo -u pengguna1 /opt/job-queue/scripts/submit.sh job_ringan 5
```

Menjalankan worker sampai antrean kosong:

```bash
sudo -u operator1 /opt/job-queue/scripts/worker.sh
```

Melihat status:

```bash
/opt/job-queue/scripts/status.sh
```

Mengamati CPU dan memori job yang sedang berjalan (5 sampel, satu per detik):

```bash
/opt/job-queue/scripts/monitor.sh 5
```

Membuat laporan:

```bash
sudo -u operator1 /opt/job-queue/scripts/laporan.sh
```

| Exit | Arti |
|------|------|
| 0 | berhasil |
| 1 | galat umum |
| 2 | cara pakai salah |
| 3 | job tidak diizinkan |
| 4 | parameter tidak valid |
| 5 | akses ditolak |
| 6 | worker lain sedang berjalan |

## Pengujian

```bash
sudo ./tests/kumpulkan-bukti.sh
```

Semua skenario dijalankan dan hasilnya disimpan ke `evidence/`. Matriks skenario ada di `tests/README.md`.

## Aktivitas Docker

Container membaca laporan dari host melalui bind mount read-only. Hanya folder `output/` yang di-mount.

```bash
docker pull alpine:3.20
```

Positif, laporan terbaca dan exit 0:

```bash
docker run --rm --mount type=bind,src=/var/lib/job-queue/output,dst=/data,readonly alpine:3.20 cat /data/laporan.txt; echo "exit=$?"
```

Negatif, penulisan ditolak dan checksum tidak berubah:

```bash
sha256sum /var/lib/job-queue/output/laporan.txt
```

```bash
docker run --rm --mount type=bind,src=/var/lib/job-queue/output,dst=/data,readonly alpine:3.20 sh -c 'echo "uji perubahan" >> /data/laporan.txt'; echo "exit=$?"
```

```bash
sha256sum /var/lib/job-queue/output/laporan.txt
```

## Pembersihan dan pemulihan

Mengosongkan antrean:

```bash
sudo rm -f /var/lib/job-queue/{pending,running,done,failed}/*
```

Kalau worker berhenti di tengah jalan, job tertinggal di `running/`. Kembalikan ke antrean lalu jalankan worker lagi:

```bash
sudo sh -c 'mv /var/lib/job-queue/running/*.job /var/lib/job-queue/pending/; rm -f /var/lib/job-queue/running/*.out'
```

Kalau permission berubah, jalankan ulang `setup.sh`. Data job yang ada tidak dihapus.

```bash
sudo ./scripts/setup.sh
```

Menghapus seluruh sistem:

```bash
sudo rm -rf /opt/job-queue /var/lib/job-queue && sudo userdel -r operator1 && sudo userdel -r pengguna1 && sudo userdel -r tamu1 && sudo groupdel jobqueueop && sudo groupdel jobqueue
```

## Kontribusi

| Nama | Komponen | Skenario | Pull request |
|------|----------|----------|--------------|
| Muhammad Hadziq | `submit.sh`, `config/allowed_jobs.txt`, `scripts/jobs/`, | U1 | #1, #4 |
| Arvin Maulana | `worker.sh` (lock dan FIFO) | U2 | #3 |
| Radhitya | `status.sh`, pencatatan PID dan exit status di `worker.sh` | U3 | #8 |
| Erlang Yudantara | `run_with_timeout.sh` | U4 | #6, #7 |
| Andika | `setup.sh`, `monitor.sh`, `laporan.sh`, Docker | U5 | #9 |
