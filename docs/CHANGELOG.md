# SincerelySea Change Log

## 2026-09-22

### QA-01 - End-to-End Customer & Firebase Quality Assurance
- Fixed account export failures caused by Firestore Timestamp and GeoPoint values and added safe customer-facing failure recovery.
- Expanded export coverage to active customer profile, community, saved, shopping, support, review, order, report, and notification data while preserving the public/private profile split.
- Completed trusted account-deletion cleanup for cart, collections, support tickets/messages/attachments, product reviews, replies, and cross-user follow requests; retained orders/reports where technically or legally required.
- Declared the collection-group indexes required by lifecycle cleanup, review export, and back-in-stock wishlist notification queries; no index was deployed.
- Added focused lifecycle regression tests; Flutter analysis, 45 Flutter tests, and a fail-closed Auth/Firestore/Storage hard-delete integration test pass.
- Confirmed 51 Functions, Firestore Rules, and Storage Rules emulator tests plus Functions lint pass without production deployment.
- Built the Android debug APK successfully; iOS static configuration is present, while build/signing and real-device permission/App Check validation remain blocked by the Windows platform and production setup.
- Preserved the frozen SEC-01 through SEC-07 boundaries, customer-only navigation, trusted checkout authority, and absence of mobile management UI.

## 2026-09-21

### MOB-03A - Product Reviews Completion
- Added deterministic product review documents keyed by customer UID, enforcing one review per authenticated customer and product.
- Added Product Detail loading, empty, safe error/retry, author/date/rating/text presentation, plus Write, Edit, and Delete Review flows.
- Resolved review author identity exclusively from users_public with a neutral SincerelySea Member fallback and no private identity copied into review records.
- Added owner-only Firestore Rules with product existence, exact field allowlist, immutable ownership/product/creation identity, 1-5 rating, and bounded text validation.
- Denied cross-user and claimed admin moderation mutations; no approval, rejection, feature, official, or hidden-by-admin customer fields are accepted.
- Kept reviews text-only with no Storage path, verified-purchase badge, client product-rating aggregate, new notification infrastructure, or mobile moderation UI.
- Added focused Flutter source-boundary coverage and Firestore emulator regression cases; no production deployment or migration was performed.

### MOB-03 - Customer Feature Completeness
- Connected Forgot Password to the existing reset flow and replaced technical/raw authentication failures with customer-safe messages.
- Hardened cart and checkout against deleted, unavailable, stale-price, and over-stock products while preserving trusted callable order authority.
- Made Buy Again resolve current catalog products before adding them, normalized order status labels, and continued successful checkout into the created order detail when readable.
- Removed non-functional notification category toggles and retained only truthful system-permission controls plus the in-app notification center.
- Added resilient retry/unavailable states for profile settings, hidden content, shared-post details, linked products, and notification actions without exposing backend exceptions.
- Removed the unused direct account-data deletion helper and retained the trusted hardDeleteAccount lifecycle boundary.
- Kept product reviews intentionally disabled because no review data/service/UI domain exists; no misleading review action is exposed.
- Added ten focused MOB-03 source-boundary tests and a customer feature matrix. No production deployment, migration, Firebase service change, management UI, or security-boundary weakening was introduced.

### MOB-02 - Customer Navigation & UX Finalization
- Finalized the customer navigation as Home, Search, Explore, Shop, and Profile, preserving tab state and returning root-level back navigation from secondary tabs to Home.
- Kept Create Post prominent on Home as a labeled community-only action without adding a permanent navigation tab or restoring product-post creation.
- Renamed customer destinations consistently to Search, Explore, and SincerelySea Store and retained existing secure queries, checkout authority, and official-store boundaries.
- Reorganized Settings into Account, Privacy & Security, Notifications, Shopping, Support, Legal, and Application; added Cart access and removed the duplicate Export Data route.
- Added customer-oriented Support categories for products, technical issues, and account deletion while preserving the existing private ticket flow and legal routes.
- Added a reusable neutral customer state view and applied loading/empty/error/retry handling across feed, search, explore, store, profile, notifications, orders, saved products, and support without exposing raw backend exceptions.
- Removed email-derived own-profile fallback identity and retained public profile reads through `users_public`; no Rules, Storage, callable authority, App Check policy, financial write, or order write was weakened.
- Added seven focused MOB-02 source-boundary tests. No production deployment, migration, Firebase service change, or management UI was introduced.

