# Geometric_Diagram Template

## Description
Salamti (سلامتي) is a feature-rich, cross-platform health and vehicular safety mobile application built using Flutter and Dart. The app acts as an intelligent safety companion by interfacing with automotive On-Board Units (OBU) to track real-time vehicle positioning and monitor hardware device health (SIM status, firmware version, and device states). It features an instant SOS broadcast system, an offline-cached emergency medical profile, multi-tier notification logs, and an emergency contacts manager designed to automatically sync and dispatch alerts over secured remote API endpoints.

---
lib/
├── main.dart             # Application initialization and entry script
├── screens/
│   ├── auth_screen.dart     # Multi-step authentication, login, and registration wizard
│   ├── home_screen.dart     # Interactive SOS layout, live maps, and OBU telemetry panel
│   ├── profile_screen.dart  # Vehicle profile matching and OBU installation identifiers
│   ├── health_screen.dart   # Local medical card repository and allergy tracker
│   ├── contacts_screen.dart # Emergency guardian coordinator and channel setup
│   ├── settings_screen.dart # Account management, profile image uploads, and security configuration
│   └── alerts_screen.dart   # Interactive threat notification timelines and historical system logs
├── theme/
│   └── app_theme.dart       # Deep dark palette specifications and structural font families
├── services/
│   ├── auth_service.dart    # Token managers and login controllers
│   └── api_config.dart      # Global API routing parameters and server endpoint paths
└── widgets/
    └── common.dart          # Reusable customized UI containers and layout dividers
---

## Features
- **OBU Hardware Companion:** Interfaced telemetry module that monitors active vehicular On-Board Units, maps live GPS coordinate locations using automated map views, and checks structural device health flags (ACTIVE, READY, BROKEN).
- **Instant SOS Broadcast:** An interactive, interactive pulse-animated SOS module designed to trigger immediate emergency distress protocols and dispatch critical status markers.
- **Emergency Medical Vault:** A locally cached profile repository letting users configure crucial blood types (e.g., A+, O-), track ongoing medications, compile explicit allergy databases, and sync information securely to remote health profiles.
- **Smart Contact Synchronization:** A dedicated contact manager with local SharedPreferences fallback caching allowing users to add trusted guardians, define relationship tiers (FAMILY, PARTNER, COLLEAGUE), and configure custom granular alerting options (Auto-Notify, Instant SMS, Voice Calls).
- **Multi-Stage Authentication Architecture:** A secure multi-page registration wizard handling credential authentication, profile assignment rules, and unified token tracking.

---

## Technologies Used
* **Flutter Framework & Dart SDK** (Cross-platform client architecture)
* **Flutter Map & Geolocator** (Real-time geographic coordinate tracking and map layer tiling)
* **Provider** (Centralized app state management)
* **Http & Http Parser** (REST API request orchestration, multi-part form payloads, and error handling)
* **Shared Preferences & Flutter Secure Storage** (Encrypted token keychains and high-performance local data caching)

---

## How to Use
1. **Configure Prerequisites:** Verify that you have the Flutter SDK set up on your machine satisfying target bounds (`>=3.0.0 <4.0.0`).
2. **Install Code Packages:** Execute the pub dependency structural manager to pull and bind required third-party plugins:
   ```bash
   flutter pub get