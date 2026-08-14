# Setup Guide - Makco v3

Rust backend (axum) + Flutter & Android Kotlin frontends.
Runs against the MovingTech / Chennai One pilot API.

## Prerequisites

- Rust 1.75+ (1.97 verified)
- Flutter 3.24+ (3.44 verified)
- Android SDK 35 (for Android app), Java 17+

## Backend

```bash
cd backend
cargo build --release
cargo run --release          # serves on 0.0.0.0:8080
```

Health check:

```bash
curl http://localhost:8080/
```

### Environment

| Variable | Default | Notes |
|----------|---------|-------|
| PORT | 8080 | Listen port |
| MT_BASE_URL | https://api.moving.tech/pilot/app/v2 | Upstream |
| MERCHANT_ID | NAMMA_YATRI | Auth payload |
| CLIENT_ID | NAMMA_YATRI | Auth payload |
| ADMIN_PHONES | 8190835624 | Comma-separated; enables mock payment |

## Flutter app

```bash
cd frontend/flutter
flutter pub get
flutter run                 # emulator, points at http://10.0.2.2:8080
flutter build apk --release
```

API base is in `lib/services/api_service.dart` (`ApiService.baseUrl`). For a
physical device, change to `http://<your-lan-ip>:8080`.

## Android app

```bash
cd frontend/android
./gradlew assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

API base is in `data/remote/Api.kt` (`ApiClient.BASE_URL`). Emulator default:
`http://10.0.2.2:8080/`.

## Local API test

The backend is a thin proxy — the old `scripts/test_api.py` (Python) against
the MovingTech base URL still exercises the full upstream flow. Auth sends a
real SMS OTP; do not run casually.

## nginx / production

Proxy `https://api.pandatern.tech/` to `localhost:8080` (as in v2). Build the
release binary and run it under systemd.
