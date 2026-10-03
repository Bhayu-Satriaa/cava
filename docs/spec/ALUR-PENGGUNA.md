# Alur Pengguna CAVA

Dokumen ini menyatukan alur dari semua modul: siapa masuk lewat pintu mana, apa
yang dia lihat, dan apa yang terjadi di database pada setiap langkah. Spec per
modul (`SPEC-dokter.md`, `SPEC-janji.md`, `SPEC-qr.md`, dan seterusnya) mengatur
isi modulnya; dokumen ini mengatur perjalanan pemakainya.

## Aktor

| Aktor | Cara masuk | Yang bisa dilakukan |
|---|---|---|
| **Pasien** | Login Google (normal) atau akun cadangan email+password (darurat demo) | Jelajah jadwal, buat janji, lihat janji, ubah jadwal, batalkan, lihat nomor RM sendiri |
| **Pasien tanpa akun** | Tidak login | Buat janji lewat agen suara/chat atau sebagai tamu, lalu urus janjinya dengan kode booking |
| **Petugas** | Email + password | Kelola janji, tandai status, lengkapi data pasien, ubah jadwal, export CSV |
| **Dokter** | Email + password (peran `dokter`) | Lihat jadwal pasiennya hari ini, isi rekam medis |

Aturan penting: **akun bukan syarat memegang janji.** Setiap janji selalu punya
kode booking. Akun hanya membuat pengelolaannya lebih nyaman.

## Alur A — Pasien baru lewat web

1. Buka `/` → daftar dokter dan jam praktik. **Tidak perlu login untuk melihat.**
2. Pilih dokter → tanggal (hanya hari praktik) → jam (slot kosong saja).
3. Tekan "Pesan" → diminta masuk dengan Google.
4. Kalau akun ini belum terhubung ke biodata mana pun → form pelengkapan:
   **nama, tempat & tanggal lahir, kelamin, alamat, nomor HP**.
5. Kalau akunnya sudah menaungi **lebih dari satu biodata** → muncul langkah
   **"Janji ini untuk siapa?"**. Kalau hanya satu, biodata itu langsung dipakai.
6. Ringkasan konfirmasi → "Ya, buat janji".
7. Janji dibuat lewat `BookingService`. Karena data wajibnya lengkap dan ini
   kunjungan pertama, **nomor rekam medis diterbitkan**.
8. Halaman sukses menampilkan: **nomor RM**, **kode booking**, dan **QR**.
9. Mengubah atau membatalkan janji bisa dari halaman janji, sampai **H-1**.

## Alur B — Pasien lama lewat web

1. Login Google → sistem mengenali pasien lewat email akunnya.
2. Halaman "Janji saya": janji mendatang, riwayat kunjungan, dan **nomor RM**.
3. Buat janji baru → data diri tidak ditanyakan lagi.
4. Nomor RM **tidak pernah berubah** — satu pasien, satu nomor, seumur hidup.

## Alur C — Pasien tanpa akun

Dua keadaan yang harus tetap bisa dilayani, dan keduanya memakai kunci yang sama:
**kode booking + 4 digit terakhir nomor HP.**

1. **Menelepon lewat agen suara.** Agen menanyakan nama, nomor HP, dokter, hari,
   dan jam. Agen menyebut ulang ringkasannya, meminta persetujuan, lalu membuat
   janji dan **mengeja kode booking**-nya. Agen tidak bisa menerima QR.
2. **Datang tanpa membuka akun.** Pasien menunjukkan kode atau QR-nya; petugas
   mencari janji dari kode itu.

Aturan untuk agen suara: **cari pasien berdasarkan nomor HP yang sudah
dinormalisasi sebelum membuat baris pasien baru.** Kalau tidak, orang yang
menelepon tiga kali akan menjadi tiga pasien berbeda, dan riwayat kunjungannya
terpecah.

## Alur D — Pasien baru yang datang dari jalur suara

Ini kasus yang paling mudah terlewat, jadi ditulis eksplisit:

