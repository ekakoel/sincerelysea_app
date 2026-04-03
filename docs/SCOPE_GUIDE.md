# SincerelySea Scope Guide

Dokumen ini menjelaskan pembagian tanggung jawab admin pada aplikasi `SincerelySea`.

## Tujuan

Scope digunakan agar setiap admin hanya melihat area kerja yang relevan.

Hal ini penting untuk:

- menjaga UI tetap sederhana
- mengurangi kesalahan operasional
- memudahkan AI/developer memahami siapa mengelola apa

## Scope Admin

### `products`

Tanggung jawab:

- membuat product post
- mengelola katalog `SincerelySea Store`
- mengatur stock, preorder, availability, dan metadata produk

Area utama:

- `products/{productId}`
- `Manage Store Products`
- product creation flow

### `orders`

Tanggung jawab:

- memproses order masuk
- mengubah status order
- memantau order yang perlu tindakan

Area utama:

- `orders/{orderId}`
- `Store Orders`
- operational order management

### `finance`

Tanggung jawab:

- mengelola semua laporan transaksi
- membaca sales report harian
- memeriksa journal entries
- memastikan transaksi tercatat sesuai kebutuhan laporan

Area utama:

- `sales_reports/{reportId}`
- `journal_entries/{entryId}`
- `Transaction Reports`

### `community`

Tanggung jawab:

- meninjau report dari komunitas
- menangani laporan post dan user
- memperbarui status penanganan report

Area utama:

- `reports/{reportId}`
- `Community Reports`

### `roles`

Tanggung jawab:

- mengatur admin access
- menentukan siapa product manager, order manager, finance admin, atau community admin

Area utama:

- `users/{uid}.role`
- `users/{uid}.adminScopes`
- `Admin Access`

## Relasi Antar Scope

- `products` fokus ke katalog
- `orders` fokus ke fulfilment operasional
- `finance` fokus ke laporan transaksi
- `community` fokus ke moderasi
- `roles` fokus ke kontrol akses

Scope boleh digabung pada satu admin jika diperlukan, tetapi secara default sebaiknya tetap dipisah.

## Aturan Implementasi Berikutnya

1. Fitur baru harus ditempatkan ke scope yang jelas.
2. Jika fitur tidak punya owner scope yang jelas, dokumentasikan dulu sebelum implementasi.
3. Setiap perubahan scope wajib memperbarui:
   - `README.md`
   - `docs/BUSINESS_DOMAIN.md`
   - `docs/CHANGELOG.md`
   - dokumen ini
