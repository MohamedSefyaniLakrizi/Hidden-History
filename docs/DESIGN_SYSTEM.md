# Hidden History — Design System

> **For agents**: This document is the single source of truth for all visual design decisions.
> When implementing any SwiftUI view, consult this document first. Never hardcode colors,
> fonts, or spacing values — always reference the token namespaces defined here.

---

## Brand Identity

| Attribute | Value |
|-----------|-------|
| App name | Hidden History |
| Tagline | "Stories beneath your feet" |
| Tone | Curious, knowledgeable, slightly mysterious, accessible |
| Aesthetic | Clean flat 2D — no glassmorphism, no skeuomorphism, no gradients |
| Inspiration | PostHog, Datafast — strong typography, purposeful color use |

### Personality
The app is like a knowledgeable local friend who knows all the forgotten stories of a city.
Not an academic textbook. Not a tourist trap. A secret guide that makes you see familiar
streets differently.

---

## Logo & App Icon

### Primary Logo Mark
A geometric map pin with a simplified compass rose inside the pin's circle.
- The pin outline is Deep Slate (`#1B3A52`)
- The inner compass detail is Warm Amber (`#D97B3C`)
- Flat, no shadows, 2pt stroke weight
- The compass has 4 cardinal points — N is slightly elongated

### App Icon
- Background: Deep Slate `#1B3A52` (solid, no gradient)
- Foreground: The pin/compass mark in Warm Amber `#D97B3C`
- Padding: Standard iOS icon safe zone (~10% inset)
- Style: Flat 2D, no depth, no glow

### Wordmark
- Font: Inter Bold
- Tracking: +20 letter-spacing
- "HIDDEN" — Deep Slate
- "HISTORY" — Warm Amber
- Displayed on a single line separated by a thin vertical divider

---

## Color System

All colors are defined in `Core/DesignSystem/Colors.swift` under the `HHColors` namespace.
**Never use hex literals in view code** — always reference `HHColors.*`.

### Brand Colors

| Token | Light Hex | Dark Hex | Usage |
|-------|-----------|----------|-------|
| `HHColors.primary` | `#1B3A52` | `#1B3A52` | Headings, nav active, logo |
| `HHColors.accent` | `#D97B3C` | `#E8894A` | CTAs, map pins, play buttons, selected state |
| `HHColors.secondary` | `#4A7C59` | `#5A9169` | Visited pins, completed states, success adjacent |
| `HHColors.cluster` | `#6B5B95` | `#7B6BA5` | Map cluster pins |

### Background Colors

| Token | Light Hex | Dark Hex | Usage |
|-------|-----------|----------|-------|
| `HHColors.backgroundPrimary` | `#FFFFFF` | `#0F1419` | Main app background |
| `HHColors.backgroundSecondary` | `#F8F7F5` | `#1A2332` | Card surfaces, sheet backgrounds |
| `HHColors.backgroundTertiary` | `#EFE9E0` | `#242E3F` | Subtle separators, input backgrounds |

### Text Colors

| Token | Light Hex | Dark Hex | Usage |
|-------|-----------|----------|-------|
| `HHColors.textPrimary` | `#1B3A52` | `#F5F3F0` | Headings, primary labels |
| `HHColors.textSecondary` | `#4A5568` | `#C5BFBA` | Body text, descriptions |
| `HHColors.textTertiary` | `#8A94A4` | `#8A8177` | Captions, timestamps, placeholders |
| `HHColors.textDisabled` | `#B8BFCC` | `#5A5550` | Disabled elements |

### Status Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `HHColors.success` | `#2D9E6F` | Confirmation, completed downloads |
| `HHColors.warning` | `#E8A725` | Rate limit approaching, soft warnings |
| `HHColors.error` | `#C85250` | Auth errors, network failures |
| `HHColors.info` | `#4B8AC7` | Informational banners |

### Map-Specific Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `HHColors.mapPinUnvisited` | `#D97B3C` | Default historical site pin |
| `HHColors.mapPinVisited` | `#4A7C59` | Site user has visited/listened to |
| `HHColors.mapPinUserLocation` | `#1B3A52` | Current user position |
| `HHColors.mapPinCluster` | `#6B5B95` | Clustered group of sites |

### Dividers & Borders

| Token | Light Hex | Dark Hex |
|-------|-----------|----------|
| `HHColors.divider` | `#E0D9D0` | `#3A4557` |
| `HHColors.border` | `#D4CCC2` | `#2E3B4E` |

---

## Swift Color Tokens

