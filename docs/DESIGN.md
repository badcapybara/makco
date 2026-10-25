# Design — "Madras Flow"

A fresh, warm, everyday design language for the Makco transit app.

Madras Flow is deliberately **not** a hacker/terminal theme. No black screens,
no monospace everywhere, no blinking dots. It is built for normal riders:
soft, legible, friendly — and still distinct. It takes its identity from
Chennai itself: auto-rickshaw amber, the green-blue of the sea and the metro,
warm paper, and the geometry of temple gopurams. Every screen reads like a
boarding pass you'd actually want to hold.

---

## 1. Design principles

1. **Warm, not dark.** Paper-cream backgrounds and soft surfaces. High
   contrast text in a deep warm ink, never pure black on pure white.
2. **Ticket logic.** The signature shape is the boarding pass / ticket stub —
   cards with a perforated edge. Everything you can book or pay for looks like
   a ticket. It feels physical and trustworthy.
3. **One accent story.** Amber is the action colour (book, pay, go). Teal is
   information (status, route, meta). Green is success. Red-coral is error.
   No rainbow.
4. **Friendly by default.** Human copy, generous spacing, big touch targets,
   calm motion. Errors apologise and offer a path forward.
5. **Local, not literal.** Chennai cues are abstracted (amber, gopuram steps,
   sea teal) — not clichés or clip-art.

---

## 2. Palette

Warm neutrals + one high-energy accent. Tokens are named for meaning, not colour.

| Token | Hex | Use |
|-------|-----|-----|
| Paper | `#FAF6EF` | App background (warm cream) |
| Surface | `#FFFFFF` | Cards, sheets |
| Surface Alt | `#F2EAE0` | Inputs, subtle fills |
| Ink | `#1E2A32` | Primary text (soft charcoal-navy) |
| Ink Muted | `#5B6B76` | Secondary text |
| Ink Faint | `#93A1AC` | Placeholders, disabled |
| Auto Amber | `#F2A93B` | Primary action, book/pay, highlights |
| Amber Press | `#D98E1F` | Amber pressed / contrast-safe on light |
| Sea Teal | `#12737E` | Status, route meta, information |
| Sea Teal Soft | `#E0F2F4` | Teal chip fill |
| Ticket Green | `#2E9E5B` | Success, confirmed, valid |
| Ticket Green Soft | `#E3F5E9` | Success chip fill |
| Coral | `#D95D39` | Error, cancel |
| Coral Soft | `#FBEAE4` | Error chip fill |
| Hairline | `#EADFD0` | Borders, dividers (warm) |

Dark variant ("Night Ride", optional): Paper `#12181C`, Surface `#1A2227`,
Ink `#EDF1F3`, Amber `#F2B24C`, Teal `#6FC6CE`. Use auto-switch via system
theme. Keep amber as the only saturated accent in both modes.

---

## 3. Typography

Two faces, one job: readable. Display face only for headings; body face for
everything else.

| Role | Face | Weight / Size | Notes |
|------|------|---------------|-------|
| Display (headings) | Bricolage Grotesque | 700, 28–40sp | Warm, characterful, still clean |
| Body / UI | Public Sans | 400–600, 14–16sp | Extremely legible on cream |
| Price numerals | Public Sans tabular | 700, 20–28sp | Tabular figures so fares line up |
| Overline / chip | Public Sans caps | 600, 11sp, +1 letter-spacing | Tiny labels: "ROUTE 1B", "CONFIRMED" |

Rules:
- Body min 14sp; never below 12sp for real content.
- Headings sentence-case, friendly: "Where are you headed?"
- Fares always right-aligned in tabular figures (₹45 lines up across a list).
- No monospace except QR codes themselves.

---

## 4. Shape & geometry

- **Radius:** generous. Cards 20dp, buttons pill (999dp), inputs 14dp.
- **Signature — ticket stub cards.** A card with a perforated edge: a row of
  small scallops or notches along the top edge, and a dashed vertical seam
  when the card holds a "stub" (e.g. fare + QR). Implement as a notch cutout
  on one edge (two semicircle cutouts, ticket-machine style).
- **Gopuram step** — a layered 3-step silhouette (like stacked temple tiers)
  used sparingly: behind the app wordmark, at the top of the search screen,
  or as a divider motif. Abstract, low-contrast (tint of Surface Alt), never
  as an icon of a temple.
- **Buttons:** pill, 52dp tall, amber fill with ink text for primary; teal
  tonal for secondary; ghost for tertiary. Always full-label, never icon-only
  without a label.
