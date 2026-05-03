# SincerelySea App

SincerelySea adalah aplikasi mobile Flutter yang menggabungkan komunitas sosial dengan `admin-managed marketplace`. Aplikasi ini sekarang berfungsi sebagai ruang komunitas sekaligus `SincerelySea Store`, tempat brand memasarkan produk resminya langsung di dalam aplikasi.

---

## 📘 Documentation

Mulai 2026-04-03, setiap perubahan kode wajib didokumentasikan di file Markdown.

- Changelog utama: [docs/CHANGELOG.md](/Users/abc/SincerelySea/sincerelysea/docs/CHANGELOG.md)
- Aturan dokumentasi: [docs/DOCUMENTATION_POLICY.md](/Users/abc/SincerelySea/sincerelysea/docs/DOCUMENTATION_POLICY.md)
- Domain bisnis: [docs/BUSINESS_DOMAIN.md](/Users/abc/SincerelySea/sincerelysea/docs/BUSINESS_DOMAIN.md)
- Panduan scope admin: [docs/SCOPE_GUIDE.md](/Users/abc/SincerelySea/sincerelysea/docs/SCOPE_GUIDE.md)
- Roadmap proyek: [docs/PROJECT_ROADMAP.md](/Users/abc/SincerelySea/sincerelysea/docs/PROJECT_ROADMAP.md)

---

## 🧭 Project Summary

- `SincerelySea` adalah aplikasi komunitas + official store milik brand
- marketplace bersifat `admin-managed`, bukan multi-seller publik
- store resmi berjalan dengan nama `SincerelySea Store`
- admin dibagi berdasarkan scope kerja agar operasional lebih rapi

## 🧭 Business Domain

- `SincerelySea Store` adalah toko resmi brand di dalam aplikasi.
- Produk dikelola internal oleh user dengan role `admin`.
- User biasa berperan sebagai pembeli dan anggota komunitas.
- Commerce reporting mengikuti struktur `sales_reports` dan `journal_entries`.
- Admin internal dapat dibagi berdasarkan scope kerja:
  - `products`
  - `orders`
  - `finance`
  - `community`
  - `roles`

Dokumen domain lengkap:
- [docs/BUSINESS_DOMAIN.md](/Users/abc/SincerelySea/sincerelysea/docs/BUSINESS_DOMAIN.md)

## 🗂️ Admin Scope

- `products`: katalog, stock, preorder, dan pengelolaan produk
- `orders`: operasional order, status order, dan fulfilment
- `finance`: seluruh laporan transaksi, sales reports, dan journal entries
- `community`: report komunitas, moderasi post/user
- `roles`: pembagian akses admin

Dokumen scope lengkap:
- [docs/SCOPE_GUIDE.md](/Users/abc/SincerelySea/sincerelysea/docs/SCOPE_GUIDE.md)

## 🚀 Features

- Authentication dengan Firebase Auth
- Home feed komunitas, posting, interaksi, dan profile
- Social commerce dengan product post, cart, checkout, dan order flow
- `SincerelySea Store` yang dikelola admin
- Wishlist produk, saved products, dan official store catalog
- Admin dashboard, role management, sales reports, dan journal entries
- Scoped admin operations untuk product manager, order manager, dan community manager
- Scoped finance administration untuk semua laporan transaksi dan jurnal
- Firebase Firestore, Storage, App Check, dan Cloud Functions integration
- Android & iOS support

---

## 🗺️ Roadmap

Roadmap utama proyek dipisahkan per scope agar lebih mudah diikuti AI dan developer.

Fokus saat ini:

- penguatan admin scope
- operasional order yang lebih efisien
- transaction reporting dan integrasi jurnal
- tooling komunitas dan access control

Dokumen roadmap lengkap:
- [docs/PROJECT_ROADMAP.md](/Users/abc/SincerelySea/sincerelysea/docs/PROJECT_ROADMAP.md)

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
├── models/          # Product, order, cart, sales report, journal entry models
├── services/        # Auth, post, product, order, wishlist, reporting, admin
├── screens/         # Social, commerce, admin, settings, auth, profile screens
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

Scope admin utama:

- `products`: pengelolaan katalog dan inventori
- `orders`: pengelolaan order dan laporan penjualan
- `finance`: pengelolaan semua laporan transaksi dan journal entries
- `community`: pengelolaan report komunitas
- `roles`: pengelolaan akses admin

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
