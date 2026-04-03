# SincerelySea Business Domain

Dokumen ini menjelaskan arah domain bisnis commerce terbaru pada aplikasi `SincerelySea`.

## Model Bisnis

SincerelySea menggunakan model `brand-owned marketplace`.

- `SincerelySea Store` adalah toko resmi di dalam aplikasi.
- Produk dijual oleh brand dan dikelola secara internal.
- User biasa berperan sebagai pembeli dan anggota komunitas.
- User dengan role `admin` dapat dibagi lagi berdasarkan tanggung jawab:
  - `products`
  - `orders`
  - `finance`
  - `community`
  - `roles`

## Dampak Domain ke Struktur Data

### Products

Dokumen `products/{productId}` sekarang mengikuti konsep toko resmi:

- `ownerType: "business"`
- `ownerId: "sincerelysea"`
- `storeName: "SincerelySea Store"`
- `managedByAdmins: true`

Field `userId` tetap dipertahankan untuk menandai admin yang terakhir membuat produk, tetapi kepemilikan bisnis berada pada `ownerId`.

### Orders

Dokumen `orders/{orderId}` sekarang membawa konteks store resmi:

- `storeId: "sincerelysea"`
- `storeName: "SincerelySea Store"`
- `fulfillmentMode: "admin_managed"`

Dengan model ini, pengelolaan order tidak lagi bergantung pada konsep seller publik.

### Reporting

Sistem laporan penjualan mengikuti struktur jurnal:

- `sales_reports/{reportId}`
- `journal_entries/{entryId}`

`sales_reports` menyimpan snapshot agregasi harian.
`journal_entries` menyimpan jejak akuntansi dari event commerce seperti:

- `order_created`
- `order_paid`
- `order_cancelled`

## Prinsip Pengembangan Berikutnya

1. Semua fitur commerce baru harus mengacu ke `SincerelySea Store`, bukan seller publik.
2. Semua operasi katalog dan fulfilment harus diasumsikan `admin-managed`.
3. Akses admin harus dibatasi sesuai area kerja agar product manager, order manager, dan community manager tidak saling tumpang tindih.
4. Fitur laporan atau finance baru harus terhubung ke `journal_entries` dan `sales_reports`.
5. Perubahan domain bisnis wajib dicatat di `docs/CHANGELOG.md`.
