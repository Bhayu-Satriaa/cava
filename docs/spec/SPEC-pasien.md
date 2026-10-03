# Spec: `pasien` — Biodata Pasien, Akun, dan Nomor Rekam Medis

Modul ini menangani siapa pasiennya, bagaimana biodata ditautkan ke akun, dan
nomor rekam medis yang menjadi identitas klinisnya.

## Tujuan

Satu baris pasien mewakili **satu orang**, dengan **satu nomor rekam medis seumur
hidup**. Dan satu akun bisa mengelola beberapa orang — mengikuti pola Kartu
Keluarga di Mobile JKN.

Ukuran keberhasilan:

- Satu akun bisa membuat janji untuk beberapa anggota keluarga, dan setiap orang
  punya nomor rekam medis sendiri.
- Orang yang sama tidak pernah punya dua nomor rekam medis, walau mendaftar dari
  jalur berbeda (web, suara, atau dibuatkan petugas).
- Riwayat kunjungan seorang pasien tetap utuh walau akunnya berganti.

## Data

### `pasiens`

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `nama` | string | |
| `tempat_lahir` | string nullable | dari TTL di notulen |
| `tanggal_lahir` | date nullable | **wajib untuk pendaftaran web dan penerbitan nomor RM**; boleh kosong hanya untuk pasien yang dibuat agen suara |
| `kelamin` | enum | `L` / `P` |
| `alamat` | text nullable | |
| `no_hp` | string | **tidak unik** — satu nomor bisa dipakai satu keluarga |
| `nomor_rekam_medis` | string unik, boleh kosong | terbit saat data wajib lengkap |
| `dibuat_pada` / `diubah_pada` | timestamp | |

**Tidak ada kolom NIK** — sudah diputuskan dihapus dari atribut pasien.

### `pasien_akun` (tabel penghubung)

| Kolom | Tipe | Catatan |
|---|---|---|
| `id` | bigint PK | |
| `user_id` | FK → `users` | akun login |
| `pasien_id` | FK → `pasiens` | biodata |
| UNIQUE | (`user_id`, `pasien_id`) | |

## Kenapa tabel penghubung, bukan `user_id` di dalam `pasiens`

Notulen meminta "1 akun untuk banyak biodata". Dibaca apa adanya, cukup dengan
`user_id` di dalam `pasiens`. Tapi dua keadaan nyata akan mematahkannya:

1. **Dua orang tua, satu anak.** Dengan `user_id` di tabel pasien, biodata anak
   hanya menempel pada satu akun. Begitu ibunya mendaftar, bapaknya tidak bisa
   melihat anaknya.
2. **Anak yang besar lalu punya akun sendiri.** Tanpa tabel penghubung, dia
   terdaftar sebagai pasien baru — nomor rekam medisnya ganda, riwayat
   kunjungannya terbelah.

Tabel penghubung menyelesaikan keduanya **tanpa mengubah isi permintaan notulen**:
satu akun tetap menaungi banyak biodata.

## Konsekuensi menghapus NIK, dan cara menutupnya

Menghapus NIK punya sisi baik yang nyata: **data pribadi yang disimpan jadi lebih
sedikit**, jadi risiko dan tanggung jawabnya lebih kecil. Itu alasan yang sah.

Tapi ada yang hilang, dan harus disebut apa adanya: **tidak ada lagi kunci yang
pasti untuk mengenali orang.** Yang tersisa hanya nama, tanggal lahir, dan nomor
HP — dan di satu keluarga, nomor HP-nya sama.

Cara menutupnya, dua lapis:

**Lapis 1 — cari sebelum buat.** Sistem **tidak pernah** langsung membuat baris
pasien baru. Sebelumnya dia mencari dulu dengan nama + tanggal lahir, dan
menampilkan kemungkinan yang cocok. Kalau ada kecocokan, **wajib memilih yang
sudah ada**, bukan membuat baris baru. Aturan ini yang mencegah pasien ganda.

**Lapis 2 — nomor rekam medis sebagai kunci kuat.** Untuk menautkan anggota
keluarga yang sudah pernah berobat, jalur yang dipakai adalah **nomor rekam
medis**-nya, karena itu satu-satunya nomor yang dijamin unik per orang. Nama +
tanggal lahir hanya dipakai untuk pasien yang belum pernah punya nomor RM.

**Yang tetap jadi risiko, dan diterima sadar:** dua orang dengan nama sama **dan**
tanggal lahir sama masih mungkin tertukar. Ini jarang, tapi bukan mustahil, dan
tidak ada lagi data yang bisa membedakan mereka secara otomatis. Verifikasi
akhirnya ada di petugas di meja pendaftaran. Kalau kalian menganggap risiko ini
terlalu besar untuk klinik nyata, NIK adalah jawabannya — tapi untuk proyek ini
kalian memilih jalan yang lebih hemat data, dan itu pilihan yang sah.

