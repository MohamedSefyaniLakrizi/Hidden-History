# Hidden History — Onboarding & Analytics

> **For agents**: This document defines the complete onboarding flow screen-by-screen,
> every PostHog event with its exact property schema, and all feature flags.
> When implementing any onboarding screen or analytics call, use this as the spec.

---

## PostHog Setup

```swift
// App/HiddenHistoryApp.swift — initialise once at launch

import PostHog
import SwiftUI

@main
struct HiddenHistoryApp: App {
    init() {
        let config = PostHogConfig(
            apiKey: Config.postHogApiKey,   // from Config.xcconfig
            host: "https://app.posthog.com"
        )
        config.captureApplicationLifecycleEvents = true  // auto: app_opened, etc.
        config.captureScreenViews = false                // we fire manual screen events
        config.sessionRecording = false                  // enable in Phase 3 if needed
        PostHogSDK.shared.setup(config)
    }

    var body: some Scene {
        WindowGroup { RootView() }
    }
}
```

### Identifying Users

```swift
// After sign-up / sign-in
PostHogSDK.shared.identify(
    userId,
    userProperties: [
        "email": user.email ?? "",
        "signup_method": "apple",     // or "email"
        "plan": "free"                // updated to "premium" on subscription
    ]
)

// On subscription
PostHogSDK.shared.capture("subscription_started", properties: [...])
PostHogSDK.shared.identify(userId, userProperties: ["plan": "premium"])
```

### Resetting on Sign-Out

```swift
PostHogSDK.shared.reset()
```

---

## Onboarding Flow

The onboarding is a one-time flow shown on first launch. It is gated by a
`hasCompletedOnboarding` flag in Supabase user metadata and local `UserDefaults`.

### Screen 1 — Splash / Brand Intro

**Purpose**: First impression, brand moment, 2-second auto-advance.

**UI**:
- Full-screen `HHColors.primary` (`#1B3A52`) background
- Centred app icon (72pt)
- App name wordmark below (Inter Bold, 28pt, white)
- Tagline "Stories beneath your feet" (SF Pro, 14pt, 60% white opacity)
- Subtle fade-in animation (0.4s) then auto-advances after 2s

**Analytics**:
```swift
PostHogSDK.shared.capture("onboarding_splash_viewed")
```

---

### Screen 2 — Value Proposition (3-card swipe)

**Purpose**: Explain the core value before asking for permissions or sign-up.

**UI**:
- Horizontal swipe carousel, 3 cards, page indicator dots
- Each card: full-screen illustration area (top 60%) + headline + body text (bottom 40%)
- Background: `HHColors.backgroundPrimary`
- Headline: `HHTypography.displaySmall`, `HHColors.textPrimary`
- Body: `HHTypography.bodyLarge`, `HHColors.textSecondary`
- CTA on last card: "Get Started" (Primary Button) + "I already have an account" (text link)
- Skip button top-right (from card 1 onward)

**Card Content**:

| Card | Illustration | Headline | Body |
|------|-------------|----------|------|
| 1 | Map with amber pins radiating outward | "Your city has secrets" | "Discover the forgotten stories behind buildings, monuments, and streets you walk past every day." |
| 2 | Headphones with audio waveform | "Listen, don't just look" | "Expert narrations bring history to life. Put your headphones in and let the stories find you." |
| 3 | Timeline from ancient to modern | "Five thousand years in your pocket" | "From Roman ruins to Victorian factories — Hidden History spans every era." |

**Analytics**:
```swift
// Fired when each card is viewed (by swipe or first load)
PostHogSDK.shared.capture("onboarding_value_prop_viewed", properties: [
    "card_index": 0,   // 0, 1, or 2
    "method": "swipe"  // or "auto" for first card
])

// Fired if user taps Skip
PostHogSDK.shared.capture("onboarding_value_prop_skipped", properties: [
    "at_card_index": 1
])
```

---

### Screen 3 — Location Permission

**Purpose**: Request `CoreLocation` permission with clear context before the iOS prompt.

**UI**:
- Illustration: stylised location pin with a city map behind it
- Headline: "Find history near you"
- Body: "Hidden History uses your location to surface stories within walking distance. We never store or share your location."
- Primary Button: "Allow Location Access" → triggers `CLLocationManager.requestWhenInUseAuthorization()`
- Secondary link: "Not Now" → proceeds without location (limited experience)

**Analytics**:
```swift
PostHogSDK.shared.capture("location_permission_screen_viewed")

// After iOS prompt resolves
PostHogSDK.shared.capture("location_permission_result", properties: [
    "granted": true,           // or false
    "status": "whenInUse"      // or "denied", "restricted"
])
```