### Security Checkpoint - Frozen Baseline & Production Rollout Plan
- Froze SEC-01 through SEC-07 as the security baseline for later mobile work: Flutter remains customer-only and privileged management remains in trusted backend/operator infrastructure.
- Added `docs/PRODUCTION_ROLLOUT.md` as the single authority for canonical phase status, production prerequisites, ordered deployment, rollback boundaries, acceptance gates, smoke coverage, STOP conditions, and MOB-02 constraints.
- Classified pending-order reconciliation, public/private profile backfill, legacy post-visibility normalization, and Storage/media remediation as requiring scripts and operator review; no migration script was invented without production inventory and mapping approval.
- Preserved the existing SEC-01 operator scripts according to their narrow capabilities and kept SEC-01 at PARTIAL 7/8 pending fresh-token production smoke.
- Recorded the current pre-deploy gate as NOT READY because migrations/inventories, release artifacts, provider registration, real-device App Check validation, and the final SEC-01 session are outstanding.
- Performed no production inventory/export, migration, deployment, data mutation, service-enforcement change, or console operation.

### SEC-07 - App Check Production Enforcement Readiness
- Made Flutter App Check initialization Firebase-first and build-mode controlled: debug providers remain local-development tolerant, while profile/release providers fail closed.
- Selected Play Integrity for Android production and App Attest with DeviceCheck fallback for iOS production; added the Runner App Attest entitlement and removed Android release fallback to debug signing.
- Applied Firebase Functions SDK-native App Check enforcement to `hardDeleteAccount`, `createCustomerOrder`, and `cancelCustomerOrder` without removing authentication, authorization, validation, or idempotency checks.
- Kept `setUserAdminAccess` on its trusted claim-based operator/backend boundary and left Firestore/Storage Rules independent of App Check.
- Added neutral customer-facing handling for callable attestation/authentication failures and found no hardcoded App Check debug token.
- Added focused Flutter and Functions source/configuration tests; genuine production attestation still requires registered providers and real Android/iOS devices.
- Performed no deployment and did not enable Firebase Console enforcement. Firestore and Storage production enforcement remain staged operator actions after the existing migration/remediation prerequisites.

### SEC-06 - Storage & Media Security
- Classified active profile, post, support, and legacy product-gallery paths; review media is not implemented.
- Restricted profile/post writes and deletes to authenticated UID-bound namespaces, made support attachments owner-private, and changed community/official reads from anonymous to signed-in Rules access.
- Denied all customer writes/deletes to official legacy product media while preserving authenticated catalog reads for `SincerelySea Store`.
- Enforced exact JPG/PNG/WebP MIME values and 5 MiB profile, 10 MiB post, and 8 MiB support size limits in Storage Rules, with aligned Flutter validation and clear failures.
- Stopped storing new support download URLs; new tickets retain validated private Storage paths while legacy token URLs are flagged for rollout remediation.
- Added seven Storage Emulator tests, a Firestore support-path regression, and Flutter media-policy coverage; the combined Firestore/Storage/backend suite passes 41/41 and Flutter passes 17/17.
- Documented that flat post paths and existing tokenized profile/post URLs cannot fully enforce SEC-05 visibility/blocking at the media layer; no proxy/CDN redesign was introduced.
- Performed no production deployment, Storage deletion, object migration, or App Check enforcement change.

## 2026-09-20

### SEC-05 - Post Visibility & Block Enforcement
- Added one Firestore post-read policy for authenticated public, approved-follower, private-owner, legacy official-product, and conservative legacy community behavior.
- Enforced symmetric blocks on direct post reads, parent comment/reply reads, and new likes, shares, comments, or replies.
- Restricted customer creation to self-owned community posts, allowlisted owner edits, protected ownership/type/counters, and validated caller-only like toggles.
- Corrected follower approval Rules so public follows remain direct while private-account followers require the owner's pending-request acceptance; pending requests grant no post access.
- Validated deterministic owner-controlled block records and retained owner-only hidden/saved post state.
- Replaced unsafe broad feed/search/map/profile post queries with a shared author-scoped query service compatible with Rules; no new composite index is required.
- Kept legacy community posts without `visibility` owner-only pending normalization while retaining signed-in reads of legacy official product posts, subject to blocks.
- Added focused emulator coverage; no production deployment or social/profile/order migration was performed.

