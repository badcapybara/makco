# Makco v3 - API Reference

Makco is a multimodal Chennai transit booking backend (bus + metro). It proxies
the MovingTech / Chennai One API and adds validation, admin handling, and a
simpler REST surface. Built with Rust + axum.

## Base URL

- Local: `http://localhost:8080`
- Emulator: `http://10.0.2.2:8080`
- Production: `https://api.pandatern.tech`

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
| bus  | "BUS_HYBRID" |
| metro | "METRO_V2" |
| (any other) | "METRO" |

## Endpoints

### Health

```
GET /
```
```json
{"app":"Makco","modes":["bus","metro"],"status":"ok","version":"3.0.0"}
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
GET /transit/routes/active?city=chennai
GET /transit/route/{routeCode}/stops?city=chennai
GET /transit/stops/possible?city=chennai
```

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
Returns booking + Juspay payment order. Statuses: `NEW`, `PAYMENT_PENDING`,
`CONFIRMED`, `CANCELLED`.

### Ticket Verify

```
GET /transit/ticket/verify?city=chennai&mode=metro&ticketRef=<ref>
```

### User

```
GET /profile
GET /tickets?city=chennai&mode=metro
```

## Admin

Admin phone `8190835624` (env `ADMIN_PHONES`, comma-separated) triggers
`isMockPayment=true` on confirm → ticket issued without real payment.
Response includes `isAdmin: true`.

## Legacy aliases

For back-compat with v2 clients, these map to the same handlers (metro mode):

```
/metro/stations  /metro/routes  /metro/search  /metro/search/{id}/quote
/metro/quote/{id}/confirm  /booking/{id}/status  /booking/{id}/refresh
```

## Error codes

| Code | Meaning |
|------|---------|
| MISSING_HEADER | token header absent (401) |
| INVALID_OTP | otp not 4 digits |
| INVALID_PHONE | phone not 10 digits |
| INVALID_TOKEN | upstream token invalid |

## Notes

- `vehicleType` is JSON-encoded upstream (`"METRO"`), handled by the backend.
- CORS is permissive (mobile clients).
- Upstream MovingTech can return mismatched Content-Length; reqwest handles it
  (the old Nim backend crashed on this).
