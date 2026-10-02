# Spec: `janji` — Siklus Hidup Janji Temu

Modul ini menangani seluruh hidup satu janji temu: dibuat, diubah jadwalnya,
dibatalkan, sampai selesai. Di luar lingkup: data dokter (`dokter`), panel
petugas (`backoffice`), dan percakapan AI (`asisten-ai`).

## Tujuan

Pasien bisa memesan slot dokter tanpa menelepon, mendapat bukti pemesanan yang
bisa ditunjukkan saat datang, dan bisa mengubah atau membatalkan sendiri tanpa
menghubungi klinik. Petugas bisa mencatat apa yang benar-benar terjadi.

Ukuran keberhasilan:

- Dua orang tidak bisa memesan slot yang sama, dibuktikan dengan percobaan
  bersamaan yang ditolak **database**, bukan oleh validasi di kode.
- Pasien yang membatalkan janji tidak meninggalkan slot yang terkunci permanen.
- Setiap perubahan pada sebuah janji bisa ditelusuri siapa, kapan, dan apa yang
  berubah.

## Asumsi

Benarkan kalau salah:

1. Aplikasi web, bukan aplikasi mobile native.
2. Pasien **tidak login**. Identitasnya adalah kode booking.
3. Petugas klinik login (modul `backoffice`).
4. Satu slot = satu jam. Semua janji dianggap berdurasi sama.
5. Tidak ada notifikasi eksternal (WhatsApp/email/SMS) — di luar lingkup.
6. Semua waktu memakai zona WITA (UTC+8) dan disimpan sebagai waktu lokal klinik.
7. Mikrofon hanya diuji lewat `http://localhost` (browser memblokir di alamat non-HTTPS).

## Data

### `appointments`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `kode` | string(8) UNIQUE | acak, huruf besar, tanpa karakter mirip (0/O, 1/I/L) |
| `dokter_id` | FK → `dokters` | |
| `tanggal` | date | |
| `jam` | time | jam mulai, kelipatan slot |
| `nama_pasien` | string | |
| `no_hp` | string | dipakai untuk pemulihan kode dan verifikasi ringan |
| `keluhan` | text nullable | |
| `sumber` | enum | `web`, `chat`, `suara`, `petugas` |
| `status` | enum | lihat bagian Status |
| `dibatalkan_pada` | datetime nullable | **bagian dari kunci unik** — lihat di bawah |
| `dibuat_pada` / `diubah_pada` | timestamp | |

### Kunci anti double-booking

```
UNIQUE (dokter_id, tanggal, jam, dibatalkan_pada)
```

Alasannya penting dan perlu dipahami seluruh tim: di MySQL, `NULL` dianggap
berbeda satu sama lain di dalam indeks unik. Janji yang masih aktif punya
`dibatalkan_pada = NULL`, jadi dua janji aktif pada slot yang sama **pasti
ditolak**. Janji yang sudah dibatalkan punya nilai di kolom itu, jadi ia tidak
lagi mengunci slotnya — tanpanya, slot yang dibatalkan akan terkunci selamanya
dan rahasia ini baru ketahuan saat demo.

Efek sampingnya: saat mengubah jadwal, kita **cukup memperbarui `tanggal` dan
`jam` pada baris yang sama**. Kalau slot tujuan sudah terisi, MySQL menolak
perubahan itu secara atomik — tidak ada celah waktu antara "cek" dan "simpan".

### `riwayat_janji`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `appointment_id` | FK, on delete cascade | |
| `aksi` | enum | `dibuat`, `diubah`, `dibatalkan`, `dikonfirmasi`, `hadir`, `selesai`, `tidak_hadir` |
| `tanggal_lama`, `jam_lama` | nullable | terisi untuk `diubah` |
| `tanggal_baru`, `jam_baru` | nullable | terisi untuk `diubah` |
| `oleh` | enum | `pasien`, `petugas`, `asisten` |
| `catatan` | text nullable | alasan pembatalan/penundaan |
| `dibuat_pada` | timestamp | |

Janji **tidak pernah dihapus**. Dibatalkan berarti diubah statusnya. Ini yang
membuat riwayatnya bisa dipertanggungjawabkan.

## Status janji

```
dipesan ──┬─→ dikonfirmasi ──┬─→ hadir ──→ selesai
          │                  └─→ batal
          ├─→ batal
          └─→ (tanggal terlewat tanpa kehadiran) ──→ tidak_hadir
```

