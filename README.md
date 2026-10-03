# CAVA — Clinic Appointment Voice Assistant

Aplikasi janji temu klinik untuk tugas kelompok (PBL) Pemrograman Web Lanjut di
Politani. Pasien bisa membuat janji lewat **web**, **chat AI**, atau **suara**;
petugas mengelola janji di back office; dokter mengisi rekam medis hasil
pemeriksaan.

Dibangun dengan **Laravel 13** dan **MySQL**.

> **Status saat ini: tahap desain.** Yang ada di repo ini baru dokumen dan kerangka
> Laravel. Belum ada satu pun fitur yang dikoding. Itu disengaja — prototipe
> versi sebelumnya dibangun terburu-buru tanpa spec, dan hasilnya harus dirombak.

## Urutan membaca (penting)

Baca berurutan. Setiap dokumen mengandaikan dokumen sebelumnya sudah dibaca.

1. **`SPEC-MAP.md`** — peta modul, urutan build, dan aturan arsitektur yang
   mengikat semua modul. Mulai dari sini.
2. **`docs/spec/ERD.md`** — struktur data dan relasinya. Diagramnya digambar
   otomatis oleh GitHub saat file ini dibuka di browser.
3. **`docs/spec/ALUR-PENGGUNA.md`** — perjalanan pemakai dari mendaftar sampai
   selesai: alur pasien, pasien tanpa akun, petugas, dan dokter.
4. **Spec per modul** — baca sesuai bagian yang kamu pegang:
   - `docs/spec/SPEC-dokter.md` — dokter, jadwal praktik, tanggal libur
   - `docs/spec/SPEC-pasien.md` — biodata, akun, nomor rekam medis
   - `docs/spec/SPEC-janji.md` — buat janji, ubah jadwal, batalkan, riwayat
   - `docs/spec/SPEC-qr.md` — QR bukti janji dan halaman scan petugas

## Aturan kerja tim

1. **Spec dulu, baru kode.** Kalau ada yang berubah, ubah dokumennya dulu di
   commit terpisah, baru kodingnya. Ini yang membedakan versi ini dari yang lama.
2. **Satu fitur, satu commit.** Pesan commit berbahasa Indonesia, menjelaskan apa
   yang berubah — bukan "update" atau "fix".
3. **Jangan pernah commit `.env`** atau kredensial apa pun. Repo ini publik.
   Kunci API dan password diisi sendiri di `.env` masing-masing.
4. **Menambah paket/library harus disetujui dulu** oleh seluruh kelompok, bukan
   satu orang diam-diam.
5. **Klaim harus dibuktikan.** Setelah menambah fitur, tunjukkan hasil nyatanya:
   HTTP status, potongan output, atau baris dari database.

## Cara menjalankan

Butuh **Laragon** (sudah berisi PHP 8.3 dan MySQL 8) di Windows.

```bash
composer install
cp .env.example .env          # Windows: copy .env.example .env
php artisan key:generate
php artisan migrate           # butuh database `cava` sudah dibuat di MySQL
php artisan serve
```

Buka `http://localhost:8000`.

Database yang dipakai bernama **`cava`**. Buat dulu di MySQL kalau belum ada.

## Yang sudah diputuskan (jangan diusulkan ulang)

- Nama **CAVA**; MySQL, bukan SQLite; Laravel 13.
- **Rebuild dari nol** dengan history git bersih.
- Auth: **Google** sebagai jalur utama, **email+password** sebagai cadangan.
  Pasien punya akun; petugas dan dokter memakai email+password.
- **Satu akun boleh menaungi banyak biodata** (pola Kartu Keluarga), lewat tabel
  penghubung `pasien_akun`.
- Jenis kelamin dan tanggal lahir tidak diturunkan dari NIK — **NIK tidak
  disimpan**.
- **QR berisi kode acak 8 karakter**, bukan id.
- Nomor rekam medis berformat **`RM-000123`**, terbit saat data wajib pasien
  lengkap pada kunjungan pertama, dan tidak pernah berubah.
- Pasien boleh membatalkan atau mengubah jadwal **sampai H-1**.
- Petugas wajib menandai `dikonfirmasi` sebelum janji bisa ditandai `hadir`.
- Rekam medis disimpan di tabel sendiri dan **tidak pernah ikut export CSV**.

## Pertanyaan terbuka — butuh keputusan kelompok

1. **Durasi satu slot janji** berapa menit? (nilainya sudah jadi kolom di jadwal,
   jadi tinggal diisi; default 30)
2. **Pembagian tugas per modul** — belum ada. Urutan build ada di `SPEC-MAP.md`.
3. **Pengingat otomatis sebelum jadwal?** Kalau ya, lewat email — satu-satunya
   jalur yang tersedia. Kalau tidak, fitur ini dihapus dari rencana.
4. **Pengiriman email untuk registrasi dan lupa password:** pakai `MAIL_MAILER=log`
   (berfungsi tanpa internet, cocok untuk demo), Mailtrap, atau Gmail SMTP?
5. **Petugas perlu memindahkan banyak janji sekaligus** kalau dokter berhalangan?
6. **Jadwal dokter diubah lewat UI panel atau cukup lewat seeder** untuk keperluan
   demo?
7. **Desain kartu pasien** — ukuran, isi, dan siapa yang mencetak.
8. **Format QR dicetak di kertas bukti janji?** Kalau ya, ukuran cetaknya berapa.
9. **Paket `laravel/socialite`** untuk login Google belum diinstall — masih
   menunggu persetujuan setelah alur disetujui.

## Struktur folder dokumen

```
SPEC-MAP.md              peta modul + urutan build
docs/spec/ERD.md         struktur data (diagram Mermaid, tampil di GitHub)
docs/spec/ALUR-PENGGUNA.md   alur semua aktor
docs/spec/SPEC-dokter.md     modul dokter
docs/spec/SPEC-pasien.md     modul pasien
docs/spec/SPEC-janji.md      modul janji temu
docs/spec/SPEC-qr.md         modul QR
```