### SEC-04 - User Data Privacy and Legal/Support Alignment
- Split customer records into signed-in-readable allowlisted `users_public` profiles and owner-only `users_private` account/contact data; made mixed legacy `users` documents owner-only.
- Routed profile/community reads, checkout prefill, account export/deletion, notification identity, and trusted role metadata to the correct visibility boundary.
- Removed email-prefix fallbacks from public community identity writes so private authentication email is not reused as a public handle.
- Extended trusted account deletion to remove both new profile documents while preserving legacy subcollection cleanup.
- Aligned active Terms & Conditions, Privacy Policy, and in-app Support content with the customer-only community and official-store architecture, without claiming external legal review.
- Added shared legal/support metadata, preserved registration acceptance and canonical registration/settings routes, and removed unsupported contact-response promises.
- Added focused source tests plus Firestore Emulator coverage for public-field allowlisting, cross-user public reads, private-read denial, owner private access, and owner-only legacy records.
- Kept SEC-01 at 7/8 and SEC-02/SEC-03 implemented/tested but not deployed. SEC-04 is also not deployed; production user-data backfill and coordinated app/Rules release remain required.

### SEC-03 - Trusted Checkout & Order State
- Replaced Flutter order creation and cancellation transactions with authenticated `createCustomerOrder` and `cancelCustomerOrder` callables.
- Made the backend load official-store products, validate availability, derive item snapshots/prices/totals, and atomically decrement ready stock before creating a pending order.
- Added UID-scoped deterministic checkout identities so repeated requests return one order without duplicate stock decrement or SEC-02 financial creation events.
- Made trusted cancellation verify ownership and pending state, restore applicable stock once, and treat repeated cancellation as an idempotent success.
- Denied all Firestore client create/update/delete operations on `orders` while preserving own-order and authorized operational reads; ordinary customer stock writes remain denied.
- Added focused Rules and backend tests for direct-write denial, privacy, server price authority, invalid inventory, stock safety, idempotency, cancellation authorization, and SEC-02 integration.
- Kept legacy pending orders readable but blocked trusted cancellation when their client-authored stock snapshot cannot be safely restored without operator reconciliation.
- Kept SEC-01 at 7/8 and SEC-02 implemented/tested; no Functions/Rules deployment or production data migration was performed.

### SEC-02 - Trusted Financial Reporting
- Removed the Flutter `SalesReportingService` and `JournalEntry` model so customer clients no longer write `journal_entries` or `sales_reports`.
- Added trusted order-created and order-cancelled Cloud Functions that derive journals and UTC daily report increments from order snapshots.
- Made each financial event idempotent with deterministic `order_created_{orderId}` and `order_cancelled_{orderId}` journal identities and a transactional duplicate guard.
- Preserved finance-scope reads while denying every client create, update, and delete on both financial collections.
- Added focused Rules coverage for blocked finance writes and retained customer order create/cancel behavior, plus unit coverage proving retries do not double-count either event.
- Kept SEC-01 at 7/8, made no production deployment, and left client-authoritative order totals and stock mutation for SEC-03.

### MOB-01 - Customer-Only Mobile Surface
- Declared Flutter customer-facing only for ordinary, admin, and developer identities; privileged management belongs to a separate future backend website.
- Removed the mobile admin dashboard, access management, developer console, community moderation, sales/finance reports, seller order operations, product management, and Firebase health-check surfaces plus their dedicated client services/routes.
- Removed admin/developer badges and claim-gated menus from customer profiles and settings.
- Made PostService.addPost structurally community-only and removed dead client post audit/repair helpers; existing official product posts remain readable in feed and shared-post detail.
- Renamed SellerStorefrontScreen to OfficialStoreScreen, removed seller parameters, and centralized the official store identity and fulfilment constants.
- Retained customer catalog/search/filter, wishlist, cart, checkout, own-order history/detail, Buy Again, and pending-order cancellation.
- Added six MOB-01 source-boundary tests for customer navigation/settings, role-independent mobile behavior, removed management routes, community-only creation, official-store naming, and preservation of SEC-01 infrastructure.
- Preserved setUserAdminAccess, Firebase Auth custom claims, claim-aware Firestore Rules, trusted Admin SDK scripts, and admin_audit_logs; Firestore Rules, Storage Rules, Functions behavior, and production deployment state were not changed by MOB-01.

