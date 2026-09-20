# SincerelySea App

## Master documentation

Start every change with the [Master Product Blueprint](docs/BLUEPRINT.md) and [Development Roadmap](docs/ROADMAP.md). The repository is authoritative for current implementation; the blueprint defines the target product. Supporting references: [Technical Blueprint](docs/TECHNICAL_BLUEPRINT.md), [User Flows](docs/USER_FLOWS.md), and [Architectural Decisions](docs/DECISIONS.md).

**Current development phase:** `MOB-01 - Customer-Only Mobile Surface` is implemented in the repository. The Flutter app is the customer experience; privileged operations belong to a separate future backend website. SEC-01 remains at 7/8 because the fresh-token production smoke matrix is still blocked.

SincerelySea adalah aplikasi mobile Flutter khusus pelanggan yang menggabungkan komunitas sosial dengan toko resmi `SincerelySea Store`. Akun Firebase yang memiliki claim `admin` atau `developer` tetap melihat surface pelanggan yang sama dan tidak memperoleh menu manajemen di Flutter.

---

## 📘 Documentation

Mulai 2026-04-03, setiap perubahan kode wajib didokumentasikan di file Markdown.

- Changelog utama: [docs/CHANGELOG.md](docs/CHANGELOG.md)
- Aturan dokumentasi: [docs/DOCUMENTATION_POLICY.md](docs/DOCUMENTATION_POLICY.md)
- Domain bisnis: [docs/BUSINESS_DOMAIN.md](docs/BUSINESS_DOMAIN.md)
- Panduan scope backend: [docs/SCOPE_GUIDE.md](docs/SCOPE_GUIDE.md)
- Roadmap proyek: [docs/ROADMAP.md](docs/ROADMAP.md)

---

## 🧭 Project Summary

- Flutter adalah aplikasi komunitas + official store untuk pelanggan.
- Tidak ada konsep seller publik atau surface manajemen di mobile.
- Store resmi memakai `storeId=sincerelysea` dan `storeName=SincerelySea Store`.
- Backend website terpisah akan menjadi management plane untuk katalog, fulfilment, moderasi, finance, dan role.

## 🧭 Business Domain

- `SincerelySea Store` adalah toko resmi brand di dalam aplikasi.
- Produk dikelola internal melalui backend website, bukan Flutter.
- User biasa berperan sebagai pembeli dan anggota komunitas.
- Commerce reporting mengikuti struktur `sales_reports` dan `journal_entries`.
- Scope manajemen backend tetap dipertahankan:
  - `products`
  - `orders`
  - `finance`
  - `community`
  - `roles`

Dokumen domain lengkap: [docs/BUSINESS_DOMAIN.md](docs/BUSINESS_DOMAIN.md).

## 🗂️ Backend Management Scope

- `products`: katalog, stock, preorder, dan pengelolaan produk
- `orders`: operasional order, status order, dan fulfilment
- `finance`: seluruh laporan transaksi, sales reports, dan journal entries
- `community`: report komunitas, moderasi post/user
- `roles`: pembagian akses admin

Scope tersebut adalah otorisasi management plane dan tidak membuat menu Flutter berubah. Dokumen lengkap: [docs/SCOPE_GUIDE.md](docs/SCOPE_GUIDE.md).

## 🚀 Features

- Authentication dengan Firebase Auth
- Home feed komunitas, posting, interaksi, dan profile
- Community post, image, hashtag, location, like, comment, reply, save, follow, report, dan discovery
- Product post resmi tetap dapat dibaca; Flutter hanya dapat membuat community post biasa
- Katalog `SincerelySea Store`, search/filter, wishlist, cart, checkout, order history/detail, cancellation yang diizinkan, dan Buy Again
- Wishlist produk, saved products, dan official store catalog
- Settings pelanggan untuk account, privacy, notifications, support, legal, session, logout, dan account lifecycle
- Tidak ada dashboard, moderation, finance, role, product, atau order-management UI di Flutter
- Firebase Firestore, Storage, App Check, dan Cloud Functions integration
- Android & iOS support

