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

**Makco v3** — a Chennai metro booking app at `/home/makco`: a Rust BFF plus a
Flutter Android app using the "Madras Flow" design language.

Goal: replace the old Nim app with a Rust backend and a fast, modern Flutter
client on top of the MovingTech / Chennai One API. Metro-first: upstream still
accepts `BUS`/`SUBWAY`, but Chennai bus data is empty, so the app exposes Metro
only until that changes.

### Tech decisions
- Backend: Rust (axum + reqwest), not Nim.
- Frontend: Flutter, org `com.pandatern.makco`, Riverpod 3 + go_router.
- Design: "Madras Flow" (`docs/DESIGN.md`) — warm, rider-friendly, ticket logic.
- Scope: Chennai Metro now; bus held behind the backend for later.
- Location: `/home/makco`.

---

## WHAT IS DONE

Backend (Rust) at `/home/makco/backend`:
- `src/config.rs` — mode→vehicleType mapping: metro→`METRO`, bus→`BUS`.
- `src/api_client.rs` — MovingTech proxy (auth, stations, routes, activeRoutes,
  route stops, possible stops, search, quote, confirm, status, ticket verify,
  profile, ticket bookings). Mode-aware.
- `src/handlers.rs` — token validation, mode query, and a thin upstream proxy.
  Payment is universal; no admin detection or mock-payment bypass. Errors return
  real HTTP status codes (400 validation, 401 missing token, 502 upstream).
- `src/main.rs` — `/transit/*` routes plus legacy `/metro/*` aliases.
- Release binary `backend/target/release/makco`, run by `makco.service` on
  `:8080` (enabled, auto-restart). Verified live at `http://163.123.236.154:8080`.

Frontend (Flutter) at `/home/makco/frontend/flutter`, v3.3.0+330:
- **One-screen booking**: From/To station sheets, quantity, auto fare fetch,
  one-tap repeat from saved recent trips. No booking wizard.
- **State**: Riverpod providers for session, stations, tickets, recents and the
  ride controller (`lib/state/`).
- **Routing**: go_router with `/splash`, `/auth`, `/home`, `/ticket`, `/payment`;
  `makco://app/ticket?ref=...` deep link.
- **Tickets**: real scannable QR from the operator's `qrData` (`qr_flutter`),
  ticket number, valid-till, polling for fresh bookings, shared `TicketTile`
  across Home and Tickets. `/tickets` now lists bookings via
  `frfs/booking/list`; booking-level `stations[]` supplies from/to names.
- **Tickets tab**: All / Active / Past filters, pull-to-refresh, tap for ticket.
- **Auth**: 10-digit phone, 4-digit OTP with autofill, auto-submit, resend timer.
  Token/user id live in encrypted storage; old plain-preference values migrate.
- **Offline**: last stations and tickets are cached; providers fall back when the
  network fails. Tickets cache is cleared on sign-out.
- **Stations**: 41 metro stations, search, favourites (star + filter) and a
  "Near me" sort using device location; no bus UI.
- **Fonts**: Bricolage Grotesque and Public Sans are bundled assets, no runtime
  fetch and no first-launch font flash.
- **Profile**: session-backed, server/version info, sign-out.
- `Api` normalises bare JSON arrays from upstream (`stations`, `routes`, quotes,
  tickets) under `data`, so all list endpoints decode consistently.
- Tests: `test/app_smoke_test.dart` covers the auth boot, router, Home, station
  picker, favourites filter and QR ticket. `flutter analyze` clean.
- Release APK signed with `android/makco-release.jks` (alias `makco`), served at
  `http://163.123.236.154/app-release.apk` from `/var/www/makco`.

### Real API facts (re-verified live, 2026-10-24)
- vehicle types accepted now: `METRO`, `SUBWAY`, `BUS`. `METRO_V2` and
  `BUS_HYBRID` return 400.
- `/frfs/activeRoutes` now requires `vehicleType`.
- `/frfs/route/{code}/stops` and `/frfs/stations/possibleStops` return 404.
- Chennai: 41 metro stations, 4 routes (BLUE_UP/DOWN, GREEN_*). BUS is empty.
- OTP is 4 digits. Merchant/client that works: `NAMMA_YATRI`.
- Payment is required for every account. A booking only gets a signed `qrData`
  after Juspay reports success; there is no mock or admin shortcut.

---

## WHAT IS NEXT (roadmap)

1. **End-to-end payment test** with any account (search → quote → confirm →
   Juspay page → status `CONFIRMED` → ticket). Payment is universal; admin
   bypasses have been removed. Blocked while live quotes are empty and until a
   real ticket is funded.
2. **Real CMRL gate scan** of a freshly issued QR.
3. HTTPS for the API; raw IP HTTP remains for now (no trusted cert for an IP).
4. Bus is deliberately out of scope until upstream returns Chennai data.

---

## WHERE THINGS ARE

- Project root: `/home/makco`
- Rust backend: `/home/makco/backend`
  - build: `cd /home/makco/backend && cargo build --release`
  - run: `/home/makco/backend/target/release/makco` (port 8080, `GET /` health)
  - service: `/etc/systemd/system/makco.service`
- Flutter app: `/home/makco/frontend/flutter`
  - SDK: `/opt/flutter`; Android SDK: `/opt/android-sdk` (platform 36)
  - build: `cd /home/makco/frontend/flutter && flutter build apk --release`
  - output: `build/app/outputs/flutter-apk/app-release.apk`
  - tests: `flutter test`
- nginx: `/etc/nginx/sites-available/makco_ip` serves `/var/www/makco`
- Design spec: `/home/makco/docs/DESIGN.md`
- Bundled fonts/licenses: `/home/makco/frontend/flutter/assets/fonts`
- Offline cache: `lib/services/cache.dart`
- Favourites: `lib/state/favourites.dart`
- Location helper: `lib/services/location.dart`
- CI: `/home/makco/.github/workflows/ci.yml`
- Old repo (reference only): `/srv/baymax/app/makco`
- Old decompiled Chennai One app: `/srv/baymax/app/decompiled_fresh/assets/index.android.bundle`
- Conventions: `/home/makco/CONVENTIONS.md`, `/home/makco/AGENTS.md`
