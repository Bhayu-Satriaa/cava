# Spec: `qr` — Bukti Janji dan Halaman Scan

Modul ini menyediakan satu QR per janji (untuk ditunjukkan pasien saat datang)
dan satu halaman scan di panel petugas (untuk membacanya). Di luar lingkup:
pembuatan janji itu sendiri (`janji`) dan kerangka panel petugas (`backoffice`).

## Tujuan

Pasien tidak perlu mengeja kode 8 karakter saat check-in, dan petugas tidak
perlu mengetiknya. Satu QR berfungsi ganda: bukti saat datang **dan** jalan
pintas untuk membuka kembali halaman janji, tanpa aplikasi tambahan.

Ukuran keberhasilan:

- Kamera bawaan HP apa pun bisa membuka halaman janji pasien dari QR itu, tanpa
  memasang aplikasi.
- Petugas bisa check-in pasien dari QR dalam waktu kurang dari 10 detik, dihitung
  dari membuka halaman scan sampai status berubah.
- QR tidak bisa dipakai untuk mengubah atau membatalkan janji tanpa data penguat.

## Aturan desain

1. **QR berisi URL, bukan teks kode.**
   Isinya `{APP_URL}/janji/{kode}`. Teks polos seperti `BKVXAY5F` hanya bisa
   dibaca aplikasi khusus, jadi ia kehilangan separuh manfaatnya.
2. **Tidak ada data pribadi di dalam QR.** Tidak ada nama, nomor HP, keluhan, atau
   nomor rekam medis. QR = URL + kode, tidak lebih.
3. **QR sama dengan kata sandi.** Siapa pun yang memotretnya memegang kunci janji
   itu. Karena itu halaman scan **tidak langsung menampilkan aksi**: petugas
   melihat ringkasan dulu, lalu menekan tombol untuk mengubah status.
4. **Kode dicetak teks di sebelah QR**, dalam huruf yang mudah dibaca. Kalau
   kamera gagal, petugas masih bisa mengetiknya. Ini juga satu-satunya jalur bagi
   pasien yang memesan lewat suara.
5. **QR dibuat saat halaman sukses ditampilkan, bukan disimpan sebagai file.**
   Tidak ada gambar yang perlu dititipkan ke storage, jadi tidak ada berkas basi
   kalau janji diubah. Kalau kode tidak pernah berubah, QR-nya juga tidak perlu
   dibuat ulang.

## Alur pasien

1. Setelah booking berhasil, halaman sukses menampilkan: kode teks (huruf besar,
   mudah dibaca), QR, tombol **Salin kode**, dan tombol **Simpan gambar QR**.
2. Tombol simpan gambar memakai elemen `<canvas>` QR yang sudah dirender; hasilnya
   diunduh sebagai PNG. Pasien tidak perlu screenshot.

## Alur petugas

1. `/admin/scan` — halaman dengan area kamera dan tombol alternatif
   "Masukkan kode manual".
2. Arahkan kamera ke QR → sistem membaca URL → mengambil kode di ujungnya.
   **Yang dipakai adalah kode-nya, bukan URL mentahnya** — supaya QR dari
   lingkungan lain (misalnya hasil pengembangan) tidak membawa petugas ke alamat
   yang salah.
3. Tampilkan ringkasan: nama pasien, dokter, hari + tanggal, jam, status saat ini.
4. Tombol aksi yang tersedia mengikuti aturan status di `janji`:
   tandai `hadir`, tandai `selesai`, atau tandai `tidak_hadir`.
5. Kalau kode tidak ditemukan, atau janjinya sudah `batal`/`selesai`, tampilkan
   pesan yang jelas — bukan halaman error dan bukan layar kosong.

## Catatan teknis yang menentukan

- **Kamera hanya hidup di konteks aman.** `http://localhost` dianggap aman;
  IP LAN (`http://192.168.x.x`) tidak. Kalau halaman scan dibuka dari HP lewat IP
  LAN, kamera akan diblokir browser. Uji ini di awal, jangan di hari presentasi.
- Kalau kamera tidak tersedia atau ditolak izinnya, **halaman harus tetap berguna**:
  tampilkan pesan singkat dan langsung arahkan ke input kode manual. Petugas tidak
  boleh terjebak di layar yang tidak bisa diapa-apakan.
- Pembacaan QR di sisi klien tidak perlu pustaka berat; satu pustaka pembaca QR
  kecil sudah cukup. Pilih yang tidak butuh proses build, karena proyek ini tidak
  memakai Node untuk aset.

## Kriteria selesai

- [ ] QR pada halaman sukses terbaca oleh kamera bawaan HP dan membuka halaman
      janji yang benar.
- [ ] Kode teks di sebelah QR terlihat dan bisa disalin dengan satu klik.
- [ ] Tombol "Simpan gambar QR" menghasilkan file PNG yang benar-benar bisa discan.
- [ ] Halaman scan berhasil mengubah status janji dari QR, dan perubahan itu
      tercatat di `riwayat_janji` dengan `oleh = petugas`.
- [ ] Halaman scan menolak kode yang tidak ada dengan pesan yang bisa dipahami.
- [ ] Halaman scan menampilkan janji yang sudah `batal` sebagai batal, bukan
      seolah-olah masih aktif.
- [ ] Kalau izin kamera ditolak, halaman menampilkan pesan dan input kode manual
      tetap berfungsi.
- [ ] Diuji lewat `http://localhost`, dan hasilnya dicatat (berhasil/gagal) supaya
      risiko ini tidak lagi jadi tebakan.

## Risiko

| Risiko | Dampak | Pencegahan |
|---|---|---|
| Halaman scan dibuka lewat IP LAN, kamera diblokir | Tinggi | Uji di `localhost` lebih awal; sediakan input kode manual |
| QR dipotret orang lain lalu janji diubah | Sedang | Halaman scan hanya menampilkan ringkasan; ubah/batal tetap butuh kode + verifikasi |
| Pustaka QR butuh proses build Node | Sedang | Pilih pustaka yang bisa dipakai langsung sebagai file statis |
| QR berisi URL lingkungan pengembangan | Sedang | Petugas memakai kode di ujung URL, bukan URL-nya |

## Pertanyaan terbuka

- Apakah QR perlu ikut tercetak di struk atau kertas bukti janji? Kalau ya, ukuran
  cetaknya perlu ditentukan.