---

## 🗺️ Roadmap

Roadmap utama proyek dipisahkan per scope agar lebih mudah diikuti AI dan developer.

Fokus berikutnya setelah MOB-01 adalah menyelesaikan SEC-01 fresh-token production smoke verification tanpa mengubah surface mobile atau memperluas scope ke backend website.

Dokumen roadmap lengkap:
- [docs/ROADMAP.md](docs/ROADMAP.md)

---

## 🛠️ Tech Stack

- **Framework**: Flutter  
- **Language**: Dart  
- **Backend**: Firebase  
  - Firebase Authentication  
  - Cloud Firestore  
  - Firebase Storage  
- **State Management**: Provider  
- **Version Control**: Git & GitHub  

---

## 📂 Project Structure

```
lib/
├── models/          # Customer commerce and compatibility models
├── services/        # Auth, community, customer commerce, support, notifications
├── screens/         # Customer social, shop, settings, auth, and profile screens
├── widgets/         # Reusable cards, images, and UI helpers
├── theme/           # Theme tokens and semantic colors
├── l10n/            # Localization files
└── main.dart        # App entry point and provider registration
```

---

## ⚙️ Installation Guide

### 1️⃣ Clone Repository

```bash
git clone https://github.com/ekakoel/sincerelysea_app.git
cd sincerelysea_app
```

### 2️⃣ Install Dependencies

```bash
flutter pub get
```

### 3️⃣ Setup Firebase

1. Buat project di Firebase Console  
2. Tambahkan Android & iOS app  
3. Download:
   - `google-services.json` → letakkan di `android/app/`
   - `GoogleService-Info.plist` → letakkan di `ios/Runner/`
4. Jalankan:

```bash
flutterfire configure
```

### 4️⃣ Run App

```bash
flutter run
```

---

## 📱 iOS Setup (Mac Required)

Pastikan sudah:

- Install Xcode  
- Install CocoaPods  

Kemudian jalankan:

```bash
cd ios
pod install
cd ..
flutter run
```

---

## 📦 Build Release

### Android
```bash
flutter build apk --release
```

### iOS
```bash
flutter build ios --release
```

---

## 🔐 Environment & Security

- API Keys tidak disimpan dalam repository.  
- Gunakan `.env` atau konfigurasi Firebase resmi.  
- Jangan commit file kredensial sensitif.  

---

## 🧾 Commerce Reporting

Laporan penjualan mengikuti alur:

`Order -> Journal Entry -> Sales Report`

Koleksi Firestore utama:

- `products/{productId}`
- `orders/{orderId}`
- `sales_reports/{reportId}`
- `journal_entries/{entryId}`

Scope management plane utama:

- `products`: pengelolaan katalog dan inventori
- `orders`: pengelolaan order dan laporan penjualan
- `finance`: pengelolaan semua laporan transaksi dan journal entries
- `community`: pengelolaan report komunitas
- `roles`: pengelolaan akses admin

Flutter tidak membaca koleksi finance sebagai dashboard dan tidak menyediakan aksi manajemen. Penulisan jurnal/report yang masih terjadi di transaksi customer adalah risiko SEC-02 yang belum diselesaikan dan bukan bukti bahwa finance management tersedia di mobile.

Event order yang saat ini dicatat ke jurnal:

- `order_created`
- `order_paid`
- `order_cancelled`

---

## 🤝 Contributing

Kontribusi sangat terbuka.

1. Fork repository  
2. Create new branch  
3. Commit changes  
4. Open Pull Request  

---

# Debuging:
- flutter clean
- flutter pub get
- cd ios && pod install && cd ..
- flutter run -d <iphone_id>

---

# Deploy Firebase Rule
- firebase deploy --only firestore:rules
- firebase deploy --only storage

---

## 📄 License

This project is licensed under the MIT License.

---

## About SincerelySea

SincerelySea hadir sebagai ruang digital untuk berbagi cerita yang tulus sekaligus membangun official store experience yang 
terhubung langsung dengan komunitasnya.
