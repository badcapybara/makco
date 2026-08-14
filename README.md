# MAKCO v3 — Chennai Transit Terminal

Multimodal Chennai transit booking (bus + metro) with a Rail Signage /
Data Terminal UI. Rust backend proxying the MovingTech / Chennai One API,
with Flutter and Android Kotlin frontends sharing one design language.

## What changed vs v2 (Nim)

- Backend rewritten in **Rust (axum)** — the old Nim backend crashed on
  MovingTech's Content-Length mismatch during admin mockPayment. reqwest
  handles it.
- Focus broadened from **metro-only → bus + metro** (BUS_HYBRID / METRO_V2).
- New endpoints: `/transit/*`, active routes, route stops, possible stops,
  ticket verify.
- New design language: **Rail Signage / Data Terminal** (split-flap boards,
  amber-on-black, monospace).

## Stack

| Layer | Tech |
|-------|------|
| Backend | Rust + axum + reqwest |
| Android | Kotlin + Jetpack Compose |
| Flutter | Dart + Material 3 (custom theme) |
| Payments | Juspay (via MovingTech) |
| Auth | Phone OTP (4-digit), persistent token |

## Layout

```
makco/
├── backend/            # Rust axum proxy
├── frontend/
│   ├── flutter/        # Flutter app (Rail Signage UI)
│   └── android/        # Kotlin Compose app (same UI)
├── docs/               # API_REFERENCE, DESIGN_LANGUAGE, SETUP
└── scripts/            # (future) e2e scripts
```

## Quick start

```bash
cd backend && cargo run --release          # http://localhost:8080
cd frontend/flutter && flutter run         # emulator
cd frontend/android && ./gradlew assembleDebug
```

## Docs

- `docs/API_REFERENCE.md` — every endpoint, modes, admin behavior
- `docs/DESIGN_LANGUAGE.md` — the Rail Signage design system
- `docs/SETUP.md` — build & run
- `MISSION.md` — agent brain / project memory