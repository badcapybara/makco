# MISSION — Makco v3 Brain File

This file is the persistent memory of the agent working on Makco. Read it first.
It answers: who I am, what I am building, what is done, what is next, and where
everything lives.

---

## WHO I AM

Operating under the TANK protocol (see CONVENTIONS.md): an authoritative
engineering lead. Decisive, concise, plain text. I build, harden, and document.
I do not use markdown for the user-facing voice; files in the repo follow
normal repo conventions.

---

## WHAT I AM BUILDING

**Makco v3** — a multimodal Chennai transit app (bus + metro) at `/home/makco`.

Goal: replace the old metro-only Nim app with a fresh Rust backend and a new
unique UI. Same underlying MovingTech / Chennai One API, same auth + Juspay
payment model, but:
- transport focus broadened from metro-only to **bus + metro** (and hybrid)
- backend rewritten in **Rust (axum)** instead of Nim
- frontend: **both Flutter and Android Kotlin**, same new design language

### Design language (decided)
"Rail Signage / Data Terminal" — departure-board split-flaps, monospace,
high-contrast amber/black, real transit-board aesthetic. Non-standard, unique.

### Tech decisions (decided by user)
- Backend: Rust (axum + reqwest). NOT Nim.
- Frontend: Flutter AND Android Kotlin (both).
- Modes: Bus + Metro.
- Location: `/home/makco`.

---

## WHAT IS DONE

Backend (Rust) at `/home/makco/backend`:
- `Cargo.toml` — axum 0.7, reqwest (rustls), serde, tokio, tower-http CORS.
- `src/config.rs` — env config; vehicleType mapping BUS/BUS_HYBRID/METRO/METRO_V2.
- `src/api_client.rs` — MovingTech proxy client (mt_auth, stations, routes,
  activeRoutes, route stops, possibleStops, search, quote, confirm, status,
  ticket verify, profile, ticket bookings). Uses reqwest.
- `src/handlers.rs` — axum handlers, admin check (8190835624), token header
  validation, mode query param (`?mode=bus|metro`).
- `src/main.rs` — routes incl. `/transit/*` + legacy `/metro/*` aliases.
- Compiles clean (zero warnings). Boots and serves `/` = 200.

Flutter app at `/home/makco/frontend/flutter`:
- Rail Signage / Data Terminal UI (amber-on-black, split-flap boards).
- Theme in `lib/theme/terminal_theme.dart`; screens in `lib/screens/`.
- `flutter analyze` clean. APK builds (debug).

Android Kotlin app at `/home/makco/frontend/android`:
- Same design language, Jetpack Compose.
- `ui/theme/Terminal.kt` palette, `ui/components/TerminalComponents.kt` system.
- Screens: Auth, Home (bus/metro picker), Booking, Payment, History, Profile.
- `./gradlew assembleDebug` builds. Kotlin 2.0 + Compose compiler plugin.

Docs: `docs/API_REFERENCE.md`, `docs/DESIGN_LANGUAGE.md`, `docs/SETUP.md`.
Git repo initialized at `/home/makco`, initial commit on `main`.

### Real API facts extracted from Chennai One bundle (verified in decompiled_fresh)
- vehicle types: `BUS`, `BUS_HYBRID`, `METRO`, `METRO_V2`
- endpoints: `/frfs/stations`, `/frfs/routes`, `/frfs/activeRoutes`,
  `/frfs/route/{routeCode}/stops`, `/frfs/stations/possibleStops`,
  `/frfs/search`, `/frfs/search/{id}/quote`, `/frfs/quote/{id}/confirm`,
  `/frfs/booking/{id}/status`, `/frfs/ticket/verify`, `/profile`,
  `/ticket/bookings/v2`
- OTP is 4 digits. `vehicleType` must be JSON-encoded (`"METRO"`).
- Admin phone 8190835624 gets `isMockPayment=true`.

---

## WHAT IS NEXT (roadmap)

1. Push to GitHub — needs `gh auth login` (not currently logged in). Target:
   `pandatern/makco` (new repo or new branch) + CI workflows for Rust + Flutter.
2. End-to-end verification against live MovingTech API (needs a real OTP/token).
3. Deploy backend behind nginx (`api.pandatern.tech`) + systemd.
4. Optional: wire bus-mode specifics (active routes, route stops, possible stops)
   into the UI beyond the generic station picker.
5. Add scripts/test_api.py equivalent for the Rust backend.

---

## WHERE THINGS ARE

- New project root: `/home/makco`
- Rust backend: `/home/makco/backend`
  - build: `cd /home/makco/backend && cargo build`
  - run: `./target/debug/makco` (port 8080, health at `GET /`)
- Old repo (reference only, do not modify): `/srv/baymax/app/makco`
- Old decompiled Chennai One app (for endpoint discovery):
  `/srv/baymax/app/decompiled_fresh/assets/index.android.bundle`
- Conventions: `/home/makco/CONVENTIONS.md`, `/home/makco/AGENTS.md`
- Old AGENTS (Nim repo): `/home/makco/AGENTS_MAKCO.md`
- Old README: `/home/makco/README_OLD.md`

---

## CONSTRAINTS & GOTCHAS

- MovingTech upstream can send Content-Length mismatches (crashed old Nim
  backend on admin mockPayment). reqwest handles this; keep timeouts short.
- crates.io API is 403 from curl but static.crates.io works — cargo builds fine.
- `/home` is not writable by baymax directly; `/home/makco` is owned by baymax.
- OTP auth sends REAL SMS. Do not run scripts/test_api.py without consent.
- Never commit real secrets. Admin phone/UUID stays in code as-is (matches old repo).