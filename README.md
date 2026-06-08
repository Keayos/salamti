# salamti-app
A cross-platform mobile application built with Flutter and Dart designed to provide vehicle telemetry tracking, On-Board Unit (OBU) device synchronization, and automated legal identification document verification. The app features secure local token storage, Google authentication, real-time location mapping services, and remote API integrations.
# Salamti 📐✨

## Description
Salamti is a robust, production-ready cross-platform mobile application built with the Flutter framework and Dart. Designed to enhance vehicular operations and user safety, the app acts as a central hub for vehicle management and IoT connectivity by pairing directly with vehicle On-Board Units (OBU). It securely syncs device metadata, monitors hardware SIM states, logs driving telemetry, and features a digital identity vault enabling seamless document uploads for driver licenses and ID cards.

---

## Features
- **OBU & Vehicle Management:** Integrates directly with remote backend endpoints to pair, test, and register vehicular On-Board Units alongside active SIM network indicators.
- **Identity & Document Verification:** Includes an automated settings portal allowing users to capture, crop, and upload high-resolution verification images of driver licenses and identification cards.
- **Real-Time Mapping & Telemetry:** Combines OpenStreetMap layers and Google Maps SDKs to track active coordinates, evaluate operational paths, and log GPS locations safely.
- **Secure Authentication Hub:** Implements a streamlined authentication lifecycle leveraging Google Sign-In federated identity providers combined with encrypted hardware storage keys.

---

## Technologies Used
* **Flutter & Dart SDK** (Cross-platform application core framework)
* **Google Maps Flutter & Flutter Map** (Hybrid tile-rendering geographical engines)
* **Firebase Core & Google Sign-In** (Federated identity management and cloud services)
* **Http & Http Parser** (Multi-part binary document stream handling and API payload execution)
* **Flutter Secure Storage & Shared Preferences** (Hardware-level keychain encryption and key-value state persistence)

---

## How to Use
1. **Set Up the Environment:** Ensure you have the Flutter SDK (compatible with environment rules `>=3.0.0 <4.0.0`) and Android Studio/Xcode properly configured on your computer.
2. **Fetch Dependencies:** Navigate to your project root directory and run the package retriever to clean and install project plugins:
   ```bash
   flutter pub get