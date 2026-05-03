# SincerelySea Change Log

Semua perubahan proyek wajib dicatat di file ini mulai sekarang.

## 2026-04-13

### Changed
- Konfigurasi Android di `android/app/build.gradle.kts` disesuaikan agar `applicationId` mengikuti package Firebase client yang saat ini ada di `android/app/google-services.json` (`com.sincerelysea.app`), sambil mempertahankan `namespace` existing untuk meminimalkan perubahan struktur kode Android.
- Konfigurasi Google Sign-In iOS disinkronkan dengan project Firebase aktif di `ios/Runner/GoogleService-Info.plist` dan `ios/Runner/Info.plist`, termasuk `CLIENT_ID`, `REVERSED_CLIENT_ID`, dan URL scheme callback yang benar untuk bundle `com.sincerelysea.app`.
- `AppCheckHeaderService` sekarang menonaktifkan injeksi header App Check secara aman pada platform/versi OS Apple yang tidak mendukung provider attestation, sehingga warning `firebase_app_check/code-unsupported` tidak lagi berkembang menjadi gangguan UI.

### Fixed
- `AppCheckCachedNetworkImage` tidak lagi mengirim `placeholder` dan `progressIndicatorBuilder` secara bersamaan ke `CachedNetworkImage`, sehingga assertion `octo_image` saat register/login dengan akun Google tidak lagi terpancing oleh render gambar placeholder.
- Konfigurasi Firebase proyek dipindahkan agar mengikuti project baru `SincerelySea` (`gen-lang-client-0026437130`) pada Android dan iOS.
- Target iOS `Runner` sekarang memakai bundle identifier `com.sincerelysea.app` agar selaras dengan konfigurasi Firebase project baru.
- File Firebase iOS di `ios/GoogleService-Info.plist`, `ios/Runner/GoogleService-Info.plist`, dan `ios/AppFrameworkInfo.plist` diperbarui agar menunjuk ke project `gen-lang-client-0026437130`.
- `AuthService` sekarang memakai Android Google Sign-In `serverClientId` dari project Firebase baru agar login Google di Android tidak lagi memakai client ID project lama.
- Alur `Create Post` diperbaiki agar post biasa tidak lagi mewajibkan gambar. Sekarang user bisa publish selama ada caption atau gambar, dan upload Storage hanya dijalankan jika file gambar memang dipilih.
- Logging analytics setelah `posts.add(...)` di `PostService` dibuat best-effort agar kegagalan telemetry tidak lagi membuat publish post terlihat gagal walaupun dokumen Firestore sudah berhasil ditulis.
- Lookup profil `users/{uid}` sebelum publish post di `PostService` dibuat best-effort dengan timeout pendek. Jika Firestore sementara `unavailable`, post tetap akan ditulis memakai fallback nama dari Firebase Auth.
- Publish post sekarang otomatis mencoba sekali lagi jika Firestore mengembalikan `unavailable`, dengan re-enable network Firestore sebelum retry untuk membantu koneksi ke project Firebase baru yang masih belum stabil.
- Konfigurasi Firebase CLI di `.firebaserc` dipindahkan ke project baru `gen-lang-client-0026437130` agar deploy rules berikutnya tidak lagi mengarah ke project lama.
- Widget image berbasis App Check sekarang otomatis retry tanpa header jika request image Firebase Storage gagal. Ini membantu menampilkan image legacy dari bucket/project lama pada halaman selain post.
- Kartu unavailable product di `saved_products_screen.dart` juga dipindahkan ke `AppCheckCachedNetworkImage` agar perilaku loading image konsisten dengan halaman lain.

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
- Struktur data baru untuk domain bisnis resmi `SincerelySea Store` pada product dan order.
- Model dan service pelaporan baru: `SalesReport`, `JournalEntry`, dan `SalesReportingService`.
- Halaman admin baru untuk membaca sales reports dan journal entries.
- Dokumen domain bisnis baru di `docs/BUSINESS_DOMAIN.md`.
- Scope admin baru untuk membedakan product manager, order manager, community manager, dan access manager.
- Halaman `Community Reports` untuk admin komunitas.
- Order management yang lebih mudah dipakai dengan pencarian dan kartu `needs attention`.
- Scope `finance` baru untuk admin yang mengelola seluruh laporan transaksi aplikasi.
- Dokumen baru `docs/SCOPE_GUIDE.md` dan `docs/PROJECT_ROADMAP.md` untuk memetakan scope admin dan roadmap proyek.

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
- Konsep seller publik sekarang digeser menjadi `SincerelySea Store` yang dikelola admin.
- `OrderService` sekarang menulis snapshot `sales_reports` dan `journal_entries` saat order dibuat, dibayar, diselesaikan, atau dibatalkan.
- Wording UI commerce sekarang mengarah ke official store, store orders, dan admin-managed catalog.
- `README.md` sekarang mendokumentasikan domain bisnis baru, arsitektur reporting, dan struktur proyek yang lebih sesuai dengan kondisi codebase saat ini.
- Menu settings admin sekarang dibagi per tanggung jawab: product admin, order admin, community admin, dan access control.
- `AdminService`, `ProductService`, `OrderService`, dan rules Firestore sekarang menghormati `adminScopes`.
- Akses `sales_reports` dan `journal_entries` sekarang diarahkan ke admin `finance`, terpisah dari admin order operasional.
- `README.md` sekarang diposisikan sebagai entry point utama untuk memahami konsep bisnis, scope admin, dan roadmap proyek.

### Notes
- Setiap perubahan berikutnya harus menambah entri baru di file ini.
- Gunakan kategori minimal: `Added`, `Changed`, `Removed`, `Fixed`, jika relevan.