### Security
- Implemented the SEC-01 trust boundary by moving admin/developer/scope authorization from mutable Firestore user fields to Firebase Auth custom claims; claim-authoritative production Rules are active, while the fresh-token privileged smoke matrix remains incomplete.
- Firestore Rules now reject privileged authority fields during customer registration and keep all authority fields immutable to clients.
- Added an audited callable role-management command plus a trusted local Admin SDK bootstrap/migration script.
- Added nine Firestore Emulator tests for registration, explicit admin/developer escalation attempts, protected authority-field creation and add/change/removal, ordinary profile updates, trusted admin/developer access, unauthenticated access, non-admin access, and forged legacy roles.
- Hardened the local claim bootstrap so it requires the exact production project, explicit UID/role/scopes, a dry run, and a separate `--confirm` execution.
- Added a read-only legacy privileged-account inventory that reports candidate UIDs and claim state without exposing email addresses or granting access.
- Audited the production inventory command as read-only, verified its exact-project rejection guard, confirmed Google Cloud CLI/Application Default Credentials, and completed the inventory against `gen-lang-client-0026437130`.
- Recorded the operator's explicit identity approval and provisioned `WT0trMBt9zNaMFYXQ61cs67K1x53` as developer with all five supported scopes.
- Provisioned `4RWo2A35L2NYavF4NuD0VwINOmB2` as admin with the operational scopes `products`, `orders`, `finance`, and `community`; intentionally withheld the privilege-delegating `roles` scope.
- Independently verified both enabled Firebase Auth accounts and their exact custom claims after provisioning and again immediately before Rules deployment.
- Deployed only claim-authoritative Firestore Rules to `gen-lang-client-0026437130` with `firebase deploy --only firestore:rules --project gen-lang-client-0026437130`; the active Rules API release points to ruleset `ed2fdf20-027d-4e7b-b271-51033f9d6c16`.
- Kept production authorization smoke verification separate from Rules deployment and required fresh privileged tokens before attempting it.
- Added a project-locked, read-only SEC-01 production verifier that uses in-memory authentication, bounded Firestore reads, no mutation APIs, and no token output.
- Reconfirmed both approved Auth claim sets and verified in production that unauthenticated `admin_audit_logs` access is denied. The remaining privileged smoke cases stopped before Firestore access because operator ADC lacks `iam.serviceAccounts.signBlob` and no reachable signed-in application session was available; no IAM, Rules, claims, or production data were changed.

### Changed
- Registration no longer writes legacy role or scope defaults from Flutter.
- Flutter no longer contains admin gates or role-management actions; the callable backend remains available for the future backend website.
- Added `SECURITY.md` and synchronized the roadmap, technical blueprint, and architectural decisions with the implemented trust boundary.
- Repaired the incomplete Functions dependency installation that omitted the Firebase SDK executable shim, using a lockfile-consistent clean install under Node.js 22 and npm 10.
- Moved the Functions runtime from Node.js 20 to supported Node.js 22; retained `firebase-functions` 5.1.1 and `firebase-admin` 12.7.0 after compatibility validation rather than introducing unrelated major upgrades.
- Deployed only `setUserAdminAccess` to `gen-lang-client-0026437130`; the production Functions inventory confirms the v2 callable is active in `us-central1` on Node.js 22.
- Kept SEC-01 at 7/8 and blocked because the refreshed privileged application sessions are not reachable by the verifier; developer/admin positive reads, admin `roles` denial, and authenticated profile reads remain. Recorded the separate Artifact Registry cleanup-policy warning emitted after successful Function creation and the non-blocking Rules compiler warnings for existing unused helpers.

## 2026-09-19

### Added
- Master product blueprint, technical architecture/security audit, dependency-ordered roadmap, user flows, and decision log.

### Changed
- Documentation policy now requires blueprint/roadmap review and evidence-based roadmap updates.

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
