# SincerelySea Project Roadmap

> **Superseded for active development.** This pre-audit document is retained as historical context. Use [ROADMAP.md](ROADMAP.md), [BLUEPRINT.md](BLUEPRINT.md), and [TECHNICAL_BLUEPRINT.md](TECHNICAL_BLUEPRINT.md) as the current source of truth.

> **MOB-01 alignment:** Flutter is customer-facing only. Every product, order, finance, moderation, user, and role administration target below belongs to the separate backend website; it must not be restored as a Flutter route.

> **Security checkpoint:** SEC-01 through SEC-07 are the frozen mobile security baseline. [PRODUCTION_ROLLOUT.md](PRODUCTION_ROLLOUT.md) is the single authority for canonical status, production prerequisites, deployment order, rollback, acceptance gates, and smoke verification. QA-01 is complete at the local source/test/emulator and Android debug-build boundary without weakening these controls; the next phase is REL-01 Android/iOS release readiness.

> **SEC-02 alignment:** Flutter cannot write financial collections. Trusted Cloud Functions derive idempotent creation/cancellation journals and daily reports from order documents. Source/tests are complete and coordinated production deployment remains pending.

> **SEC-03 alignment:** Flutter now requests checkout and cancellation through trusted callables. New orders use server-loaded prices/snapshots, transactional stock mutation, pending-only cancellation, and UID-scoped idempotency. Source and tests are complete but not deployed; legacy pending orders require operator reconciliation before trusted cancellation.

> **SEC-04 alignment:** Source now separates signed-in-readable `users_public` profiles from owner-only `users_private` data and keeps mixed legacy `users` documents owner-only. Terms, Privacy, and Support are aligned to the customer-only app. Tests are complete, but coordinated production backfill and deployment are pending.

> **SEC-05 alignment:** Firestore Rules now enforce public/follower/private posts, symmetric blocking, parent-gated comments/replies, protected community-post writes, and owner-only hide/save state. Source/tests are complete and not deployed; legacy community posts need visibility normalization before cross-user discovery.

> **SEC-06 alignment:** Storage Rules now require authentication, path ownership, exact image MIME allowlists, and per-class size limits; support attachments are owner-private and official product media is customer read-only. Source/tests are complete and not deployed. Legacy support token URLs require remediation, while post-level Storage visibility remains limited by the existing flat media path.

> **SEC-07 alignment:** Flutter now selects debug App Check providers only for debug builds and Play Integrity/App Attest with DeviceCheck fallback for non-debug builds. Customer-sensitive callables declare native App Check enforcement while retaining Auth and backend validation. Source/test readiness is complete; provider registration, deployment, Firebase service enforcement, and real-device validation remain production actions.

Dokumen ini menjadi peta pengembangan tingkat tinggi agar AI dan developer berikutnya mudah memahami prioritas proyek.

## Current State

SincerelySea saat ini adalah:

- aplikasi customer community + official store berbasis Flutter + Firebase
- mobile surface tanpa management UI untuk ordinary, admin, maupun developer account
- official `SincerelySea Store` yang dikelola dari backend website terpisah
- memiliki scope backend terpisah untuk `products`, `orders`, `finance`, `community`, dan `roles`
- memiliki trusted reporting untuk event order dibuat/dibatalkan melalui `sales_reports` dan `journal_entries`
- memiliki trusted callable checkout/cancellation untuk order baru, authoritative pricing, dan stock mutation
- memiliki source-level public/private customer profile split dan legal/support content yang selaras; production backfill belum dijalankan
- memiliki source-level social visibility/block enforcement dan Rules-compatible author-scoped feed/search/map/profile queries; belum deployed
- memiliki owner-scoped Storage media rules, private support attachments, dan customer-read-only official media; belum deployed
- memiliki App Check source/test readiness untuk Android, iOS, dan customer callables; enforcement produksi Firestore/Storage belum diaktifkan atau diverifikasi
- memiliki navigasi customer final Home/Search/Explore/Shop/Profile, Create Post komunitas dari Home, Settings berbasis kebutuhan customer, dan state loading/empty/error/retry yang konsisten pada layar utama
- memiliki flow customer MOB-03 yang lengkap pada level source/test serta product review MOB-03A berbasis rating 1-5 dan teks, satu review per customer/product, author dari users_public, dan mutasi owner-only; media, verified purchase, aggregate tepercaya, dan moderasi review belum diimplementasikan
- memiliki QA-01 lokal yang lulus analyze, Flutter tests, Functions/Rules/Storage emulator tests, Auth/Firestore/Storage account-lifecycle integration, dan Android debug build, serta deklarasi index untuk filtered collection-group lifecycle/wishlist queries; real-device auth/permissions/App Check serta build/signing iOS masih menunggu REL-01 dan index belum dideploy

## Product Roadmap

### 1. Store & Catalog

Owner scope: `products`

Plane: backend website.

Target:

- editing produk yang lebih lengkap
- category management
- bulk stock update
- publish/unpublish product
- image management per produk

### 2. Order Operations

Owner scope: `orders`

Plane: backend website.

Target:

- bulk order actions
- internal note per order
- shipping workflow yang lebih detail
- packing / fulfillment checklist
- order SLA / urgency indicators

### 3. Transaction Reporting

Owner scope: `finance`

Plane: backend website.

Target:

- filter laporan per hari, minggu, bulan
- export CSV/PDF
- dashboard gross/net/cancelled sales
- struktur journal account yang lebih final
- reconciliation flow antara order dan laporan

### 4. Community Administration

Owner scope: `community`

Plane: backend website.

Target:

- dashboard report moderation
- resolution notes
- moderation history
- escalation flow untuk report penting

### 5. Access Control

Owner scope: `roles`

Plane: backend website.

Target:

- preset admin templates
- audit log yang lebih kaya
- admin activity monitoring
- scope validation yang lebih ketat

## Technical Roadmap

### Short Term

- pertahankan MOB-01 customer-only route boundary dengan source tests
- pertahankan regresi MOB-02 untuk state tab/back, Create Post komunitas, struktur Settings, legal/support, dan error state netral
- pertahankan regresi MOB-03 untuk auth, community/social, commerce, notifications, profile/settings, support/legal, dan account lifecycle
- pertahankan regresi MOB-03A untuk deterministic review ownership, rating/content validation, public author identity, dan larangan cross-user mutation
- tambah migrasi data untuk product/order lama agar konsisten dengan `SincerelySea Store`
- selesaikan SEC-01 fresh-token production smoke matrix

- jalankan hanya rollout terkoordinasi dari register, gate, dan urutan kanonis di `docs/PRODUCTION_ROLLOUT.md`
- lanjutkan ke REL-01 untuk Android/iOS release readiness, real-device auth/permission/App Check, dan build/signing iOS tanpa deployment produksi prematur

### Mid Term

- bangun dashboard backend website per scope
- perluas Cloud Functions reporting di luar event order dibuat/dibatalkan setelah lifecycle order backend tersedia
- tambah export service untuk finance

### Long Term

- integrasi sistem jurnal final
- dashboard operasional internal pada backend website
- workflow approval untuk perubahan produk, order, dan finance

## Documentation Rules

Setiap pengembangan baru wajib sinkron dengan:

- `README.md`
- `docs/BUSINESS_DOMAIN.md`
- `docs/SCOPE_GUIDE.md`
- `docs/PROJECT_ROADMAP.md`
- `docs/BLUEPRINT.md`
- `docs/SECURITY.md`
- `docs/PRODUCTION_ROLLOUT.md`
- `docs/CHANGELOG.md`