---

### Screen 4 — Notification Permission

**Purpose**: Request push notifications for "nearby history" alerts. Shown only if location was granted.

**UI**:
- Illustration: a notification bubble with a historical site pin
- Headline: "Never miss a story"
- Body: "We'll nudge you when something remarkable happened near where you're standing."
- Primary Button: "Turn On Notifications" → triggers `UNUserNotificationCenter.requestAuthorization`
- Secondary link: "Skip for Now"

**Analytics**:
```swift
PostHogSDK.shared.capture("notification_permission_screen_viewed")

PostHogSDK.shared.capture("notification_permission_result", properties: [
    "granted": true    // or false
])
```

---

### Screen 5 — Sign Up / Sign In

**Purpose**: Create an account to persist history, bookmarks, and subscription.

**UI**:
- Headline: "Create your account"
- Subhead: "Save your discoveries and sync across devices."
- Apple Sign In button (full width, standard Apple styling — required by App Store guidelines)
- Divider "or"
- Email field + "Continue with email" button → sends magic link
- Footer: "Already have an account? Sign in" (tap to switch mode)
- Privacy policy + Terms links at bottom

**Analytics**:
```swift
PostHogSDK.shared.capture("signup_screen_viewed")

PostHogSDK.shared.capture("signup_method_selected", properties: [
    "method": "apple"   // or "email"
])

PostHogSDK.shared.capture("signup_completed", properties: [
    "method": "apple",
    "is_new_user": true
])

// If user already had account and signed in instead
PostHogSDK.shared.capture("signin_completed", properties: [
    "method": "apple"
])
```

---

### Screen 6 — Interest Tags

**Purpose**: Personalise the initial map view. Which eras/categories does the user care about?

**UI**:
- Headline: "What are you curious about?"
- Subhead: "We'll highlight the stories that matter to you."
- Era chips (multi-select): Prehistoric · Roman · Medieval · Tudor · Georgian · Victorian · WWII · Modern
- Category chips (multi-select): Architecture · Battles & Wars · Cultural Life · Industrial · Royalty & Politics · Crime & Punishment · Science & Discovery
- "Feeling lucky" button (random selection) for users who don't want to choose
- Primary Button: "Let's go" (enabled immediately, even with zero selections — defaults to all)

**Analytics**:
```swift
PostHogSDK.shared.capture("interests_screen_viewed")

PostHogSDK.shared.capture("interests_selected", properties: [
    "eras": ["victorian", "wwii"],
    "categories": ["architecture", "industrial"],
    "used_lucky_button": false,
    "selection_count": 4
])
```

---

### Screen 7 — Soft Paywall

**Purpose**: Introduce premium before the user experiences limitations. Skippable.

**Placement**: After interests, before the map. Shown once during onboarding.
A hard paywall is shown later when the user hits a free-tier limit.

**UI**:
- Background: `HHColors.backgroundPrimary`
- Badge: "Try free for 7 days" (Warm Amber chip, prominent)
- Headline: "Unlock the full story"
- Feature list (3 items with icons):
  - "AI-narrated audio in HD voice" — Premium ElevenLabs
  - "Unlimited listens, every day" — vs 5/day free
  - "Download stories for offline" — offline packs
- Pricing: "$4.99/month · Cancel anytime"
  - Annual toggle: "or $39.99/year (save 33%)"
- Primary Button: "Start Free Trial" → RevenueCat purchase flow
- Secondary link: "Continue with free plan" → proceeds to map

**Analytics**:
```swift
PostHogSDK.shared.capture("paywall_shown", properties: [
    "source": "onboarding",
    "position": "post_interests",
    "variant": PostHogSDK.shared.getFeatureFlag("onboarding_paywall_position") as? String ?? "default"
])

PostHogSDK.shared.capture("paywall_cta_tapped", properties: [
    "source": "onboarding",
    "product": "monthly"    // or "annual"
])

PostHogSDK.shared.capture("paywall_dismissed", properties: [
    "source": "onboarding",
    "action": "continue_free"
])
```

---

### Screen 8 — Map (First Launch)

**Purpose**: First real app screen. User sees sites around them immediately.

**First-launch behaviours**:
- Map centres on user's location (or London if no location permission)
- Nearest 3 sites pulse-animate once to draw attention
- A tooltip appears: "Tap a pin to discover its story" (auto-dismisses after 3s or on tap)

**Analytics**:
```swift
PostHogSDK.shared.capture("map_first_loaded", properties: [
    "location_granted": true,
    "sites_visible": 12,    // count of pins in initial viewport
    "city": "London"
])
```