```swift
// Core/DesignSystem/Colors.swift

import SwiftUI

enum HHColors {
    // MARK: — Brand
    static let primary       = Color(hex: "1B3A52")
    static let accent        = Color(hex: "D97B3C")
    static let secondary     = Color(hex: "4A7C59")
    static let cluster       = Color(hex: "6B5B95")

    // MARK: — Adaptive Backgrounds
    static let backgroundPrimary = Color("BackgroundPrimary")      // Asset catalog adaptive
    static let backgroundSecondary = Color("BackgroundSecondary")
    static let backgroundTertiary = Color("BackgroundTertiary")

    // MARK: — Adaptive Text
    static let textPrimary    = Color("TextPrimary")
    static let textSecondary  = Color("TextSecondary")
    static let textTertiary   = Color("TextTertiary")
    static let textDisabled   = Color("TextDisabled")

    // MARK: — Status
    static let success = Color(hex: "2D9E6F")
    static let warning = Color(hex: "E8A725")
    static let error   = Color(hex: "C85250")
    static let info    = Color(hex: "4B8AC7")

    // MARK: — Map
    static let mapPinUnvisited   = accent
    static let mapPinVisited     = secondary
    static let mapPinUserLocation = primary
    static let mapPinCluster     = cluster

    // MARK: — Dividers
    static let divider = Color("Divider")
    static let border  = Color("Border")
}

// Helper: initialise Color from hex string
private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
```

> Adaptive colors (background, text, dividers) are defined in `Assets.xcassets` with
> separate light/dark appearances to support dark mode automatically.

---

## Typography

All type styles are defined in `Core/DesignSystem/Typography.swift` under `HHTypography`.
**Never hardcode font names or sizes in view code.**

### Font Families

| Role | Font | Source |
|------|------|--------|
| Display & Headings | Inter (Bold, SemiBold) | Swift Package: `swift-package-inter` or bundled TTF |
| Body & UI | SF Pro Text | iOS system font (automatic) |
| Monospace (coords, dates) | SF Mono | iOS system font (`.monospaced` design) |

### Type Scale

| Token | Font | Size | Weight | Line Height | Usage |
|-------|------|------|--------|-------------|-------|
| `displayLarge` | Inter | 32pt | Bold | 1.2× | App title, hero screens |
| `displaySmall` | Inter | 24pt | SemiBold | 1.2× | Section headings |
| `headline` | Inter | 18pt | SemiBold | 1.3× | Card titles, modal titles |
| `title` | Inter | 16pt | Medium | 1.3× | Significant UI labels |
| `bodyLarge` | SF Pro Text | 16pt | Regular | 1.6× | Primary reading content |
| `body` | SF Pro Text | 14pt | Regular | 1.6× | Secondary content |
| `caption` | SF Pro Text | 12pt | Regular | 1.4× | Timestamps, metadata |
| `label` | SF Pro Text | 12pt | Medium | 1.4× | Chips, tags, badges |
| `mono` | SF Mono | 12pt | Regular | 1.4× | Coordinates, years, IDs |

### Swift Typography Tokens

```swift
// Core/DesignSystem/Typography.swift

import SwiftUI

enum HHTypography {
    static let displayLarge  = Font.custom("Inter-Bold",      size: 32)
    static let displaySmall  = Font.custom("Inter-SemiBold",  size: 24)
    static let headline      = Font.custom("Inter-SemiBold",  size: 18)
    static let title         = Font.custom("Inter-Medium",    size: 16)
    static let bodyLarge     = Font.system(size: 16, weight: .regular, design: .default)
    static let body          = Font.system(size: 14, weight: .regular, design: .default)
    static let caption       = Font.system(size: 12, weight: .regular, design: .default)
    static let label         = Font.system(size: 12, weight: .medium,  design: .default)
    static let mono          = Font.system(size: 12, weight: .regular, design: .monospaced)
}
```

---

## Spacing & Layout

```swift
// Core/DesignSystem/Spacing.swift

import CoreGraphics

enum HHSpacing {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64

    // Screen edge padding
    static let screenEdge: CGFloat = 16

    // Minimum touch target (accessibility)
    static let minTouchTarget: CGFloat = 44
}

enum HHRadius {
    static let xs:   CGFloat = 4
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 24
    static let pill: CGFloat = 9999   // fully rounded
}
```

---

## Component Specifications

### Map Pins

**Unvisited Site Pin** (default)
- Shape: Classic teardrop pin
- Fill: `HHColors.accent` (`#D97B3C`)
- Stroke: 1.5pt `HHColors.primary`
- Inner icon: Small compass/star at 12pt, white
- Size: 36×44pt (normal), 48×58pt (selected/active)
- Selected animation: scale up 1.0→1.15 with spring easing

