# Peta Modul CAVA

Dokumen ini adalah indeks: modul apa saja yang ada, mana bergantung pada mana, dan
urutan pengerjaannya. Setiap modul punya spec sendiri di `docs/spec/SPEC-<id>.md`.

Aturan: **spec ditulis dan disetujui sebelum kode**. Kalau isi spec berubah, ubah
dokumennya dulu, baru kodenya.

| Id modul | Tanggung jawab | Bergantung pada |
|---|---|---|
| `dokter` | Data dokter dan jadwal praktiknya (poli, hari, jam mulai–selesai) | — |
| `janji` | Siklus hidup janji temu: buat, ubah jadwal, batalkan, riwayat perubahan, kode booking | `dokter` |
| `qr` | Pembuatan QR pada bukti janji dan halaman scan QR di panel petugas | `janji`, `backoffice` |
| `backoffice` | Login petugas, daftar janji, ubah status, export CSV | `janji` |
| `asisten-ai` | Chat teks dan suara yang memakai layanan `janji` | `dokter`, `janji` |

**Urutan build:** `dokter` → `janji` → (`backoffice`, `asisten-ai`) → `qr`

`backoffice` dan `asisten-ai` boleh dikerjakan bersamaan setelah `janji` selesai,
karena keduanya hanya *memakai* layanan janji dan tidak mengubah aturannya.

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
