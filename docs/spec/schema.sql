-- ============================================================
--  CAVA — Clinic Appointment Voice Assistant
--  Skema MySQL 8.0 untuk tabel fitur.
--  Database: cava   |   Charset: utf8mb4 / utf8mb4_unicode_ci
-- ============================================================
--  STATUS: SUDAH DIUJI, BUKAN DRAF
--  Diuji 2 Okt 2026 pada MySQL 8.0.30 di database sekali pakai
--  (`cava_schema_test`, dihapus lagi setelah pengujian). Hasil:
--    - 10 tabel terbentuk tanpa error
--    - 13 foreign key terpasang
--    - 10 kunci unik (di luar primary key) terpasang
--    - duplikat slot ditolak database: ERROR 1062
--    - dua akun dengan `google_id` NULL diterima, `google_id` sama ditolak
--    - setelah baris slot dihapus, slot yang sama bisa dipesan lagi
--    - menghapus janji ikut menghapus baris slot dan riwayatnya (cascade)
-- ============================================================
--  Cara pakai:
--   1. Database kosong  -> jalankan Bagian 1, lalu Bagian 2.
--   2. `users` sudah ada (kamu sudah `php artisan migrate`)
--      -> LEWATI Bagian 1, jalankan Bagian 2, lalu Bagian 3.
--
--  Urutan CREATE TABLE penting: tabel yang menunjuk tabel lain
--  harus dibuat setelah tabel yang ditunjuknya.
-- ============================================================

SET NAMES utf8mb4;


-- ============================================================
--  BAGIAN 1 — TABEL `users`
--  Lewati bagian ini kalau tabel `users` sudah ada.
-- ============================================================