**Visited Site Pin**
- Fill: `HHColors.secondary` (`#4A7C59`)
- Inner icon: Checkmark, white, 10pt
- Same dimensions as unvisited

**User Location Pin**
- Shape: Circle, no point
- Fill: `HHColors.primary`
- Stroke: 3pt `HHColors.accent`, animates pulse (1.0→1.3 scale, 1.5s loop, fades)
- Size: 32pt diameter

**Cluster Pin**
- Shape: Circle
- Fill: `HHColors.cluster`
- Text: Site count, white, `HHTypography.label`
- Size: 36pt + 2pt per additional count, max 52pt

---

### Audio Player Bar

A persistent bottom sheet that appears when a site is selected.

**Collapsed State** (height: 72pt + safe area)
- Background: `HHColors.backgroundSecondary`
- Top border: 1pt `HHColors.divider`
- Top corners: 16pt radius
- Layout (horizontal):
  - Site thumbnail (40×40pt, 8pt radius): left
  - Site name (truncated, `HHTypography.title`): center
  - Progress line (2pt, `HHColors.accent`): bottom of bar, full width
  - Play/Pause button (44pt circle, `HHColors.accent` fill, white icon): right

**Expanded State** (full screen modal, sheet presentation)
- Background: `HHColors.backgroundPrimary`
- Hero image: full width, 280pt height, no radius (bleeds to edges)
- Content padding: `HHSpacing.md` horizontal
- Site name: `HHTypography.displaySmall`, `HHColors.textPrimary`
- Narrator credit: `HHTypography.body`, `HHColors.textTertiary`
- Time display: `HHTypography.mono`, `HHColors.textSecondary`
- Progress bar:
  - Track: 4pt height, `HHColors.backgroundTertiary`
  - Fill: `HHColors.accent`
  - Thumb: 14pt circle, `HHColors.accent`
- Controls:
  - Skip back 15s: 52pt touch target, icon only
  - Play/Pause: 64pt circle, `HHColors.accent` fill, white icon (24pt)
  - Skip forward 15s: 52pt touch target, icon only
- Speed selector: `0.75×  1×  1.25×  1.5×  2×` — pill button group, active fills `HHColors.accent`
- Share + Download icons: top right, 44pt touch targets

---

### Place Card

**Compact (list / map bottom sheet)**
- Background: `HHColors.backgroundSecondary`
- Corner radius: `HHRadius.md` (12pt)
- Padding: `HHSpacing.md`
- Height: 120pt
- Layout:
  - Left: thumbnail image 80×80pt, `HHRadius.sm`, object-fit cover
  - Right column:
    - Category chip (see below): top
    - Site name: `HHTypography.headline`, `HHColors.textPrimary`, max 2 lines
    - Distance + era: `HHTypography.caption`, `HHColors.textTertiary`
    - Short bio snippet: `HHTypography.body`, `HHColors.textSecondary`, 1 line truncated
- Tap: scale 0.98 spring feedback, navigates to SiteDetailView

**Expanded (SiteDetailView)**
- Full-screen push navigation
- Hero image: full width, 240pt, no corner radius (edge to edge)
- Content below: vertical scroll
  - Category chip row (horizontal scroll)
  - Site name: `HHTypography.displayLarge`
  - Metadata row: Distance · Audio duration · Era/period (mono font, tertiary color)
  - Description: `HHTypography.bodyLarge`, line height 1.6
  - Mini map: 160pt height, rounded 12pt, shows pin at site location
  - Related sites carousel: horizontal scroll of compact cards
- Sticky bottom bar: "Listen" button — full width, 56pt height, `HHColors.accent` fill, "Listen" in `HHTypography.headline` white

---

### Category Chips / Tags

- Height: 30pt
- Padding: 10pt horizontal, 6pt vertical
- Font: `HHTypography.label`
- Corner radius: `HHRadius.sm` (8pt)
- **Default state**: 1pt border `HHColors.border`, transparent fill, text `HHColors.textSecondary`
- **Selected state**: `HHColors.accent` fill, white text, no border
- **Disabled state**: `HHColors.backgroundTertiary` fill, `HHColors.textDisabled` text

Category colour accents (border/icon tint in default state only):

| Category | Accent |
|----------|--------|
| Architecture | `HHColors.primary` |
| Cultural Heritage | `HHColors.accent` |
| Natural History | `HHColors.secondary` |
| Industrial Past | `#9B8679` (Warm Taupe) |
| Social History | `#5C2E3A` (Deep Burgundy) |
| Military & Conflict | `#4A5568` (Slate) |

