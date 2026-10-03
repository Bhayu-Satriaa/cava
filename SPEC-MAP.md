# Peta Modul CAVA

Dokumen ini adalah indeks: modul apa saja yang ada, mana bergantung pada mana, dan
urutan pengerjaannya. Setiap modul punya spec sendiri di `docs/spec/SPEC-<id>.md`.

Aturan: **spec ditulis dan disetujui sebelum kode**. Kalau isi spec berubah, ubah
dokumennya dulu, baru kodenya.

| Id modul | Tanggung jawab | Bergantung pada |
|---|---|---|
| `dokter` | Data dokter, jadwal praktik, tanggal libur/cuti | — |
| `janji` | Siklus hidup janji temu: buat, ubah jadwal, batalkan, riwayat perubahan, kode booking | `dokter` |
| `pasien` | Biodata pasien (tanpa NIK), nomor rekam medis, penautan ke akun | `akun` |
| `akun` | Login (Google, cadangan email+password) dan peran: pasien, petugas, dokter. Satu akun boleh menaungi banyak biodata | — |
| `rekam-medis` | Catatan hasil pemeriksaan per kunjungan. **Tidak pernah ikut export CSV** | `janji`, `akun` |
| `backoffice` | Daftar janji, ubah status, export CSV, kelola jadwal dokter | `janji`, `akun` |
| `asisten-ai` | Chat teks dan suara yang memakai layanan `janji` | `dokter`, `janji` |
| `qr` | Pembuatan QR pada bukti janji dan halaman scan QR di panel petugas | `janji`, `backoffice` |

**Urutan build:** `dokter` → `janji` → `akun` → (`backoffice`, `rekam-medis`,
`asisten-ai`) → `qr`

`backoffice`, `rekam-medis`, dan `asisten-ai` boleh dikerjakan bersamaan setelah
`janji` selesai, karena ketiganya hanya *memakai* layanan janji dan tidak mengubah
aturannya. Yang tidak boleh dikerjakan bersamaan adalah `janji` dan apa pun yang
menyentuh tabel `slot_terpesan`.

`qr` ditaruh paling akhir bukan karena tidak penting, tapi karena ia bergantung
pada dua modul sekaligus (kode dari `janji`, halaman scan di `backoffice`).
Halaman scan memakai kamera, dan kamera di browser **hanya hidup di konteks
aman** — artinya harus dibuka lewat `http://localhost`, bukan IP LAN. Ini risiko
demo yang perlu diuji lebih awal, jangan di hari presentasi.

## Kenapa "buat", "ubah jadwal", dan "batal" jadi satu modul `janji`

Ketiganya bekerja pada data yang sama dan wajib tunduk pada aturan yang sama
(slot tidak boleh bentrok, jam harus ada di jadwal dokter, kode booking tidak
berubah). Kalau dipisah, aturannya akan terduplikasi dan cepat atau lambat salah
satu jalur jadi berbeda — persis penyebab bug double-booking.

## Aturan arsitektur yang mengikat semua modul

1. **`BookingService` adalah satu-satunya pintu masuk** untuk membuat, mengubah,
   dan membatalkan janji. Form web, chat, dan suara memanggil layanan yang sama.
   Tidak ada logika booking yang ditulis ulang di controller atau di view.
2. **Batas data ditegakkan di database.** Anti double-booking tidak boleh
   bergantung pada pengecekan `if` di aplikasi.
3. **Nama hari dihitung backend**, tidak pernah diserahkan ke model AI.
