# Pengujian

Setiap anggota menguji satu paket skenario: satu kondisi positif dan satu kondisi negatif. Penolakan yang benar pada uji negatif dihitung sebagai berhasil. Seluruh pengujian dijalankan pada Ubuntu Server 22.04 (lihat `evidence/lingkungan.txt`).

## Prasyarat umum

- `sudo ./scripts/setup.sh` sudah dijalankan, sehingga akun `operator1`, `pengguna1`, `tamu1` dan folder antrean tersedia.
- Image `alpine:3.20` sudah diunduh.
- Antrean kosong sebelum setiap skenario.

## Pemulihan

Setelah setiap skenario antrean dikosongkan:

```bash
sudo rm -f /var/lib/job-queue/{pending,running,done,failed}/*
```

## Matriks skenario dan hasil

| ID | Penanggung jawab | Positif | Negatif | Hasil aktual | Status | Bukti |
|----|------------------|---------|---------|--------------|:------:|-------|
| U1 | Muhammad Hadziq | `submit.sh job_ringan 5` diterima | `submit.sh rm 5` ditolak | Positif: exit 0, file masuk `pending/`. Negatif: exit 3, `pending/` tidak bertambah | Lulus | `evidence/U1-pengajuan.txt` |
| U2 | Arvin Maulana | Dua job dijalankan sesuai urutan masuk | Worker kedua ditolak saat worker pertama aktif | Positif: `job_ringan` berjalan sebelum `job_gagal`. Negatif: exit 6, "worker lain sedang berjalan" | Lulus | `evidence/U2-fifo-lock.txt` |
| U3 | Radhitya | `job_ringan 1` tercatat BERHASIL | `job_gagal 3` tercatat GAGAL | Positif: `EXIT=0`, `STATUS=BERHASIL`. Negatif: `EXIT=3`, `STATUS=GAGAL` | Lulus | `evidence/U3-status-exit.txt` |
| U4 | Erlang Yudantara | `job_lama 3` selesai sebelum batas | `job_lama 20` dihentikan | Positif: BERHASIL, exit 0. Negatif: dihentikan SIGTERM setelah 10 detik, exit 124, GAGAL | Lulus | `evidence/U4-timeout.txt` |
| U5 | Andika | Container membaca `laporan.txt` | Container menulis ke mount read-only | Positif: laporan tampil, exit 0. Negatif: "Read-only file system", exit 1, checksum sama sebelum dan sesudah | Lulus | `evidence/U5-akses-laporan-docker.txt` |

Pengujian tambahan yang diwajibkan modul, dipegang Andika:

| Pengujian | Langkah | Hasil aktual | Status | Bukti |
|-----------|---------|--------------|:------:|-------|
| Pembatasan akses | `tamu1` menjalankan `submit.sh` | Ditolak, exit 5 | Lulus | `evidence/U5-akses-laporan-docker.txt` |
| Monitoring CPU dan memori | `monitor.sh` saat `job_ringan` 3 dan 8 detik | CPU job 88–99%, RSS sekitar 1,4 MB pada kedua beban | Lulus | `evidence/monitor.txt` |

## Pembahasan

**U1, pengajuan.** Job hanya diterima jika namanya ada di `config/allowed_jobs.txt` dan parameternya dalam rentang. `rm` ditolak sebelum menyentuh antrean, jadi pengguna tidak dapat menjalankan perintah sembarang. Ini bentuk proteksi: daftar job yang diizinkan ditentukan oleh administrator, bukan pengguna. File job ditulis ke file sementara lalu dipindah dengan `mv`, sehingga worker tidak pernah membaca file yang belum selesai ditulis.

**U2, FIFO dan lock.** Urutan eksekusi mengikuti nama file yang diawali waktu pengajuan. Ini antrean tingkat aplikasi, bukan penjadwalan CPU oleh kernel. Worker memakai `flock -n` pada `worker.lock`, sehingga worker kedua langsung ditolak (exit 6) dan satu job tidak dapat diproses dua kali. Karena hanya ada satu kunci dan worker tidak menunggu kunci milik proses lain, tidak ada kondisi saling menunggu, jadi deadlock tidak terjadi. Kunci dilepas otomatis oleh kernel saat proses worker berakhir.

**U3, status dan exit status.** Worker mencatat PID proses job dan exit status-nya ke file job. Exit 0 dicatat BERHASIL, exit bukan 0 dicatat GAGAL, dan file dipindah ke `done/` atau `failed/`. Posisi folder menunjukkan tahap hidup job: menunggu, berjalan, lalu selesai.

**U4, timeout.** `run_with_timeout.sh` memakai `timeout` dengan batas 10 detik. `job_lama 3` selesai dalam 3 detik. `job_lama 20` dikirimi SIGTERM pada detik ke-10 dan berakhir dengan exit 124. Jam pada bukti (02:31:12 sampai 02:31:25) sesuai dengan 3 detik ditambah 10 detik. Jalur SIGKILL (exit 137) tidak teruji karena `job_lama` berhenti dengan SIGTERM.

**U5, akses dan Docker.** `tamu1` bukan anggota group `jobqueue`, sehingga tidak dapat membuka `/var/lib/job-queue` dan permintaannya ditolak dengan exit 5. Container membaca laporan melalui bind mount yang memetakan `/var/lib/job-queue/output` di host ke `/data` di container. Opsi `readonly` membuat penulisan ditolak, dan checksum laporan tidak berubah. Hasil ini hanya membuktikan pembatasan pada mount yang dipakai, bukan seluruh aspek keamanan container.

**Monitoring.** Pada beban 3 detik, CPU job sekitar 95–98%. Pada beban 8 detik, CPU naik dari 88% ke 99%. Memori (RSS) hampir sama, 1452 KB dan 1456 KB. Load average sebelum dan sesudah beban 3 detik adalah 0,67 dan 0,70, sedangkan beban 8 detik 0,70 dan 0,72. Perbedaan kedua beban terutama pada lamanya, bukan pada jumlah memori yang dipakai. Job berupa perulangan sederhana, sehingga pemakaian CPU tinggi dan memori kecil.