Karena nama + tanggal lahir jadi penanda utama, **`tanggal_lahir` wajib diisi
untuk pendaftaran web dan untuk penerbitan nomor RM.** Kalau kolom ini dibiarkan
kosong, pencocokan pasien praktis tidak bisa dilakukan.

## Aturan

1. **Nomor rekam medis terbit saat data wajib pasien lengkap — nama, tanggal
   lahir, kelamin, alamat, nomor HP — pada kunjungan pertamanya.** Lewat web ini
   terjadi saat janji pertama dibuat; lewat agen suara ini terjadi saat petugas
   melengkapi datanya di meja pendaftaran.
2. Nomor rekam medis **unik dan tidak pernah berubah**. Format `RM-000123`, tanpa
   tahun, karena berlaku seumur hidup dan tidak direset.
3. Penerbitan nomor RM **tidak boleh memakai `MAX(nomor) + 1` di kode** — dua
   pasien yang mendaftar bersamaan bisa mendapat nomor yang sama. Pakai urutan
   dari database dan bungkus dalam transaksi.
4. `no_hp` **tidak unik**, karena satu nomor lazim dipakai satu keluarga.
5. `no_hp` disimpan dalam **satu format kanonik** (hanya angka, diawali `62`).
   Tanpa itu, `0812...`, `+62 812-...`, dan `62812 ...` menjadi tiga pasien
   berbeda. Normalisasi di satu fungsi, dipakai semua jalur.
6. **Cari sebelum buat** (lihat bagian di atas) berlaku di semua jalur: web, agen
   suara, dan petugas di meja pendaftaran.
7. Pasien tanpa akun tetap sah. Baris pasien boleh ada tanpa penautan ke akun
   mana pun — itulah bentuk pasien yang datang lewat telepon.

## Cara memakai di halaman

Saat pasien yang sudah login menekan "Pesan", muncul satu langkah: **"Janji ini
untuk siapa?"** berisi daftar biodata yang tertaut ke akunnya, plus pilihan
"tambah anggota keluarga".

Menambah anggota keluarga punya dua pintu:

- Sudah pernah berobat → masukkan **nomor rekam medis**. Kalau cocok, biodata itu
  langsung tertaut. Ini jalur yang paling aman.
- Belum pernah → isi nama, tempat & tanggal lahir, kelamin, alamat, nomor HP.
  Sistem mencari dulu; kalau ada yang mirip, kecocokan itu ditampilkan dan
  pengguna diminta memilih, bukan langsung membuat baris baru.

Langkah "untuk siapa" tidak bisa dilewati kalau akunnya menaungi lebih dari satu
biodata. Kalau hanya satu, biodata itu yang dipakai tanpa bertanya.

## Kriteria selesai

- [ ] Satu akun dapat menautkan lebih dari satu biodata, dan setiap biodata punya
      nomor RM sendiri.
- [ ] Satu biodata dapat ditautkan ke lebih dari satu akun (dua orang tua, satu
      anak) tanpa terduplikasi.
- [ ] Menautkan lewat nomor rekam medis yang salah ditolak dengan pesan jelas.
- [ ] Pendaftaran dengan nama + tanggal lahir yang sudah ada **menampilkan
      kecocokan** dan menolak membuat baris baru sebelum pengguna memilih.
- [ ] Dua pendaftaran bersamaan menghasilkan dua nomor RM yang berbeda.
- [ ] Nomor HP dalam tiga format penulisan berbeda menghasilkan satu baris pasien.
- [ ] Pasien yang dibuat lewat agen suara tetap bisa dibuka petugas dan
      dilengkapi di meja pendaftaran.

## Risiko

| Risiko | Dampak | Pencegahan |
|---|---|---|
| Tanpa NIK, dua orang bisa tertukar | Tinggi | Cari sebelum buat + penautan lewat nomor RM + verifikasi petugas |
| Anak terdaftar dua kali | Tinggi | Tabel penghubung + pencarian sebelum membuat baris baru |
| Nomor RM ganda dari pendaftaran bersamaan | Tinggi | Urutan dari database dalam transaksi, bukan `MAX+1` |
| Nomor HP berbeda format dianggap pasien berbeda | Sedang | Satu fungsi normalisasi |
| Tanggal lahir kosong membuat pencocokan mustahil | Sedang | Wajib untuk pendaftaran web dan penerbitan nomor RM |

## Pertanyaan terbuka

- Apakah perlu entitas "Keluarga" dengan nomor Kartu Keluarga seperti Mobile JKN?
  Untuk sekarang belum, tapi tabel penghubung sudah menyediakan tempatnya.
- Bagaimana pasien membuktikan identitasnya saat mengambil nomor RM di meja, kalau
  NIK tidak disimpan? (Kartu pasien fisik, atau nomor RM yang dikirim lewat email.)