CREATE TABLE `users` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`              VARCHAR(120)    NOT NULL,
  `email`             VARCHAR(190)    NOT NULL,
  `email_verified_at` TIMESTAMP       NULL DEFAULT NULL,
  `password`          VARCHAR(255)    NULL COMMENT 'boleh kosong untuk akun yang hanya masuk lewat Google',
  `peran`             ENUM('pasien','petugas','dokter') NOT NULL DEFAULT 'pasien',
  `google_id`         VARCHAR(190)    NULL COMMENT 'id akun Google; NULL untuk akun password',
  `remember_token`    VARCHAR(100)    NULL,
  `created_at`        TIMESTAMP       NULL DEFAULT NULL,
  `updated_at`        TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`),
  UNIQUE KEY `users_google_id_unique` (`google_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Catatan: kolom unik yang boleh NULL seperti `google_id` justru yang kita mau.
-- MySQL mengizinkan banyak NULL di dalam indeks unik, jadi ribuan akun password
-- bisa hidup berdampingan, sementara satu google_id tidak bisa dipakai dua kali.


-- ============================================================
--  BAGIAN 2 — TABEL FITUR
-- ============================================================

-- ---------- dokter ----------

CREATE TABLE `dokters` (
  `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`      BIGINT UNSIGNED NULL COMMENT 'akun login dokter; boleh kosong',
  `nama`         VARCHAR(120)    NOT NULL COMMENT 'lengkap dengan gelar',
  `spesialisasi` VARCHAR(100)    NOT NULL,
  `aktif`        TINYINT(1)      NOT NULL DEFAULT 1,
  `no_sip`       VARCHAR(50)     NULL,
  `no_hp`        VARCHAR(20)     NULL,
  `created_at`   TIMESTAMP       NULL DEFAULT NULL,
  `updated_at`   TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dokters_user_id_unique` (`user_id`),
  CONSTRAINT `dokters_user_id_foreign` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `jadwal_dokters` (
  `id`                 BIGINT UNSIGNED   NOT NULL AUTO_INCREMENT,
  `dokter_id`          BIGINT UNSIGNED   NOT NULL,
  `hari`               TINYINT UNSIGNED  NOT NULL COMMENT 'ISO: 1=Senin .. 7=Minggu',
  `jam_mulai`          TIME              NOT NULL,
  `jam_selesai`        TIME              NOT NULL,
  `durasi_slot_menit`  SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  `aktif`              TINYINT(1)        NOT NULL DEFAULT 1,
  `created_at`         TIMESTAMP         NULL DEFAULT NULL,
  `updated_at`         TIMESTAMP         NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `jadwal_dokters_dokter_hari_index` (`dokter_id`, `hari`),
  CONSTRAINT `jadwal_dokters_dokter_id_foreign` FOREIGN KEY (`dokter_id`)
    REFERENCES `dokters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `dokter_libur` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `dokter_id`  BIGINT UNSIGNED NOT NULL,
  `tanggal`    DATE            NOT NULL,
  `alasan`     VARCHAR(100)    NULL COMMENT 'cuti, seminar, dan sejenisnya',
  `created_at` TIMESTAMP       NULL DEFAULT NULL,
  `updated_at` TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `dokter_libur_dokter_tanggal_unique` (`dokter_id`, `tanggal`),
  CONSTRAINT `dokter_libur_dokter_id_foreign` FOREIGN KEY (`dokter_id`)
    REFERENCES `dokters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------- pasien ----------

CREATE TABLE `pasiens` (
  `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `nama`              VARCHAR(120)    NOT NULL,
  `tempat_lahir`      VARCHAR(80)     NULL,
  `tanggal_lahir`     DATE            NULL COMMENT 'wajib sebelum nomor RM diterbitkan',
  `kelamin`           ENUM('L','P')   NULL,
  `alamat`            TEXT            NULL,
  `no_hp`             VARCHAR(20)     NULL COMMENT 'tidak unik: satu nomor bisa dipakai satu keluarga',
  `nomor_rekam_medis` VARCHAR(20)     NULL COMMENT 'format RM-000123, seumur hidup',
  `created_at`        TIMESTAMP       NULL DEFAULT NULL,
  `updated_at`        TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pasiens_nomor_rekam_medis_unique` (`nomor_rekam_medis`),
  KEY `pasiens_pencarian_index` (`nama`, `tanggal_lahir`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Indeks `pasiens_pencarian_index` bukan hiasan: karena NIK tidak disimpan,
-- pencocokan pasien memakai nama + tanggal lahir. Tanpa indeks ini, aturan
-- "cari sebelum buat" akan memperlambat setiap pendaftaran.


-- ---------- janji temu ----------

CREATE TABLE `appointments` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `kode`            CHAR(8)         NOT NULL COMMENT 'acak, isi QR dan bukti booking',
  `dokter_id`       BIGINT UNSIGNED NOT NULL,
  `pasien_id`       BIGINT UNSIGNED NOT NULL,
  `tanggal`         DATE            NOT NULL,
  `jam`             TIME            NOT NULL COMMENT 'jam mulai, kelipatan durasi slot',
  `keluhan`         TEXT            NULL,
  `sumber`          ENUM('web','chat','suara','petugas') NOT NULL DEFAULT 'web',
  `status`          ENUM('dipesan','dikonfirmasi','hadir','selesai','batal','tidak_hadir')
                    NOT NULL DEFAULT 'dipesan',
  `dibatalkan_pada` DATETIME        NULL,
  `created_at`      TIMESTAMP       NULL DEFAULT NULL,
  `updated_at`      TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `appointments_kode_unique` (`kode`),
  KEY `appointments_dokter_tanggal_index` (`dokter_id`, `tanggal`),
  KEY `appointments_pasien_index` (`pasien_id`),
  KEY `appointments_status_index` (`status`),
  KEY `appointments_tanggal_index` (`tanggal`),
  CONSTRAINT `appointments_dokter_id_foreign` FOREIGN KEY (`dokter_id`)
    REFERENCES `dokters` (`id`) ON DELETE RESTRICT,
  CONSTRAINT `appointments_pasien_id_foreign` FOREIGN KEY (`pasien_id`)
    REFERENCES `pasiens` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Penjaga anti double-booking. Baris di tabel ini HANYA ada selama janjinya
-- masih aktif; dibatalkan berarti barisnya dihapus, sehingga slot bisa dipesan
-- lagi sementara riwayat janjinya tetap utuh di tabel `appointments`.
CREATE TABLE `slot_terpesan` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `appointment_id` BIGINT UNSIGNED NOT NULL,
  `dokter_id`      BIGINT UNSIGNED NOT NULL,
  `tanggal`        DATE            NOT NULL,
  `jam`            TIME            NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `slot_terpesan_slot_unique` (`dokter_id`, `tanggal`, `jam`),
  UNIQUE KEY `slot_terpesan_appointment_unique` (`appointment_id`),
  CONSTRAINT `slot_terpesan_appointment_id_foreign` FOREIGN KEY (`appointment_id`)
    REFERENCES `appointments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `slot_terpesan_dokter_id_foreign` FOREIGN KEY (`dokter_id`)
    REFERENCES `dokters` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `riwayat_janji` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `appointment_id` BIGINT UNSIGNED NOT NULL,
  `user_id`        BIGINT UNSIGNED NULL COMMENT 'petugas yang mengubah; NULL bila oleh sistem',
  `aksi`           ENUM('dibuat','diubah','dibatalkan','dikonfirmasi','hadir','selesai','tidak_hadir') NOT NULL,
  `tanggal_lama`   DATE            NULL,
  `jam_lama`       TIME            NULL,
  `tanggal_baru`   DATE            NULL,
  `jam_baru`       TIME            NULL,
  `oleh`           ENUM('pasien','petugas','asisten') NOT NULL,
  `catatan`        TEXT            NULL,
  `dibuat_pada`    TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `riwayat_janji_appointment_index` (`appointment_id`),
  CONSTRAINT `riwayat_janji_appointment_id_foreign` FOREIGN KEY (`appointment_id`)
    REFERENCES `appointments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `riwayat_janji_user_id_foreign` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Isi pemeriksaan. Sengaja BUKAN kolom di `appointments`, supaya tidak pernah
-- ikut ter-export ke CSV panel petugas.
CREATE TABLE `rekam_medis` (
  `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `appointment_id` BIGINT UNSIGNED NOT NULL,
  `dokter_id`      BIGINT UNSIGNED NOT NULL,
  `diagnosis`      TEXT            NOT NULL,
  `tindakan`       TEXT            NULL,
  `catatan`        TEXT            NULL,
  `created_at`     TIMESTAMP       NULL DEFAULT NULL,
  `updated_at`     TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `rekam_medis_appointment_unique` (`appointment_id`),
  CONSTRAINT `rekam_medis_appointment_id_foreign` FOREIGN KEY (`appointment_id`)
    REFERENCES `appointments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `rekam_medis_dokter_id_foreign` FOREIGN KEY (`dokter_id`)
    REFERENCES `dokters` (`id`) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Satu akun boleh menaungi banyak biodata, dan satu biodata boleh dikelola
-- lebih dari satu akun (dua orang tua, satu anak).
CREATE TABLE `pasien_akun` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    BIGINT UNSIGNED NOT NULL,
  `pasien_id`  BIGINT UNSIGNED NOT NULL,
  `created_at` TIMESTAMP       NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `pasien_akun_user_pasien_unique` (`user_id`, `pasien_id`),
  CONSTRAINT `pasien_akun_user_id_foreign` FOREIGN KEY (`user_id`)
    REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `pasien_akun_pasien_id_foreign` FOREIGN KEY (`pasien_id`)
    REFERENCES `pasiens` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ============================================================
--  BAGIAN 3 — HANYA kalau tabel `users` sudah ada dari Laravel
--  Hapus tanda komentar (--) pada blok di bawah, lalu jalankan.
-- ============================================================
-- ALTER TABLE `users`
--   ADD COLUMN `peran` ENUM('pasien','petugas','dokter') NOT NULL DEFAULT 'pasien' AFTER `password`,
--   ADD COLUMN `google_id` VARCHAR(190) NULL AFTER `peran`,
--   MODIFY COLUMN `password` VARCHAR(255) NULL,
--   ADD UNIQUE KEY `users_google_id_unique` (`google_id`);
