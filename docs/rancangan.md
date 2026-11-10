# Rancangan Sistem

## Lingkungan

| Komponen | Spesifikasi |
|----------|-------------|
| Sistem operasi | Ubuntu Server 22.04 LTS di VirtualBox |
| Mesin virtual | 3 CPU, RAM 2 GB, partisi root 11 GB |
| Shell | bash 5.1.16 |
| Docker | docker.io 29.1.3, image `alpine:3.20` |

Hasil pemeriksaan lingkungan aktual tersimpan di `evidence/lingkungan.txt`.

## Komponen

| Script | Fungsi | Dijalankan oleh |
|--------|--------|-----------------|
| `submit.sh` | Memeriksa dan memasukkan job ke antrean | operator1, pengguna1 |
| `worker.sh` | Menjalankan job sesuai urutan dan mencatat hasilnya | operator1 |
| `run_with_timeout.sh` | Menjalankan satu job dengan batas waktu 10 detik | worker.sh |
| `status.sh` | Menampilkan status, PID, dan exit status job | operator1, pengguna1 |
| `monitor.sh` | Mengamati penggunaan CPU dan memori job | operator1, pengguna1 |
| `laporan.sh` | Membuat ringkasan hasil job | operator1, pengguna1 |
| `setup.sh` | Menyiapkan akun, group, folder, dan permission | root |

## Alur job

```
pending/  ──►  running/  ──►  done/    (berhasil)
                         └──►  failed/  (gagal atau melewati batas waktu)
```

1. `submit.sh` memeriksa nama job dan parameter. Jika valid, file job dibuat di folder `pending/`.
2. `worker.sh` mengunci `worker.lock`. Jika kunci sudah dipakai worker lain, worker kedua langsung berhenti.
3. Worker mengambil job paling lama di `pending/`, memindahkannya ke `running/`, lalu menjalankannya.
4. Setelah job selesai, worker mencatat PID, exit status, dan status, lalu memindahkan file ke `done/` atau `failed/`.
5. Worker berhenti saat `pending/` sudah kosong.

## Struktur direktori

```
/opt/job-queue/          script dan konfigurasi, hanya dapat diubah root
/var/lib/job-queue/      data antrean, group jobqueue
├── pending/             job yang menunggu
├── running/             job yang sedang berjalan
├── done/                job yang berhasil
├── failed/              job yang gagal
├── output/              laporan, dibaca oleh container Docker
├── queue.log            catatan seluruh kejadian
└── worker.lock          kunci worker, group jobqueueop
```

## User, group, dan matriks akses

| Akun | Group | Mengajukan job | Menjalankan worker | Melihat status |
|------|-------|:--------------:|:------------------:|:--------------:|
| operator1 | jobqueue, jobqueueop | ✓ | ✓ | ✓ |
| pengguna1 | jobqueue | ✓ | ✗ | ✓ |
| tamu1 | - | ✗ | ✗ | ✗ |

Pembatasan dilakukan oleh permission Linux. `tamu1` tidak dapat membuka folder antrean karena bukan anggota group `jobqueue`. `pengguna1` tidak dapat menjalankan worker karena `worker.lock` hanya dapat dibuka group `jobqueueop`.

## Alasan rancangan

| Keputusan | Alasan |
|-----------|--------|
| Antrean berupa folder dan file | Status job mudah diperiksa dengan `ls` dan `cat` |
| Job dipindahkan dengan `mv` | Perpindahan terjadi sekaligus, sehingga satu job tidak dapat diambil dua kali |
| Worker dikunci dengan `flock` | Hanya satu worker yang berjalan, dan kunci terlepas otomatis jika worker berhenti |
| Hanya ada satu kunci | Tidak ada proses yang saling menunggu, sehingga deadlock tidak terjadi |
| Batas waktu dengan `timeout` | Job yang terlalu lama dihentikan agar antrean tidak macet |
| Script dipisah dari data | Pengguna dapat memakai antrean tanpa dapat mengubah script |
| Docker hanya membaca `output/` | Container cukup membaca laporan tanpa akses ke data antrean lain |
