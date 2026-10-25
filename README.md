# MAKCO v3 — Chennai Metro booking

Chennai Metro booking app: a Rust proxy over the MovingTech / Chennai One API
and a Flutter Android client built around one screen — pick a start, pick a
stop, see live fares, pay, scan the QR.

Metro-only. Bus is out of scope until upstream returns Chennai data.

## Stack

| Layer | Tech |
|-------|------|
| Backend | Rust, axum, reqwest |
| App | Flutter 3.47, Riverpod 3, go_router, qr_flutter |
| Storage | flutter_secure_storage, offline cache, local favourites |
| Payments | Juspay (via MovingTech) |
| Auth | Phone OTP (4-digit) with a stored session token |
| Deploy | systemd `makco.service` on `:8080`, nginx for APK downloads |

## Layout

```
makco/
├── backend/            # Rust axum proxy
├── frontend/flutter/   # Flutter app (Madras Flow)
├── docs/               # API_REFERENCE, SETUP, DESIGN
├── .github/workflows/  # CI (backend + Flutter + APK artifact)
├── test/               # Flutter widget smoke tests (inside frontend/flutter)
├── MISSION.md          # project memory / roadmap
└── AGENTS.md           # agent config
```

## Run

Backend:

```bash
cd backend
cargo build --release
./target/release/makco            # http://127.0.0.1:8080
```

App:

```bash
cd frontend/flutter
flutter pub get
flutter test
flutter build apk --release       # signed with android/makco-release.jks
```

Download: `http://163.123.236.154/app-release.apk`

## Docs

- `docs/API_REFERENCE.md` — endpoints, modes, response shapes, payment flow
- `docs/DESIGN.md` — "Madras Flow" design language
- `docs/SETUP.md` — build, deploy and service setup
- `MISSION.md` — project memory and roadmap
