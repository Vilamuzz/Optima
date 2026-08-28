<p align="center">
  <img src="assets/images/logo.png" alt="Optima Logo" width="120" />
</p>

<h1 align="center">Optima POS</h1>

<p align="center">
  <strong>A modern, cross-platform Point of Sale system built with Flutter & Firebase.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#getting-started">Getting Started</a> •
  <a href="#project-structure">Project Structure</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

---

## Features

| Feature | Description |
|---|---|
| 🛒 **Point of Sale** | Fast, intuitive POS screen with barcode scanning, cart management, and checkout flow |
| 📦 **Product Management** | Add, edit, and organize products with categories, pricing, and stock tracking |
| 📊 **Daily Sales Reports** | View daily transaction summaries and sales analytics at a glance |
| 🔄 **Restocking** | Record restocking batches with full audit trail and cost tracking |
| 🖨️ **Bluetooth Receipt Printing** | Pair and print receipts to ESC/POS thermal printers via Bluetooth |
| 📱 **Barcode Scanner** | Scan product barcodes using the device camera for quick product lookup |
| 🏪 **Store Profile** | Customize store name, address, phone, and footer message for receipts |
| 🔐 **Authentication** | Secure login powered by Firebase Auth |
| 🌗 **Dark & Light Mode** | Automatic theme switching based on system preference |
| ☁️ **Cloud Sync** | All data is stored and synced in real-time via Cloud Firestore |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | [Flutter](https://flutter.dev) (Dart) |
| **Backend / Database** | [Firebase](https://firebase.google.com) (Cloud Firestore, Firebase Auth) |
| **State Management** | [Provider](https://pub.dev/packages/provider) |
| **Printing** | [flutter_blue_plus](https://pub.dev/packages/flutter_blue_plus) + [esc_pos_utils](https://pub.dev/packages/esc_pos_utils) |
| **Barcode Scanning** | [mobile_scanner](https://pub.dev/packages/mobile_scanner) |
| **Typography** | [Google Fonts](https://pub.dev/packages/google_fonts) |

---

## Architecture

The project follows a **clean layered architecture**:

```
lib/
├── main.dart              # App entry point & AuthWrapper
├── firebase_options.dart  # Firebase config (git-ignored)
├── models/                # Data models (Product, Transaction, Category, etc.)
├── services/              # Business logic & Firebase CRUD operations
├── providers/             # State management (ChangeNotifiers)
├── screens/               # Full-page UI screens
├── widgets/               # Reusable UI components
└── theme/                 # App-wide theming (light & dark)
```

---

## Getting Started

### Prerequisites

Make sure you have the following installed:

- **Flutter SDK** ≥ 3.13  
  → [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Dart SDK** (included with Flutter)
- **Android Studio** or **VS Code** with Flutter/Dart extensions
- **Firebase CLI**  
  → [Install Firebase CLI](https://firebase.google.com/docs/cli#install_the_firebase_cli)
- **FlutterFire CLI**  
  ```bash
  dart pub global activate flutterfire_cli
  ```
- A physical Android device (recommended for Bluetooth printing & barcode scanning)

---

### 1 · Clone the Repository

```bash
git clone https://github.com/Vilamuzz/Optima.git
cd Optima
```

### 2 · Set Up Firebase

This project uses Firebase for authentication and data storage. Since `firebase_options.dart` is **git-ignored** for security, you must generate your own:

1. **Create a Firebase project** at [console.firebase.google.com](https://console.firebase.google.com).

2. **Enable the following Firebase services** in the console:
   - **Authentication** → enable Email/Password sign-in
   - **Cloud Firestore** → create a database (start in test mode or configure rules)

3. **Configure Firebase for your Flutter app:**
   ```bash
   flutterfire configure
   ```
   This will generate `lib/firebase_options.dart` and the platform-specific config files (`google-services.json` for Android, `GoogleService-Info.plist` for iOS).

> [!IMPORTANT]
> You must run `flutterfire configure` before the app will compile. The generated `firebase_options.dart` file is required by `main.dart`.

### 3 · Install Dependencies

```bash
flutter pub get
```

### 4 · Run the App

```bash
# On a connected device / emulator
flutter run

# Or specify a platform
flutter run -d android
flutter run -d chrome     # Web (limited — no Bluetooth/camera)
```

> [!NOTE]
> Bluetooth printing and barcode scanning require a **physical device**. These features are not available on emulators or web.

---

### Optional: Generate App Icons

The project uses [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons) to generate custom launcher icons from `assets/images/logo.png`:

```bash
dart run flutter_launcher_icons
```

---

## Firestore Data Structure

The app expects the following top-level collections in your Firestore database. They are created automatically as you use the app:

| Collection | Purpose |
|---|---|
| `products` | Product catalog (name, price, stock, barcode, category) |
| `categories` | Product categories |
| `transactions` | Completed sales records |
| `restocks` | Restocking batch records |
| `storeProfile` | Store name, address, phone, receipt footer |

---

## Building for Production

### Android APK

```bash
flutter build apk --release
```

The output APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

### Android App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

> [!WARNING]
> Before releasing, update the signing config in `android/app/build.gradle.kts` with your own keystore.

---

## Contributing

Contributions are welcome! To get started:

1. **Fork** the repository
2. **Create a branch** for your feature: `git checkout -b feature/my-feature`
3. **Commit** your changes: `git commit -m "Add my feature"`
4. **Push** to your branch: `git push origin feature/my-feature`
5. **Open a Pull Request**

Please make sure your code follows the existing style and passes `flutter analyze` before submitting.

---

## License

This project is proprietary. All rights reserved.

---

<p align="center">
  Built with ❤️ using Flutter & Firebase
</p>
