# Makco v3 - API Reference

Makco is a Chennai metro booking backend. It proxies the MovingTech / Chennai
One API and adds validation, payment isolation, real HTTP status codes, and a
simpler REST surface. Built with Rust + axum.

## Base URL

- Local: `http://localhost:8080`
- Emulator: `http://10.0.2.2:8080`
- Production: `http://163.123.236.154:8080` (direct server IP, no TLS yet)

## Auth

All transit endpoints require header:

```
token: <session-token>
```

Token is obtained via phone OTP flow (4-digit OTP).

## Modes

Pass `?mode=bus` or `?mode=metro` (default `metro`). Mode maps to the upstream
`vehicleType`:

| mode | vehicleType |
|------|-------------|
| bus  | "BUS" |
| metro | "METRO" |
| (any other / metro_v2) | "METRO" |

Note (2026-10): upstream now accepts only `METRO`, `SUBWAY`, `BUS`.
`METRO_V2` and `BUS_HYBRID` return HTTP 400.

## Endpoints

### Health

```
GET /
```
```json
{"app":"Makco","modes":["bus","metro"],"status":"ok","version":"3.3.0"}
```

### Auth

```
POST /auth
```
```json
{"mobileNumber":"9876543210","mobileCountryCode":"+91","merchantId":"NAMMA_YATRI","clientId":"NAMMA_YATRI"}
```
Returns `{authId, attempts, authType, ...}`.

```
POST /auth/{authId}/verify
```
```json
{"otp":"1234","deviceToken":"makco_device"}
```
Returns `{token, userId}`. OTP is 4 digits.

### Transit Data

```
GET /transit/stations?city=chennai&mode=metro
GET /transit/routes?city=chennai&mode=bus
GET /transit/routes/active?city=chennai&mode=metro
GET /transit/route/{routeCode}/stops?city=chennai&mode=metro
GET /transit/stops/possible?city=chennai&mode=metro
```

Re-verified against the live upstream (`api.moving.tech/pilot/app/v2`) on
2026-10-24:

- `stations` and `routes` work; Chennai returns 41 metro stations and 4 routes.
- `routes/active` works but upstream now **requires** `vehicleType` (the backend
  supplies it from `mode`).
- `stops/possible` and `route/{routeCode}/stops` now return 404 upstream.
- Bus modes return empty lists for Chennai (`BUS` is valid but has no data).

**Response shapes:** the proxy passes these upstream payloads through as bare
JSON arrays (`[...]`), not wrapped objects. That applies to `stations`, `routes`,
quotes and tickets. The Flutter `Api` client normalises arrays under `data`.

### Search / Quote / Booking

```
POST /transit/search?city=chennai&mode=metro
```
```json
{"fromStationCode":"SVA|0225","toStationCode":"SGM|0115","quantity":1}
```
Returns `{searchId, quotes:[]}`. Quotes generate asynchronously (2-3s).

```
GET /transit/search/{searchId}/quote?city=chennai&mode=metro
```
Returns array of quotes: `[{_type, quoteId, price, quantity, validTill, ...}]`.

```
POST /transit/quote/{quoteId}/confirm?city=chennai&mode=metro
```
```json
{"quantity":1}
```
Returns booking `{bookingId, status:"NEW", price, payment, ...}`.

```
GET /transit/booking/{bookingId}/status?city=chennai&mode=metro
GET /transit/booking/{bookingId}/refresh?city=chennai&mode=metro
```
Returns booking + Juspay payment order. Seen statuses: `NEW`, `APPROVED`,
`PAYMENT_PENDING`, `CONFIRMED`, `CANCELLED`. `APPROVED`/`PAYMENT_PENDING`
bookings have `tickets: []` until payment completes.

### Ticket Verify

```
POST /transit/ticket/verify?city=chennai&mode=metro
```
```json
{"qrData":"<signed qrData from the ticket>"}
```

Upstream `frfs/ticket/verify` parses the body as `{"qrData": ...}`; `vehicleType`
is a JSON-quoted value (`"METRO"`), which the client already emits.

### User

```
GET /profile
GET /tickets?city=chennai&mode=metro
```

`/tickets` proxies `GET frfs/booking/list?vehicleType="METRO"&limit=20&offset=0`
and returns a bare array of `FRFSTicketBookingStatusAPIRes` objects, newest
first. Each booking has `tickets[]`; the scannable payload is
`tickets[0].qrData` (never `bookingId`). Direct-BPP CMRL `qrData` is
`signature,ticketNumber,fromCode,toCode,adultQty,childQty,vehicleType,amount,otp,color,expiry,refreshAt,fleetNo,seatLabels`.
`/profile` returns the upstream profile object directly.

## Payment

Payment is universal: every account, including operator test numbers, goes
through Juspay. Confirm returns a booking whose `payment.paymentOrder` carries
the hosted payment link; the ticket and signed `qrData` are issued only after
upstream reports the payment as successful.

Makco no longer sends `isMockPayment`, does not detect admin accounts, and has
no payment bypass. A valid metro QR cannot be minted locally — `qrData` is
signed by the operator. Sandbox or mock payments may complete a booking in
non-production, but their QR is not gate-valid.

## Legacy aliases

For back-compat with v2 clients, these map to the same handlers (metro mode):

```
/metro/stations  /metro/routes  /metro/search  /metro/search/{id}/quote
/metro/quote/{id}/confirm  /booking/{id}/status  /booking/{id}/refresh
```

## Error codes

| Code | Meaning |
|------|---------|
| MISSING_HEADER | token header absent (HTTP 401) |
| INVALID_OTP | otp not 4 digits (HTTP 400) |
| INVALID_PHONE | phone not 10 digits (HTTP 400) |
| MISSING_STATIONS | search needs both station codes (HTTP 400) |
| INVALID_QUANTITY | quantity outside 1-6 (HTTP 400) |
| MISSING_QR | ticket verify needs qrData (HTTP 400) |
| INVALID_TOKEN | upstream token invalid (passed through with its upstream status) |
| *_FAILED | upstream call failed (HTTP 502) |

## Notes

- `vehicleType` is JSON-encoded upstream (`"METRO"`), handled by the backend.
- Errors use HTTP status codes: 400 validation, 401 auth, 502 upstream.
- CORS is permissive (mobile clients).
- Upstream MovingTech can return mismatched Content-Length; reqwest handles it
  (the old Nim backend crashed on this).
