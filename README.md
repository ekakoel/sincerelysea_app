# SincerelySea App  

SincerelySea adalah aplikasi mobile berbasis Flutter yang dirancang sebagai platform komunitas untuk berbagi cerita, pengalaman, dan inspirasi secara positif dan autentik. Aplikasi ini mengutamakan kenyamanan pengguna, keamanan data, dan pengalaman sosial yang modern.

---

## 🚀 Features

- 🔐 Authentication (Login & Register)
- 🏠 Home Feed (Post & Timeline)
- 📝 Create Post (Text, Hashtag, Media)
- ❤️ Interaction (Like, Comment)
- 👤 User Profile
- 📷 Media Support (Image Upload)
- ☁️ Firebase Integration
- 📱 Android & iOS Support

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
│
├── models/          # Data models
├── services/        # Firebase & business logic services
├── screens/         # UI screens
├── widgets/         # Reusable components
├── providers/       # State management
└── main.dart        # App entry point
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

## 📌 Roadmap

- 🔔 Push Notification  
- 🎥 Video Upload  
- 💬 Real-time Chat  
- 🌍 Location-based Feature  
- 🛡️ Advanced Security Rules  

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

## 🌊 About SincerelySea

SincerelySea hadir sebagai ruang digital untuk berbagi cerita yang tulus, membangun komunitas positif, dan menciptakan koneksi yang bermakna.
