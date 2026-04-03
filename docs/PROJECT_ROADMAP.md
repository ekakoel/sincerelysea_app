# SincerelySea Project Roadmap

Dokumen ini menjadi peta pengembangan tingkat tinggi agar AI dan developer berikutnya mudah memahami prioritas proyek.

## Current State

SincerelySea saat ini adalah:

- aplikasi komunitas berbasis Flutter + Firebase
- official `SincerelySea Store` yang dikelola admin
- memiliki scope admin terpisah untuk `products`, `orders`, `finance`, `community`, dan `roles`
- memiliki dasar reporting melalui `sales_reports` dan `journal_entries`

## Product Roadmap

### 1. Store & Catalog

Owner scope: `products`

Target:

- editing produk yang lebih lengkap
- category management
- bulk stock update
- publish/unpublish product
- image management per produk

### 2. Order Operations

Owner scope: `orders`

Target:

- bulk order actions
- internal note per order
- shipping workflow yang lebih detail
- packing / fulfillment checklist
- order SLA / urgency indicators

### 3. Transaction Reporting

Owner scope: `finance`

Target:

- filter laporan per hari, minggu, bulan
- export CSV/PDF
- dashboard gross/net/cancelled sales
- struktur journal account yang lebih final
- reconciliation flow antara order dan laporan

### 4. Community Administration

Owner scope: `community`

Target:

- dashboard report moderation
- resolution notes
- moderation history
- escalation flow untuk report penting

### 5. Access Control

Owner scope: `roles`

Target:

- preset admin templates
- audit log yang lebih kaya
- admin activity monitoring
- scope validation yang lebih ketat

## Technical Roadmap

### Short Term

- rapikan naming file/class yang masih memakai istilah `seller`
- tambah migrasi data untuk product/order lama agar konsisten dengan `SincerelySea Store`
- tambah test coverage untuk admin scope dan commerce reporting

### Mid Term

- pisahkan dashboard per scope
- tambah Cloud Functions untuk reporting automation
- tambah export service untuk finance

### Long Term

- integrasi sistem jurnal final
- dashboard operasional internal yang lebih komprehensif
- workflow approval untuk perubahan produk, order, dan finance

## Documentation Rules

Setiap pengembangan baru wajib sinkron dengan:

- `README.md`
- `docs/BUSINESS_DOMAIN.md`
- `docs/SCOPE_GUIDE.md`
- `docs/PROJECT_ROADMAP.md`
- `docs/CHANGELOG.md`
