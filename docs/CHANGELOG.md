# SincerelySea Change Log

Semua perubahan proyek wajib dicatat di file ini mulai sekarang.

## 2026-04-03

### Added
- Social commerce foundation:
  - `products`, `orders`, dan `users/{userId}/cart` integration di Firestore.
  - Model baru: `Product`, `CartItem`, dan `Order`.
  - Service baru: `ProductService`, `CartService`, dan `OrderService`.
  - Screen baru: katalog produk, detail produk, cart, checkout, seller storefront, order history, seller orders, dan order detail.
  - Widget baru: `ProductCard` dan `OrderCard`.
- Shop tab pada bottom navigation.
- Search, sort, category filter, dan cart badge untuk katalog produk.
- Buyer order history dan seller order management.
- Seller status filter chips dan order detail navigation.
- Folder `docs/` untuk dokumentasi perubahan teknis.
- Buyer action baru pada order detail: `Buy Again` dan `Cancel Order`.
- Seller summary card untuk total order, pending, completed, dan revenue.
- Integrasi wishlist produk ke flow commerce yang memanfaatkan sistem wishlist existing.
- Filter `Wishlist Only` di Shop.
- Integrasi wishlist produk ke seller storefront, shared product post, dan feed product card.
- Halaman `Saved Products` khusus untuk akses cepat wishlist produk.
- Notifikasi `back in stock` server-side untuk product wishlist saat stok berubah dari habis menjadi tersedia.
- Support produk `ready stock` dan `preorder` dengan field inventory khusus.
- UX commerce diperhalus dengan filter tipe produk, checkout summary yang lebih jelas, dan saved products summary.
- Halaman `Manage Products` untuk seller agar bisa mengubah availability, stock, dan preorder settings.
- Pembuatan produk sekarang dibatasi hanya untuk user dengan role `admin`.
- Panel admin untuk mengelola role user langsung dari aplikasi.
- Badge `ADMIN` pada profile owner dan preview profile user.
- Admin dashboard ringan untuk memantau users, products, orders, dan role audit log.
- Audit log role changes di koleksi `admin_audit_logs`.
- Filter audit log admin untuk membedakan promosi dan demosi role.
- Product analytics di admin dashboard untuk memantau tipe produk, paused items, low stock, dan top products.

### Changed
- `PostService` dan flow create post sekarang mendukung `type` (`post` / `product`) dan `productId`.
- `HomeScreen` sekarang bisa membuat product post dengan metadata produk lengkap.
- `ProductDetailScreen` sekarang mendukung storefront seller, add to cart, buy now, dan akses ke detail order item.
- `ProfileSettingsMenuScreen` sekarang memiliki menu commerce untuk buyer dan seller.
- `main.dart` sekarang mendaftarkan provider commerce services.
- `firestore.rules` dan `storage.rules` diperluas untuk commerce flow.
- `firestore.rules` sekarang mengizinkan buyer membatalkan order `pending` dan mengakui status `cancelled`.
- `OrderService` sekarang mengembalikan stok produk saat order dibatalkan.
- `WishlistService` sekarang mendukung item bertipe `product` dan toggle wishlist langsung dari UI produk.
- Tab wishlist profile sekarang dapat menampilkan dan membuka produk yang disimpan.
- `ProductCard` sekarang menampilkan aksi wishlist yang konsisten di seluruh surface commerce.
- `Shop` dan `Settings > Commerce` sekarang menyediakan entry point langsung ke `Saved Products`.
- Notification center sekarang mendukung notifikasi produk dan membuka detail produk langsung dari inbox notifikasi.
- Create product flow, product UI, order snapshot, dan seller order status sekarang membedakan `ready stock` vs `preorder`.
- Halaman `Shop`, `Checkout`, dan `Saved Products` sekarang lebih ramah user untuk membedakan item preorder vs ready stock.
- Seller sekarang bisa mengelola produk langsung dari `Settings > Commerce` tanpa membuat ulang post produk.
- UI, service, dan Firestore rules sekarang memblokir non-admin dari pembuatan dan publishing product post.
- Menu seller commerce sekarang hanya tampil untuk admin, dan screen manajemen produk juga melakukan guard role.
- `users/{uid}` baru sekarang menyimpan role default `user`, dan settings admin menampilkan entry point role management.
- `firestore.rules` sekarang mengizinkan admin mengganti role user secara terbatas tanpa membuka edit field profile lain.
- Perubahan role admin sekarang otomatis menulis audit log, dan seller admin kini diberi label jelas di product detail serta storefront.
- Admin dashboard sekarang lebih operasional dengan insight commerce yang langsung dihitung dari `products` dan `orders`.

### Notes
- Setiap perubahan berikutnya harus menambah entri baru di file ini.
- Gunakan kategori minimal: `Added`, `Changed`, `Removed`, `Fixed`, jika relevan.