| Status | Arti | Siapa yang boleh mengubah |
|---|---|---|
| `dipesan` | Baru dibuat, belum dikonfirmasi klinik | sistem |
| `dikonfirmasi` | Petugas/dokter sudah mengonfirmasi | petugas |
| `hadir` | Pasien sudah datang dan tercatat | petugas |
| `selesai` | Sudah ditangani | petugas |
| `batal` | Dibatalkan pasien atau petugas | pasien (pakai kode), petugas |
| `tidak_hadir` | Tanggal lewat tanpa kehadiran | petugas |

Aturan:

- `batal` dan `selesai`/`tidak_hadir` bersifat **terminal** — tidak bisa dibalik.
- Petugas menandai `dikonfirmasi` sebelum pasien bisa ditandai `hadir`.
- Pasien hanya bisa membatalkan atau mengubah jadwal selama statusnya
  `dipesan` atau `dikonfirmasi`, **dan hanya sampai H-1**.
- **Batas H-1 artinya: selama hari ini masih lebih awal dari tanggal janjinya**
  (dihitung di zona WITA). Contoh: janji Selasa 6 Oktober → pasien masih bisa
  ubah/batal sampai Senin 5 Oktober 23:59. Mulai Selasa 00:00, tombolnya hilang
  dan pasien harus menghubungi klinik.
- Konsekuensi yang harus disadari: pasien yang memesan slot **hari itu** tidak
  bisa membatalkannya sendiri. Ini konsekuensi langsung dari pilihan H-1, bukan
  bug — kalau nanti dianggap terlalu ketat, ubah aturannya di dokumen ini dulu.
- Setelah dibatalkan, kode booking tidak bisa dipakai lagi untuk mengubah jadwal.
- Slot yang sudah terlewat tidak bisa dipesan atau dijadwalkan ulang.

## Alur pasien

### 1. Membuat janji

1. Halaman `/` menampilkan daftar dokter beserta hari dan jam praktiknya.
2. Pilih dokter → pilih tanggal (hanya hari praktik dokter itu yang bisa diklik)
   → pilih jam dari slot yang masih kosong.
3. Isi nama, nomor HP, keluhan (opsional).
4. Ringkasan konfirmasi: nama dokter, hari + tanggal **dalam bahasa Indonesia**,
   jam, nama pasien. Tombol utama "Ya, buat janji".
5. Berhasil → halaman sukses menampilkan **kode booking** dan QR,
   plus tombol salin dan simpan gambar.

Progres ditampilkan sebagai "Langkah 2 dari 4" setiap saat, supaya pasien tahu
masih berapa langkah lagi.

### 2. Melihat, mengubah jadwal, membatalkan

1. Pasien membuka `/janji/{kode}` — dari tautan yang disimpan, atau dari QR.
2. Halaman menampilkan detail janji dan hanya aksi yang **masih boleh dilakukan**
   pada status saat ini. Tombol yang tidak relevan tidak ditampilkan, bukan
   ditampilkan lalu dimatikan.
3. **Ubah jadwal** → pilih tanggal/jam baru → konfirmasi → kode **tetap sama**.
   Slot lama langsung bebas, slot baru langsung terkunci.
