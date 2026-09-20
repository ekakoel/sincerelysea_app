# SincerelySea Project Roadmap

> **Superseded for active development.** This pre-audit document is retained as historical context. Use [ROADMAP.md](ROADMAP.md), [BLUEPRINT.md](BLUEPRINT.md), and [TECHNICAL_BLUEPRINT.md](TECHNICAL_BLUEPRINT.md) as the current source of truth.

> **MOB-01 alignment:** Flutter is customer-facing only. Every product, order, finance, moderation, user, and role administration target below belongs to the separate backend website; it must not be restored as a Flutter route.

> **SEC-02 alignment:** Flutter cannot write financial collections. Trusted Cloud Functions now derive idempotent creation/cancellation journals and daily reports from order documents. Production deployment is intentionally pending; SEC-03 is next for authoritative order totals and inventory mutation.

> **SEC-03 alignment:** Flutter now requests checkout and cancellation through trusted callables. New orders use server-loaded prices/snapshots, transactional stock mutation, pending-only cancellation, and UID-scoped idempotency. Source and tests are complete but not deployed; legacy pending orders require operator reconciliation before trusted cancellation.

Dokumen ini menjadi peta pengembangan tingkat tinggi agar AI dan developer berikutnya mudah memahami prioritas proyek.

## Current State

SincerelySea saat ini adalah:

- aplikasi customer community + official store berbasis Flutter + Firebase
- mobile surface tanpa management UI untuk ordinary, admin, maupun developer account
- official `SincerelySea Store` yang dikelola dari backend website terpisah
- memiliki scope backend terpisah untuk `products`, `orders`, `finance`, `community`, dan `roles`
- memiliki trusted reporting untuk event order dibuat/dibatalkan melalui `sales_reports` dan `journal_entries`
- memiliki trusted callable checkout/cancellation untuk order baru, authoritative pricing, dan stock mutation

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
- tambah migrasi data untuk product/order lama agar konsisten dengan `SincerelySea Store`
- selesaikan SEC-01 fresh-token production smoke matrix
- rekonsiliasi pending legacy order sebelum deployment SEC-03

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
- `docs/CHANGELOG.md`
