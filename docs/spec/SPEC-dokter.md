# Spec: `dokter` — Data Dokter dan Jadwal Praktik

Modul ini menyediakan siapa saja dokternya, kapan mereka praktik, dan slot jam apa
saja yang bisa dipesan. Ini fondasi: modul `janji` tidak bisa dibangun tanpa daftar
slot yang jelas.

## Tujuan

Pasien bisa melihat dokter mana yang praktik pada hari tertentu dan jam berapa
saja, dan sistem bisa membuktikan bahwa sebuah janji benar-benar jatuh di dalam
jam praktik dokternya.

Ukuran keberhasilan:

- Halaman daftar dokter menampilkan data dari database, bukan array di dalam kode.
- Setiap slot yang ditawarkan ke pasien bisa dilacak ke baris `jadwal_dokters`
  yang menjadi asalnya.
- Tidak ada pasien yang bisa memesan jam di luar jam praktik dokternya.

## Data

### `dokters`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `nama` | string | lengkap dengan gelar, mis. "drg. Sari Wulandari" |
| `spesialisasi` | string | mis. "Dokter Gigi", "Dokter Umum", "Dokter Anak" |
| `aktif` | boolean | dokter berhenti praktik **tidak dihapus** — lihat di bawah |
| `no_sip` | string nullable | nomor izin praktik; pakai data contoh, bukan data asli |
| `no_hp` | string nullable | kontak internal klinik |
| `dibuat_pada` / `diubah_pada` | timestamp | |

Jam praktik **tidak** ada di tabel ini.

### `jadwal_dokters`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `dokter_id` | FK → `dokters` | |
| `hari` | tinyint | ISO: 1 = Senin … 7 = Minggu |
| `jam_mulai`, `jam_selesai` | time | mis. 08:00 – 11:00 |
| `durasi_slot_menit` | smallint | nilai awal **30** |
| `aktif` | boolean | untuk menghentikan jadwal lama tanpa menghapusnya |
| `dibuat_pada` / `diubah_pada` | timestamp | |

### `dokter_libur`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `dokter_id` | FK → `dokters` | |
| `tanggal` | date | tanggal dokter tidak praktik |
| `alasan` | string nullable | mis. "cuti", "seminar" |
| UNIQUE | (`dokter_id`, `tanggal`) | |

Kenapa perlu: pola jadwal di `jadwal_dokters` bersifat **mingguan dan berulang**.
Dokter yang cuti pada satu tanggal tertentu tidak bisa dinyatakan dengan pola
mingguan — kalau tidak ada tabel ini, pasien akan tetap melihat slot kosong pada
hari dokter tidak praktik, memesan, lalu tidak dilayani siapa pun.

## Aturan

1. `jam_mulai` harus lebih awal dari `jam_selesai`. Ditegakkan saat validasi input
   dan saat seeding.
2. **Satu dokter tidak boleh punya dua jadwal yang tumpang tindih pada hari yang
   sama** (mis. 08:00–11:00 dan 10:00–13:00). Ini **tidak bisa** ditegakkan dengan
   `UNIQUE` biasa karena bentuknya rentang, bukan nilai tunggal. Karena itu:
   dicek di aplikasi saat petugas menyimpan jadwal, dan disebutkan apa adanya
   sebagai keterbatasan yang disadari — bukan diam-diam diabaikan.
3. Slot diturunkan dari jadwal: mulai dari `jam_mulai`, bertambah
   `durasi_slot_menit` sampai **sebelum** `jam_selesai`. Contoh: 08:00–11:00 dengan
   durasi 30 menit menghasilkan 08:00, 08:30, 09:00, 09:30, 10:00, 10:30.
   **11:00 bukan slot**, karena tidak ada sisa waktu yang cukup.
4. `hari` disimpan sebagai angka ISO, dan **nama hari berbahasa Indonesia
   dihasilkan backend** saat ditampilkan. Nama hari tidak pernah diserahkan ke
   model AI — satu model pernah menyebut hari yang salah untuk tanggal yang benar.
5. Dokter yang tidak lagi praktik diubah menjadi `aktif = false`, **tidak pernah
   dihapus**. Menghapusnya akan memutus rujukan dari janji-janji lama, dan
   riwayat kunjungan pasien ikut rusak.
6. Dokter yang tidak aktif tidak muncul di halaman pasien, tapi **tetap muncul di
   panel petugas** saat membuka janji lama yang memakai dokter tersebut.

## Kenapa durasi slot jadi data, bukan angka di dalam kode

Kalau durasi ditulis sebagai konstanta di kode, mengubahnya berarti mengubah kode
yang sedang jalan dan berisiko pada data yang sudah ada. Sebagai kolom, keputusan
"durasi berapa menit" bisa berubah kapan saja hanya dengan mengubah data — dan
keputusan itu memang belum diambil.

Yang penting sudah diputuskan **sebelum seeder jadwal dibuat**, karena slot yang
ditawarkan ke pasien mengikuti angka ini.

## Kriteria selesai

- [ ] Halaman daftar dokter dan jadwalnya balas HTTP 200 dan datanya berasal dari
      database (dibuktikan dengan mengubah satu baris seeder lalu memuat ulang).
- [ ] Seeder mengisi minimal 3 dokter dengan pola jadwal yang berbeda-beda
      (ada yang praktik 2 hari, ada yang 5 hari).
- [ ] Jumlah slot yang dihasilkan untuk satu jadwal sama dengan perhitungan manual
      (08:00–11:00 durasi 30 menit → 6 slot).
- [ ] Tanggal yang ada di `dokter_libur` tidak menghasilkan slot apa pun.
- [ ] Dokter `aktif = false` tidak muncul di halaman pasien, tapi tetap muncul di
      panel petugas.
- [ ] Mencoba membuat janji di luar jam praktik ditolak dengan pesan yang jelas.

## Risiko

| Risiko | Dampak | Pencegahan |
|---|---|---|
| Jadwal tumpang tindih tidak terdeteksi | Sedang | Validasi aplikasi + sebutkan sebagai keterbatasan |
| Slot dihitung dua tempat berbeda (view dan service) | Tinggi | Satu fungsi penghasil slot, dipakai semua pemanggil |
| Dokter dihapus, janji lama kehilangan rujukan | Tinggi | Tolak hapus; gunakan `aktif` |
| Nama hari dihitung model AI | Tinggi | Selalu hitung di backend |

## Pertanyaan terbuka

- Apakah petugas bisa mengubah jadwal dokter dari panel, atau jadwal hanya diubah
  lewat seeder/impor untuk keperluan demo?
- Apakah jadwal perlu berlaku hanya pada rentang tanggal tertentu (mis. dokter
  mulai praktik bulan depan), atau pola mingguan berulang sudah cukup?
