# Design Language - Rail Signage / Data Terminal

Makco v3 abandons the previous neo-brutalist / Apple-premium themes for a
single, distinct design system: **Rail Signage / Data Terminal**.

## Concept

The app looks and feels like the physical transit infrastructure it books:
departure boards, split-flap displays, station signage, and operator consoles.
It is deliberately non-standard for a consumer app — no rounded cards, no
gradient hero screens, no playful icons. Everything reads like hardware.

## Palette

| Token | Hex | Use |
|-------|-----|-----|
| Black | `#0A0A0A` | App background |
| Panel | `#151515` | Cards/panels |
| PanelLift | `#1D1D1D` | Inputs, raised rows |
| Amber | `#FFB000` | Primary action, headings, departure flaps |
| Green | `#00E08A` | Success, live indicator, confirm |
| Red | `#FF4D4D` | Errors, cancel, terminate |
| Cyan | `#00E0E0` | Status labels, metadata |
| White | `#F2F2F2` | Body text |
| Dim | `#6E6E6E` | Secondary text |
| Hairline | `#2A2A2A` | Borders, dividers |

## Type

- Monospace everywhere (JetBrains Mono / system monospace).
- Uppercase labels with wide letter-spacing (1.5-2px).
- Big weights (Bold) for flap text and prices.
- No serif, no script.

## Components

### SplitFlap
The signature element. A dark cell with a top-half flap showing one character,
like a Solari departure board. Used for status values, prices, quantity.

### DepartureRow
Label (dim, 92px) + SplitFlap value, laid out like a station departure board
row (`ROUTE` / `TIME`).

### TerminalPanel
Square panel with hard 1px border and four L-shaped corner brackets. Replaces
rounded cards.

### SignHeader
Full-width amber bar with black monospace title — like the sign above a metro
entrance or platform.

### TermButton
Square, 2px border, filled amber or outline variant. No rounded corners.

### LiveIndicator
Green pulsing dot + label (`AUTH GATEWAY OPEN`, `CHENNAI`). Communicates that
data is live.

## Motion

Minimal. A splash that reveals `MAKCO` letters one flap at a time (like a
flip-board cycling), plus standard polling indicators. No spring physics, no
parallax.

## Voice

Labels are telegraphic and imperative: `REQUEST OTP`, `VERIFY & CONNECT`,
`TERMINATE SESSION`, `SELECT FROM + TO`. Errors use `!! PREFIX`.

## Files

- Flutter: `frontend/flutter/lib/theme/terminal_theme.dart` (+ components in screens)
- Android: `frontend/android/.../ui/components/TerminalComponents.kt`, palette in `ui/theme/Terminal.kt`