# Setup Guide - Makco v3

Rust backend (axum). Runs against the MovingTech / Chennai One pilot API.

## Prerequisites

- Rust 1.75+ (1.99 verified)
- Flutter 3.47+ / Dart 3.13+ (SDK at `/opt/flutter`)
- Android SDK 36 at `/opt/android-sdk` (build-tools 36.0.0, platform 36)

## Frontend

```bash
cd frontend/flutter
flutter pub get
flutter analyze
flutter test                  # widget smoke tests
flutter build apk --release   # signed via android/makco-release.jks
```

State: Riverpod 3 (`lib/state/`); routing: go_router (`lib/router.dart`).
Ticket deep link: `makco://app/ticket?ref=<ticketRef>`.

Local data:

- Session token/user id: `flutter_secure_storage` (legacy plain-preferences
  values migrate on first boot).
- Offline cache: `lib/services/cache.dart` keeps the last stations and tickets.
- Favourites: `lib/state/favourites.dart`.
- Fonts: bundled Bricolage Grotesque and Public Sans in `assets/fonts/` (OFL).
- Nearby stations use `geolocator`; Android asks for location only when the
  rider taps "Near me".

APK: `frontend/flutter/build/app/outputs/flutter-apk/app-release.apk`
(published to `http://163.123.236.154/app-release.apk`).

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

## CI

`.github/workflows/ci.yml` runs `cargo check/test` for the backend and
`flutter analyze/test` for the app. It builds a release APK when the
`MAKCO_KEYSTORE_BASE64` secret is configured, otherwise a debug APK, and
uploads it as an artifact.

## Local API test

The backend is a thin proxy — the old `scripts/test_api.py` (Python) against
the MovingTech base URL still exercises the full upstream flow. Auth sends a
real SMS OTP; do not run casually.

## Production

The API currently runs directly on the server IP over HTTP:
`http://163.123.236.154:8080` (UFW allows 8080). It is managed by systemd:

```bash
sudo systemctl status makco
sudo systemctl restart makco
journalctl -u makco -f
```

The old nginx/Cloudflare domain setup (`api.pandatern.tech`) was removed; the
panda* site configs were moved to `/root/nginx-panda-backup`. Terminate TLS in
front of `localhost:8080` later if a domain is added back.