- **Bottom nav:** soft raised surface, rounded top corners, 3–5 labelled
  items, active item in amber pill with icon+label, inactive in muted ink.

---

## 5. Components

### TicketCard (signature)
The core booking/result unit. Fields: route line (origin → destination),
fare (tabular, bold), status chip, QR placeholder. Notched top edge.
Used for: quotes, bookings, history items, and the issued ticket.

### RouteRow
Origin / destination with a connecting line and a duration/ETA chip.
Friendly: "Vadapalani → Airport" with a small teal "34 min" chip.

### StatusChip
Soft-filled pill: teal for PENDING / PROGRESS, green for CONFIRMED / VALID,
coral for CANCELLED / EXPIRED. Chip text in the matching dark shade.

### PrimaryButton / SecondaryButton / GhostButton
Pill, 52dp. Primary amber; secondary teal tonal; ghost outline hairline.
Pressed states darken (Amber Press). Disabled = Ink Faint at 50%.

### FareTag
Large tabular price with a thin "INR" prefix, e.g. `₹45`.

### InputField
Filled soft field (Surface Alt), rounded 14dp, floating hint, amber focus
ring. Country-code phone input for OTP stays as two adjacent fields.

### BottomNav
Raised pill-bar floating above content. Active tab gets an amber pill behind
icon+label.

### Loading
A friendly skeleton: grey shimmer bars shaped like the next card. No
"SYSTEM INITIALIZING…", no spinners with technical labels. Text like
"Fetching fares…".

### Empty / Error states
Illustrated (simple line art: auto, metro, ticket). Empty: "No trips yet —
book your first ride." Error: "Something went wrong getting fares."
Retry is always a visible primary button.

---

## 6. Motion

- Calm, spring-based (low overshoot). 200–300ms for screens, 150ms for
  micro-interactions.
- Screen transitions: 8dp slide-up + fade (like a ticket sliding out).
- Payment confirmation: the ticket card gently "stamps" (a short scale
  settle) when status flips to CONFIRMED.
- Pull-to-refresh: springy, standard.
- No mechanical flaps, no blinking, no scanline effects.

---

## 7. Voice & tone

Plain, warm, direct. Talks to the rider like a helpful conductor.

| Before (terminal) | After (Madras Flow) |
|-------------------|---------------------|
| REQUEST OTP | "Send me the code" |
| VERIFY & CONNECT | "Verify & continue" |
| SELECT FROM + TO | "Pick your start and stop" |
| PAYMENT PENDING | "Waiting for payment…" |
| !! CONFIRM FAILED | "Couldn't confirm — please try again" |
| NO BOOKINGS ON RECORD | "No trips yet. Your bookings will appear here." |

- Sentence case. No ALL-CAPS except the tiny overline labels.
- Errors name the problem and give the next step.
- Numbers localised with ₹ and 12/24h as user preference.

---

## 8. Accessibility

- All text AA (4.5:1) on Paper/Surface. Amber `#F2A93B` only used for large
  text, fills, or icons — body text on amber uses Ink, not white.
- Touch targets min 48×48dp (buttons 52dp).
- Focus states: 2dp amber ring on keyboard/focus.
- Both light and "Night Ride" dark mode pass contrast.
- Tabular numerals for fares prevent misreads.
- Notifications/labels always accompany colour alone (chips include text).

---

## 9. Files

- Spec: `docs/DESIGN.md` (this file).
- Token source: a single file per platform at rebuild time
  (e.g. `lib/theme/madras_flow.dart` / `theme/MadrasFlow.kt`).
- Components: one file per component, matching the token names above.
- The previous "Rail Signage / Data Terminal" design is retired.


---

## Booking surface (v3.1)

The app is built around **one screen**, not a wizard:

1. Home opens with a greeting, a ticket-stub card holding `FROM` / `TO`, and a
   ticket-count stepper.
2. Tapping either row opens a searchable station sheet. Choosing the second
   station immediately fetches live fares; there is no "continue" step.
3. Fare cards show the total and a single `Pay ₹N` action. Payment opens the
   Juspay WebView; success replaces it with the ticket.
4. The same screen shows saved recent trips for one-tap repeat and the latest
   tickets; the Tickets tab holds filters and full history.
5. The ticket is a warm paper stub with a real QR, ticket ref and valid-till
   time — the same `TicketCard` language as the rest of the app.

No bus toggle, no decorative station/route lists, no dead ends.
