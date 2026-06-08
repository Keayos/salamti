# Salamty — Flutter App
### Your Safety, Always Connected

A full Flutter implementation of the Salamty personal safety app with GPS tracking, emergency contacts, medical history, and hardware device integration.

---

## 📁 Project Structure

```
salamty/
├── lib/
│   ├── main.dart                  # App entry, navigation shell
│   ├── theme/
│   │   └── app_theme.dart         # Colors & theme constants
│   ├── widgets/
│   │   └── common.dart            # Reusable UI components
│   └── screens/
│       ├── splash_screen.dart     # Animated loading screen
│       ├── auth_screen.dart       # Login & Register
│       ├── home_screen.dart       # Map + driving mode + SOS
│       ├── contacts_screen.dart   # Emergency contacts
│       ├── health_screen.dart     # Medical history
│       └── other_screens.dart     # Profile, Alerts, Settings
└── pubspec.yaml
```

---

## 🚀 Quick Start

### 1. Prerequisites
- Flutter SDK ≥ 3.0.0 — https://flutter.dev/docs/get-started/install
- Android Studio **or** VS Code with Flutter extension
- A connected Android/iOS device or emulator

### 2. Run the app

```bash
# Navigate into the project folder
cd salamty

# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run
```

### 3. Build for release

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Google Play)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release
```

---

## 📱 Screens

| Screen | Description |
|--------|-------------|
| **Splash** | Animated logo with syncing progress bar |
| **Login** | Email/password, Google & Apple sign-in |
| **Register** | Name, email, phone, password |
| **Home** | Dark map with GPS route, speed, stability indicator, SOS button |
| **Contacts** | Emergency contacts with auto-notify toggles, add new contact form |
| **Health** | Blood type selector, conditions, medications, allergies, emergency contacts |
| **Profile** | User info, verified badge, registered vehicle card |
| **Alerts** | Filterable notifications (All / Emergency / System) |
| **Settings** | Hardware connection, vehicle info, document upload, privacy toggles |

---

## 🎨 Design

- **Dark theme** — Deep navy `#0B1120` background
- **Electric blue** — `#2563EB` primary accent
- **Font** — Outfit (Google Fonts)
- **Color palette** exactly matches the original Salamty mockups

---

## 📦 Dependencies

| Package | Usage |
|---------|-------|
| `google_fonts` | Outfit font family |
| `flutter_map` | OpenStreetMap map widget |
| `latlong2` | GPS coordinate types |
| `provider` | State management |

---

## 🔌 Publishing to Google Play

1. Run `flutter build appbundle --release`
2. The `.aab` file will be at `build/app/outputs/bundle/release/app-release.aab`
3. Go to [Google Play Console](https://play.google.com/console)
4. Create a new app → Upload the `.aab` → Fill in store listing details → Publish

---

## 📝 Notes

- The map currently renders a **custom-painted grid** (no API key needed). To use real maps, replace the `_MapView` widget in `home_screen.dart` with `FlutterMap` + an OpenStreetMap tile layer.
- Authentication is **UI-only** — wire up Firebase Auth or your own backend in `auth_screen.dart`.
- Hardware Bluetooth/OBD integration can be added using the `flutter_blue_plus` package.
