# SincerelySea Business Domain

Dokumen ini menjelaskan arah domain bisnis commerce terbaru pada aplikasi `SincerelySea`.

## Model Bisnis

SincerelySea menggunakan model official brand store dengan dua application plane yang terpisah.

- Flutter mobile adalah aplikasi customer-facing untuk komunitas, discovery, shopping, review pelanggan, order pelanggan, dan account.
- Backend website terpisah adalah management plane untuk katalog, fulfilment, moderasi, finance, user, dan role.
- `SincerelySea Store` adalah satu-satunya toko resmi; tidak ada seller publik.
- Produk dijual oleh brand dan dikelola secara internal melalui backend website.
- Akun dengan claim `admin` atau `developer` tetap melihat surface pelanggan yang sama ketika membuka Flutter.
- Otorisasi management plane dibagi berdasarkan scope:
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

Field `userId` dipertahankan untuk kompatibilitas dan attribution pengelola lama, tetapi kepemilikan bisnis berada pada `ownerId`. Flutter hanya membaca produk untuk browse/buy dan tidak membuat atau mengubah katalog.

### Orders

Dokumen `orders/{orderId}` sekarang membawa konteks store resmi:

- `storeId: "sincerelysea"`
- `storeName: "SincerelySea Store"`
- `fulfillmentMode: "admin_managed"`

Dengan model ini, Flutter hanya membuat intent order melalui checkout, membaca order milik customer, melakukan Buy Again, dan membatalkan order `pending` jika Rules mengizinkan. Perubahan fulfilment dan status operasional dilakukan oleh management plane, bukan mobile.

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

1. Semua fitur commerce mobile harus mengacu ke `SincerelySea Store`, bukan seller publik.
2. Semua operasi katalog, fulfilment, moderasi, finance, dan role harus berada di backend website.
3. Scope admin adalah boundary otorisasi backend dan tidak boleh dipakai untuk menampilkan management UI di Flutter.
4. Fitur laporan atau finance baru harus terhubung ke `journal_entries` dan `sales_reports`.
5. Perubahan domain bisnis wajib dicatat di `docs/CHANGELOG.md`.
