# Nexa

Nexa adalah personal operating system untuk keuangan, target, dan proyek. Flutter, Riverpod,
go_router, Drift/SQLite. Local-first: tidak ada backend, tidak ada akun, tidak
ada sinkronisasi cloud.

## Menjalankan

```bash
flutter pub get
dart run build_runner build      # hanya setelah mengubah lib/data/database
flutter run                     # device Android tersambung
flutter test
flutter analyze
flutter build apk --debug
```

Target perangkat: Samsung SM-A035F, Android 13, 360 x 800 dp.

## Arsitektur

```
UI (widget)
  ↓
Riverpod provider  ── filter, state yang bisa diubah, aksi tulis
  ↓
Repository        ── validasi, pemetaan baris ke model, aturan bisnis
  ↓
Drift database     ── SQLite, satu file di direktori dokumen aplikasi
```

```
lib/
├── main.dart
├── app/            app · router (go_router) · theme
├── core/
│   ├── constants/  design token
│   ├── utils/      format rupiah/tanggal, id, penggabung stream
│   └── widgets/    design system + kit form
├── data/
│   ├── database/   tabel, AppDatabase, seed, provider data
│   └── repositories/  satu repository per aggregate
├── domain/
│   ├── models/     entitas immutable + enum
│   ├── services/   kalkulasi murni (tanpa database, tanpa jam)
│   └── errors.dart jenis error yang aman ditampilkan ke pengguna
└── features/
    ├── home/       agregasi: ringkasan finance, fokus, target, proyek
    ├── focus/      Today's Focus, CRUD
    ├── finance/    akun, transaksi, transfer, alokasi, arus kas
    ├── goals/      target, milestone, progres, pace
    └── projects/   proyek, task, progres dari task
```

Aturan yang dipegang:

- Widget tidak pernah menyentuh database. Widget memanggil `*Actions` dari
  provider, repository yang menulis.
- Business calculation ada di `domain/services` atau di model immutable, bukan
  di widget dan bukan di SQL.
- `Accounts.balance` adalah cache. Satu-satunya sumber kebenaran adalah ledger
  `transactions`; setiap perubahan ledger memanggil
  `AppDatabase.refreshAccountBalances()` di transaksi database yang sama.
- Saldo akun tidak pernah ditulis langsung dari form, termasuk saat form Edit
  akun dipakai untuk membetulkan saldo. Selisih antara saldo yang diminta dan
  saldo yang dihitung ledger dicatat sebagai transaksi
  `Penyesuaian saldo <nama>` di `AccountRepository.update`, jadi setiap rupiah
  pada saldo tetap punya transaksi yang bisa dibuka. Akun kewajiban memakai
  tanda yang terbalik: menambah utang berarti menambah pengeluaran.
- Tanggal dan jam masuk lewat `clockProvider`, bukan `DateTime.now()` di dalam
  widget, supaya perhitungan periode dan pace bisa diuji.

## Schema

| Tabel | Isi |
|---|---|
| `settings` | key/value: nama operator, mata uang default |
| `accounts` | nama, tipe, saldo (cache), mata uang, catatan, `is_liability`, arsip |
| `transactions` | nominal (positif), tipe, kategori, judul, akun, akun tujuan, tanggal, catatan |
| `goals` | judul, deskripsi, kategori, target, nilai sekarang, tenggat, prioritas, status |
| `goal_milestones` | ambang nilai per goal, urutan, selesai pada |
| `projects` | nama, deskripsi, status, kategori, prioritas, tenggat, langkah berikutnya |
| `project_tags` | stack dan tag, satu baris per tag |
| `project_tasks` | judul, deskripsi, prioritas, tenggat, urutan, selesai pada |
| `focus_items` | judul, prioritas, tanggal, catatan, selesai pada |

Semua tabel punya primary key `id` (string stabil, bukan urutan baris) dan
timestamp `created_at`/`updated_at`. Relasi: transaksi ke akun memakai
`ON DELETE RESTRICT` supaya akun dengan riwayat tidak bisa hilang diam-diam,
sementara goal, task, dan tag memakai `ON DELETE CASCADE`.

Versioning: `kSchemaVersion` di `lib/data/database/tables.dart`, langkah
upgrade di `AppDatabase.migration`. Seed hanya jalan di `onCreate`, jadi data
demo tidak pernah muncul lagi setelah penggunahenghapus atau mengubah
sesuatu.

## Design system

`DESIGN.md` adalah sumber kebenaran. Token ada di
`lib/core/constants/design_tokens.dart` (warna, spacing, radius) dan
`lib/app/theme.dart` (tipografi + `ThemeData`).

Deviation yang disengaja, tercatat di kode dan di sini:

- `Text Muted` DESIGN.md `#5F6670` hanya 2,9:1 di atas permukaan navy, di bawah
  WCAG AA untuk micro-label dan timestamp yang memang diperuntukkan padanya.
  Dinaikkan ke `#7E8794` (4,7:1) dengan peran dan posisi ramp yang sama.
- Ikon navigasi memakai glyph stroke Material, bukan SVG 1,75px, supaya tidak
  menambah dependensi icon set.

## Ikon launcher

Logo sumber ada di `logo_nexa.png`. Aset Android dihasilkan dari file itu
oleh `tool/generate_launcher_icons.py`, bukan digambar ulang:

```bash
python3 tool/generate_launcher_icons.py
```

Script itu lifted monogram dari file sumber memakai antialiasing file itu
sebagai mask, lalu menaruhnya di atas warna canvas dan accent aplikasi
(`#001135` dan `#E3F2FD`). Geometri logo tidak diubah, dan tidak ada gradien,
glow, bayangan, atau teks di dalam ikon.

Hasilnya:

- `res/mipmap-<density>/ic_launcher.png` untuk API < 26
- `res/mipmap-<density>/ic_launcher_foreground.png` untuk adaptive icon, dengan
  latar `@color/ic_launcher_background` di `res/values/colors.xml`
- `res/mipmap-anydpi-v26/ic_launcher.xml` dan `ic_launcher_round.xml`

Kanvas adaptive 108dp dengan safe zone 72dp, dan monogram selalu di dalam zona
itu, jadi tidak ada mask launcher yang bisa memotongnya.

## Test

```
test/
├── support/test_harness.dart     database in-memory + clock + helper widget test
├── data/                         repository, filter, persistensi, cross-module
├── widget_test.dart              navigasi, filter, form, detail, empty state
└── layout_test.dart              semua layar di 360x800 dan skala teks 1,3x
```

`flutter test` menjalankan file dua-dua lewat `dart_test.yaml`, dan menutup
database sebelum test selesai: drift menyimpan cache stream dengan timer, dan
widget test gagal kalau masih ada timer yang tertunda.