---

### Bottom Navigation

- 4 tabs: **Discover** · **Map** · **Saved** · **Profile**
- Height: 56pt + safe area inset
- Background: `HHColors.backgroundPrimary`
- Top border: 1pt `HHColors.divider`
- Active tab: icon + label in `HHColors.accent`
- Inactive tab: icon + label in `HHColors.textTertiary`
- Icons: 24pt, 2pt stroke, rounded line caps
- Labels: `HHTypography.caption` (11pt effective)
- Transition animation: icon scale 1.0→1.1 + color crossfade (0.2s ease)

---

### Buttons

**Primary Button** (main CTAs — "Listen", "Subscribe", "Get Started")
- Height: 56pt
- Background: `HHColors.accent`
- Text: `HHTypography.headline`, white
- Corner radius: `HHRadius.md` (12pt)
- Full width by default
- Pressed state: 0.94 opacity + 0.97 scale

**Secondary Button** (e.g. "Skip", "Maybe Later")
- Height: 48pt
- Background: transparent
- Border: 1.5pt `HHColors.border`
- Text: `HHTypography.title`, `HHColors.textSecondary`
- Corner radius: `HHRadius.md`

**Icon Button** (floating actions, toolbar items)
- Touch target: 44pt minimum
- Background: transparent (or `HHColors.backgroundSecondary` for contextual buttons)
- Icon: 22pt, `HHColors.textSecondary` (inactive) / `HHColors.accent` (active)

---

### Text Input / Search Bar

- Height: 44pt
- Background: `HHColors.backgroundTertiary`
- Corner radius: `HHRadius.md`
- Padding: 12pt horizontal
- Font: `HHTypography.body`
- Placeholder color: `HHColors.textTertiary`
- Focus ring: 1.5pt `HHColors.accent`
- Leading icon: search icon 18pt `HHColors.textTertiary`

---

## Icon System

All icons use a **2pt stroke weight** with **rounded line caps and joins**, at a **24×24pt** base grid.

Source: Use [SF Symbols 5](https://developer.apple.com/sf-symbols/) as the primary icon library.
Custom icons (map pins, audio waveform) are built as SwiftUI `Shape` implementations.

| Icon | SF Symbol | Usage |
|------|-----------|-------|
| Discover | `mappin.and.ellipse` | Tab bar |
| Map | `map` | Tab bar |
| Saved | `bookmark` | Tab bar |
| Profile | `person.circle` | Tab bar |
| Play | `play.fill` | Audio player |
| Pause | `pause.fill` | Audio player |
| Skip back | `gobackward.15` | Audio player |
| Skip forward | `goforward.15` | Audio player |
| Share | `square.and.arrow.up` | Site detail |
| Download | `arrow.down.circle` | Premium offline |
| Filter | `line.3.horizontal.decrease.circle` | Map/list |
| Search | `magnifyingglass` | Search bar |
| Close | `xmark` | Modals |
| Chevron | `chevron.right` | Navigation |
| Audio wave | Custom `AudioWaveShape` | Player animation |

---

## Motion & Animation

- **Default transition**: `.spring(response: 0.35, dampingFraction: 0.75)`
- **Fade in/out**: `.easeInOut(duration: 0.2)`
- **Sheet presentation**: `.easeInOut(duration: 0.3)`
- **Map pin selection scale**: spring, response 0.25, dampingFraction 0.6
- **Audio waveform**: continuous sine-wave animation while playing (AVAudioPlayer metering)
- **Page swipe (onboarding)**: `.interactiveSpring(response: 0.4, dampingFraction: 0.85)`

Principle: Animations are **functional** (indicate state change) or **delightful** (reward
interaction). Never purely decorative or blocking.

---

## Accessibility

- All interactive elements: minimum 44×44pt touch target
- All text uses Dynamic Type — scale with `HHTypography` tokens using relative sizing where possible
- Contrast ratios: minimum 4.5:1 for body text, 3:1 for large headings (WCAG AA)
- Every image/icon has an `accessibilityLabel`
- Audio player controls have full VoiceOver support with `accessibilityHint`
- Map pins announce site name + distance via `accessibilityLabel`
- Reduce Motion: respect `@Environment(\.accessibilityReduceMotion)` — replace spring animations with instant transitions

---

## Dark Mode

Dark mode is supported from day 1. Adaptive colors are defined in `Assets.xcassets` with
Appearance = Any/Dark. The `HHColors` namespace references these automatically.

The map uses MapKit's built-in `.dark` color scheme when `colorScheme == .dark`.

All component specs above list both light and dark hex values where they differ.