---

### Screen 9 — First Audio Play (Triggered from Site Detail)

When the user taps a pin and opens a site → they tap "Listen" for the first time.
The first listen is a key activation event.

**Analytics**:
```swift
PostHogSDK.shared.capture("first_audio_played", properties: [
    "site_id": site.id.uuidString,
    "site_name": site.name,
    "distance_meters": 340,
    "tier": "free",           // or "premium"
    "provider": "polly"       // or "elevenlabs"
])
```

---

## Complete PostHog Event Reference

### Onboarding Events

| Event | When fired | Key properties |
|-------|------------|----------------|
| `onboarding_splash_viewed` | Screen 1 shown | — |
| `onboarding_value_prop_viewed` | Each card shown | `card_index`, `method` |
| `onboarding_value_prop_skipped` | Skip tapped | `at_card_index` |
| `location_permission_screen_viewed` | Screen 3 shown | — |
| `location_permission_result` | iOS prompt resolves | `granted`, `status` |
| `notification_permission_screen_viewed` | Screen 4 shown | — |
| `notification_permission_result` | iOS prompt resolves | `granted` |
| `signup_screen_viewed` | Screen 5 shown | — |
| `signup_method_selected` | Method tapped | `method` |
| `signup_completed` | Auth success (new user) | `method`, `is_new_user` |
| `signin_completed` | Auth success (returning) | `method` |
| `interests_screen_viewed` | Screen 6 shown | — |
| `interests_selected` | "Let's go" tapped | `eras`, `categories`, `selection_count` |
| `paywall_shown` | Screen 7 shown | `source`, `variant` |
| `paywall_cta_tapped` | Subscribe button tapped | `source`, `product` |
| `paywall_dismissed` | Skipped | `source`, `action` |
| `map_first_loaded` | First map view | `location_granted`, `sites_visible`, `city` |
| `first_audio_played` | First listen ever | `site_id`, `distance_meters`, `tier`, `provider` |

### Core Discovery Events

| Event | When fired | Key properties |
|-------|------------|----------------|
| `map_loaded` | Map view appears | `sites_visible`, `radius_km`, `city` |
| `map_panned` | User pans map | `new_city` (if changed) |
| `map_zoomed` | Zoom level change | `zoom_level` |
| `pin_tapped` | Site pin tapped | `site_id`, `site_name`, `distance_meters`, `site_type`, `era` |
| `site_detail_viewed` | Site detail screen shown | `site_id`, `source: "pin"\|"search"\|"saved"` |
| `audio_play_started` | Listen button tapped | `site_id`, `tier`, `provider`, `is_cached` |
| `audio_paused` | Pause tapped | `site_id`, `progress_pct` |
| `audio_resumed` | Play tapped after pause | `site_id`, `progress_pct` |
| `audio_completed` | Audio reached end | `site_id`, `duration_sec`, `provider` |
| `audio_abandoned` | Dismissed before end | `site_id`, `progress_pct` |
| `audio_speed_changed` | Speed selector changed | `site_id`, `from_speed`, `to_speed` |
| `site_saved` | Bookmark added | `site_id` |
| `site_unsaved` | Bookmark removed | `site_id` |

### Search & Discovery Events

| Event | When fired | Key properties |
|-------|------------|----------------|
| `search_opened` | Search bar focused | — |
| `search_performed` | Query submitted | `query_length`, `result_count` |
| `search_result_tapped` | Result selected | `site_id`, `result_position` |
| `filter_opened` | Filter panel opened | — |
| `filter_applied` | Filter confirmed | `era_filters`, `type_filters`, `radius_km` |
| `filter_cleared` | Reset tapped | — |

### Subscription & Paywall Events

| Event | When fired | Key properties |
|-------|------------|----------------|
| `paywall_shown` | Any paywall shown | `source`, `trigger_feature` |
| `paywall_dismissed` | Paywall closed | `source`, `action` |
| `subscription_purchase_started` | Purchase initiated | `product_id` |
| `subscription_started` | Purchase confirmed | `product_id`, `price`, `currency`, `is_trial` |
| `subscription_cancelled` | RevenueCat webhook | `product_id`, `days_active` |
| `subscription_renewed` | Auto-renew success | `product_id` |
| `restore_purchases_tapped` | Restore button tapped | — |
| `restore_purchases_success` | Restore found subscription | `product_id` |

### Engagement & Retention Events