4. **Batalkan** → dialog konfirmasi ("Janji dengan drg. Sari, Selasa 6 Okt 10:00
   akan dibatalkan. Lanjutkan?") → alasan (opsional) → status jadi `batal`.

### 3. Lupa kode

Pemulihan memakai nama + nomor HP. Hasilnya **hanya menampilkan** tanggal, jam,
dan nama dokter — tombol ubah/batal tetap muncul, tapi baru berfungsi setelah
pasien memasukkan 4 digit terakhir nomor HP-nya.

Alasannya: nama + nomor HP gampang ditebak orang lain. Informasi jadwal boleh
terbuka, aksi yang mengubah data tidak.

### 4. Sampai di klinik

Pasien menunjukkan kode atau QR → petugas menandai `hadir` → setelah ditangani,
petugas menandai `selesai`. Kedua langkah ini hanya bisa dilakukan petugas yang
sudah login.

## Alur petugas

Sama seperti modul `backoffice`, tapi yang menyentuh modul ini:

- Cari janji berdasarkan kode, nama, atau nomor HP.
- Tandai `dikonfirmasi`, `hadir`, `selesai`, `tidak_hadir`.
- Mengubah jadwal pasien atas permintaan (misalnya dokter berhalangan) — misalnya
  memindahkan semua janji pada satu slot ke jam lain. Setiap perubahan tercatat
  di `riwayat_janji` dengan `oleh = petugas`.

## Peran agen AI

Agen AI (chat maupun suara) adalah **klien lain dari `BookingService`**, bukan
jalur istimewa:

- Sebelum menyimpan, agen wajib menyebut ulang dokter, hari, dan jam lalu meminta
  persetujuan eksplisit.
- Nama hari dihitung backend dan diberikan ke agen; agen tidak menghitung sendiri.
- Hasil booking dikembalikan sebagai kode, dan agen **mengeja kode itu** ke
  pasien. Untuk jalur suara, ini satu-satunya cara pasien menerima kode —
  karena itu kode teks wajib ada dan tidak boleh diganti QR saja.

## Kriteria selesai

- [ ] Booking pada slot yang sudah terisi ditolak oleh database, dibuktikan
      dengan dua permintaan berurutan ke slot yang sama.
- [ ] Mengubah jadwal mempertahankan kode booking yang sama.
- [ ] Mengubah jadwal ke slot terisi ditolak dengan pesan yang bisa dipahami
      pasien, bukan halaman error.
- [ ] Membatalkan janji membuat slot itu bisa dipesan lagi (dibuktikan dengan
      booking baru di slot yang sama).
- [ ] Setiap perubahan status punya satu baris di `riwayat_janji` dengan `oleh`
      yang benar.
- [ ] Janji yang dibatalkan tetap bisa dilihat petugas di panel admin, bukan hilang.
- [ ] Halaman janji tidak menampilkan tombol yang tidak berlaku untuk statusnya.
- [ ] Validasi form tampil di sebelah kolom yang salah, plus ringkasan kesalahan
      di atas form.
- [ ] Membatalkan janji selalu lewat dialog konfirmasi.
- [ ] Setiap aksi yang berhasil memberi umpan balik yang terlihat (bukan tombol
      yang diam setelah diklik).
- [ ] Pada hari-H, halaman janji **tidak menampilkan** tombol ubah/batal untuk
      pasien, dan menampilkan arahan menghubungi klinik.
- [ ] Dihitung di zona WITA: bulan/tahun yang berbeda tetap benar pada tanggal
      1 dan tanggal 31.
- [ ] Janji berstatus `dipesan` tidak bisa ditandai `hadir` sebelum petugas
      menandai `dikonfirmasi`.

## Risiko

| Risiko | Dampak | Pencegahan |
|---|---|---|
| Slot terkunci selamanya oleh janji batal | Tinggi | Kunci unik memakai `dibatalkan_pada` yang `NULL`-able |
| Dua permintaan bersamaan menempati slot sama | Tinggi | Andalkan `UNIQUE` di database, bukan pengecekan di aplikasi |
| Perbedaan aturan antara form web dan agen AI | Tinggi | Satu `BookingService` untuk semua jalur |
| Kode booking mudah ditebak | Sedang | Acak dari alfabet tanpa karakter mirip, panjang 8 |
| QR berisi kode dipotret orang lain | Sedang | QR hanya berisi URL; ubah/batal tetap minta 4 digit nomor HP |
| Kamera browser mati karena bukan `localhost` | Tinggi | Uji halaman scan lebih awal, jangan di hari presentasi |
| Riwayat hilang karena janji dihapus | Sedang | Tidak pernah `delete`; selalu ubah status |

## Keputusan yang sudah diambil

| Keputusan | Pilihan | Tanggal |
|---|---|---|
| Bukti booking | Kode teks **dan** QR sejak fase 1, termasuk halaman scan di panel petugas | 2 Okt 2026 |
| Batas ubah/batal oleh pasien | **H-1** — sampai pukul 23:59 hari sebelum tanggal janji (WITA) | 2 Okt 2026 |
| Status `dikonfirmasi` | **Ada** — petugas menandai konfirmasi sebelum pasien bisa ditandai hadir | 2 Okt 2026 |
| Kode booking setelah ubah jadwal | Tetap sama, tidak diterbitkan ulang | 2 Okt 2026 |
| Janji batal | Tidak pernah dihapus, hanya berubah status | 2 Okt 2026 |

## Pertanyaan terbuka

- Apakah petugas perlu kemampuan memindahkan banyak janji sekaligus (misalnya
  dokter berhalangan dan seluruh slot harus digeser)?