1. Agen suara membuat janji dengan **nama dan nomor HP saja**. Tanggal lahir dan
   data lainnya belum ada, jadi **nomor RM belum diterbitkan** dan biodatanya
   belum lengkap.
2. Pasien datang ke klinik.
3. Petugas menandai `hadir`, lalu melengkapi data: **tempat & tanggal lahir,
   kelamin, alamat**.
4. Begitu data wajibnya lengkap, **nomor RM diterbitkan** — dan di situ juga akun
   pasien bisa ditautkan kalau pasien mau memakai web nanti.

Aturan yang berlaku untuk semua jalur: **nomor RM diterbitkan saat data wajib
pasien lengkap (nama, tanggal lahir, kelamin, alamat, nomor HP) pada kunjungan
pertamanya.** Lewat web ini terjadi langsung; lewat suara ini terjadi di meja
pendaftaran.

Karena tidak ada NIK, petugas **wajib mencari dulu** dengan nama + tanggal lahir
sebelum melengkapi data — kalau tidak, pasien yang sudah pernah berobat akan
mendapat nomor RM kedua.

## Alur E — Petugas

1. Login email + password.
2. Halaman janji hari ini → tandai `dikonfirmasi` untuk janji yang dikonfirmasi
   lewat telepon.
3. Pasien datang → scan QR atau ketik kode → tampil ringkasan → tandai `hadir`.
4. Kalau data pasien belum lengkap (datang dari jalur suara) → lengkapi tempat &
   tanggal lahir, kelamin, alamat sekaligus, cari dulu sebelum menyimpan
5. Setelah dokter selesai → `selesai`. Kalau pasien tidak datang → `tidak_hadir`.
6. Atas permintaan pasien: ubah jadwal atau batalkan, dengan catatan alasan.
7. Export CSV — **tidak pernah memuat kolom rekam medis**.

Petugas **tidak melihat isi rekam medis**. Yang dia butuhkan hanya jadwal,
identitas, dan status.

## Alur F — Dokter

1. Login email + password dengan peran `dokter`.
2. Daftar pasiennya hari ini: janji berstatus `dikonfirmasi` dan `hadir`.
3. Buka satu kunjungan → isi rekam medis: keluhan, diagnosis, tindakan, catatan.
4. Menekan simpan membuat janji berstatus `selesai`.
5. Dokter hanya melihat janji **miliknya sendiri**, bukan seluruh klinik.

Dokter tidak perlu bisa membuat atau membatalkan janji; itu pekerjaan petugas.

## Peta akses halaman

| Halaman | Boleh diakses |
|---|---|
| `/` daftar dokter & jadwal | siapa saja |
| `/janji/{kode}` | siapa saja yang punya kodenya (+ 4 digit nomor HP untuk mengubah) |
| `/janji-saya` | pasien yang login |
| booking | pasien yang login, atau agen suara/chat |
| `/admin/*` | petugas |
| `/dokter/*` | dokter (hanya janji miliknya) |

## Yang berubah dari rancangan sebelumnya

- Asumsi lama "pasien tidak login, identitasnya kode booking" **sudah tidak
  berlaku**. Sekarang: pasien boleh punya akun, tapi janji tetap berdiri sendiri
  dengan kode booking.
- Nomor RM tidak lagi selalu terbit saat booking: terbit saat data wajib pasien
  lengkap.
- Panel petugas tidak lagi sepenuhnya terbuka bagi dokter; dokter punya halaman
  sendiri dengan lingkup lebih sempit.

## Pertanyaan terbuka

- Apakah pasien boleh membuat janji untuk orang lain (mis. orang tua mendaftarkan
  anaknya dengan akunnya sendiri)? Ini menentukan apakah satu akun boleh menaungi
  beberapa pasien.
- Apakah perlu pengingat otomatis sebelum jadwal? Kalau ya, lewat apa — email
  (satu-satunya jalur yang sudah ada) atau tidak sama sekali?