| Event | When fired | Key properties |
|-------|------------|----------------|
| `app_opened` | App becomes active | `source: "direct"\|"notification"\|"widget"`, `session_number` |
| `app_backgrounded` | App goes to background | `session_duration_sec` |
| `offline_pack_downloaded` | Offline audio pack saved | `city`, `site_count`, `total_mb` |
| `share_tapped` | Share button tapped | `site_id`, `share_method` |
| `notification_received` | Push notification shown | `notification_type` |
| `notification_tapped` | Push opened | `notification_type`, `site_id` |

---

## PostHog Funnels to Configure

### Funnel 1: Onboarding Activation

Steps:
1. `onboarding_splash_viewed`
2. `location_permission_result` (granted = true)
3. `signup_completed`
4. `map_first_loaded`
5. `first_audio_played`

**Target conversion (step 1 → step 5)**: 30%

### Funnel 2: Discovery → Listen

Steps:
1. `map_loaded`
2. `pin_tapped`
3. `site_detail_viewed`
4. `audio_play_started`
5. `audio_completed`

**Target conversion (step 2 → step 5)**: 40%

### Funnel 3: Free → Paid

Steps:
1. `paywall_shown`
2. `paywall_cta_tapped`
3. `subscription_started`

**Target conversion (step 1 → step 3)**: 5–8%

---

## Feature Flags

All feature flags are defined in PostHog and accessed via the iOS SDK.

```swift
// Usage pattern
let flag = PostHogSDK.shared.getFeatureFlag("flag_name") as? String ?? "control"
```

| Flag | Type | Variants | Purpose |
|------|------|----------|---------|
| `onboarding_paywall_position` | String | `post_interests` (control) · `post_signup` | A/B test paywall timing |
| `audio_autoplay_preview` | Boolean | `true` · `false` (control) | Auto-play 15s preview when pin tapped |
| `map_default_radius_km` | String | `1` · `2` (control) · `5` | Default discovery radius |
| `site_detail_layout` | String | `top_image` (control) · `side_card` | Site detail UI variant |
| `onboarding_skip_visible` | Boolean | `true` (control) · `false` | Test hiding skip on value prop |

---

## User Properties (PostHog Person Properties)

Set on `identify()` and updated when they change:

| Property | Type | Values |
|----------|------|--------|
| `plan` | String | `free`, `premium` |
| `signup_method` | String | `apple`, `email` |
| `location_granted` | Boolean | — |
| `notifications_granted` | Boolean | — |
| `onboarding_completed` | Boolean | — |
| `total_listens` | Integer | — |
| `total_sites_visited` | Integer | — |
| `preferred_eras` | Array | e.g. `["victorian", "wwii"]` |
| `city` | String | Last known city |
| `audio_speed_preference` | Float | `0.75`, `1.0`, `1.25`, `1.5`, `2.0` |
| `days_since_signup` | Integer | Computed cohort property |

---

## Analytics Helper — Swift

```swift
// Core/Utils/Analytics.swift

import PostHog

/// Thin wrapper around PostHog to provide type safety and a single import point.
/// All analytics calls in the app go through this namespace.
enum Analytics {

    static func capture(_ event: Event, properties: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    static func identify(_ userId: String, properties: [String: Any] = [:]) {
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    static func reset() {
        PostHogSDK.shared.reset()
    }

    static func isFeatureEnabled(_ flag: FeatureFlag) -> Bool {
        PostHogSDK.shared.isFeatureEnabled(flag.rawValue)
    }

    static func featureFlagVariant(_ flag: FeatureFlag) -> String {
        PostHogSDK.shared.getFeatureFlag(flag.rawValue) as? String ?? "control"
    }

    // MARK: — Event names (prevent typos)
    enum Event: String {
        case splashViewed           = "onboarding_splash_viewed"
        case valuePropViewed        = "onboarding_value_prop_viewed"
        case locationPermResult     = "location_permission_result"
        case signupCompleted        = "signup_completed"
        case mapFirstLoaded         = "map_first_loaded"
        case firstAudioPlayed       = "first_audio_played"
        case pinTapped              = "pin_tapped"
        case siteDetailViewed       = "site_detail_viewed"
        case audioPlayStarted       = "audio_play_started"
        case audioCompleted         = "audio_completed"
        case paywallShown           = "paywall_shown"
        case subscriptionStarted    = "subscription_started"
        case siteSaved              = "site_saved"
        case searchPerformed        = "search_performed"
        // ... add as needed
    }

    // MARK: — Feature flag names
    enum FeatureFlag: String {
        case onboardingPaywallPosition = "onboarding_paywall_position"
        case audioAutoplayPreview      = "audio_autoplay_preview"
        case mapDefaultRadiusKm        = "map_default_radius_km"
        case siteDetailLayout          = "site_detail_layout"
    }
}
```
