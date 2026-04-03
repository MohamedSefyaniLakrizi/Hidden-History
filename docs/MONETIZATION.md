# Hidden History — Monetization

> **For agents**: This document defines the complete subscription model, RevenueCat
> configuration, all feature gates, and the paywall implementation strategy.
> All subscription logic must go through `CheckEntitlementsUseCase` — never call
> RevenueCat directly from a View or ViewModel.

---

## Model Summary

- **Primary revenue**: Auto-renewing subscriptions (Apple In-App Purchase via RevenueCat)
- **Free tier**: Fully functional but limited — users can discover value before paying
- **Premium tier**: Removes limits + adds quality and convenience upgrades
- **Lifetime**: One-time purchase for power users

No ads in the free tier (Phase 1). Ads could be reconsidered in Phase 3 if retention is
strong enough to make a premium upsell compelling.

---

## Products

### Apple App Store Connect Products

These must be created in App Store Connect before RevenueCat can reference them.

| Product ID | Type | Price | Description |
|------------|------|-------|-------------|
| `hidden_history_premium_monthly` | Auto-renewable subscription | $4.99/mo | Hidden History Premium — Monthly |
| `hidden_history_premium_annual` | Auto-renewable subscription | $39.99/yr | Hidden History Premium — Annual |
| `hidden_history_lifetime` | Non-consumable IAP | $99.99 | Hidden History Premium — Lifetime |

**Subscription group**: `Hidden History Premium` (monthly + annual in same group — user can
only hold one at a time; App Store allows upgrade/downgrade between them)

**Free trial**: 7-day free trial on monthly product (configured in App Store Connect).
Annual can optionally have a 14-day trial — test with A/B after launch.

**Introductory offers**: $0.99 first month (for lapsed users only — configure as
"pay-as-you-go" offer targeting users who previously cancelled)

---

## RevenueCat Configuration

### Entitlements

Single entitlement gates all paid features:

| Entitlement ID | Display Name | Description |
|----------------|--------------|-------------|
| `premium_access` | Premium Access | Unlocks all premium features |

All three products (monthly, annual, lifetime) grant the `premium_access` entitlement.

### Offerings

| Offering ID | Products included | When shown |
|-------------|-------------------|------------|
| `default` | monthly + annual | Default paywall throughout app |
| `onboarding_offer` | monthly + annual (trial highlighted) | Onboarding paywall only |
| `winback_offer` | annual only (discounted if eligible) | Lapsed subscriber re-engagement |

RevenueCat's Offerings system lets us change which products are shown without an app update.

---

## Free vs Premium Feature Matrix

| Feature | Free | Premium |
|---------|------|---------|
| **Map & Discovery** | | |
| View historical sites on map | ✅ Unlimited | ✅ Unlimited |
| Text descriptions | ✅ Unlimited | ✅ Unlimited |
| Site photos | ✅ | ✅ |
| **Audio** | | |
| Standard narration (AWS Polly) | ✅ 5 per day | ✅ Unlimited |
| High-quality AI narration (ElevenLabs) | ❌ | ✅ |
| Playback speed control | ✅ | ✅ |
| Offline audio download | ❌ | ✅ |
| **Organisation** | | |
| Saved/bookmarked sites | 10 max | ✅ Unlimited |
| Visited history log | Last 7 days | ✅ Full history |
| **Personalisation** | | |
| Interest-based map filters | ❌ | ✅ |
| Custom map styles (3 styles) | ❌ | ✅ |
| **Extras** | | |
| PDF export of visited history | ❌ | ✅ |
| Early access to new sites (24h) | ❌ | ✅ |
| Ad-free experience | ❌ (ads in Phase 3+) | ✅ |

### Daily Audio Limit (Free Tier)

Free users get **5 audio plays per day** (resets at midnight local time). This is tracked
server-side via `user_history` table count, not client-side, to prevent manipulation.

When the 5th audio play finishes, a non-blocking banner appears:
> "You've used all 5 free listens today. Upgrade for unlimited."

On the 6th attempt, the paywall is shown (hard gate).

---

## iOS Implementation

### RevenueCat SDK Setup

```swift
// App/HiddenHistoryApp.swift

import RevenueCat

// In App init():
Purchases.logLevel = .error  // .debug in development
Purchases.configure(
    with: Configuration.Builder(withAPIKey: Config.revenueCatApiKey)
        .with(appUserID: nil)  // RevenueCat generates anonymous ID until sign-in
        .build()
)

// After sign-in — link RevenueCat user to Supabase user
Purchases.shared.logIn(supabaseUserId) { customerInfo, created, error in
    // handle
}
```

### Entitlement Check — Domain Layer

```swift
// Domain/UseCases/CheckEntitlementsUseCase.swift
// Tests written FIRST in: HiddenHistoryTests/Domain/UseCases/CheckEntitlementsUseCaseTests.swift

protocol EntitlementRepositoryProtocol {
    func fetchCustomerInfo() async throws -> CustomerEntitlements
}

struct CustomerEntitlements {
    let isPremium: Bool
    let expiresAt: Date?
    let isInTrial: Bool
}

final class CheckEntitlementsUseCase {
    private let repository: EntitlementRepositoryProtocol

    init(repository: EntitlementRepositoryProtocol) {
        self.repository = repository
    }

    /// Returns true if the user currently has active premium access.
    func isPremium() async throws -> Bool {
        let info = try await repository.fetchCustomerInfo()
        return info.isPremium
    }
}
```

### Entitlement Repository — Data Layer

```swift
// Data/Repositories/RevenueCatEntitlementRepository.swift

import RevenueCat

final class RevenueCatEntitlementRepository: EntitlementRepositoryProtocol {
    func fetchCustomerInfo() async throws -> CustomerEntitlements {
        let info = try await Purchases.shared.customerInfo()
        let entitlement = info.entitlements["premium_access"]
        return CustomerEntitlements(
            isPremium: entitlement?.isActive ?? false,
            expiresAt: entitlement?.expirationDate,
            isInTrial: entitlement?.periodType == .trial
        )
    }
}
```

### Feature Gating Pattern in ViewModels

```swift
// In any ViewModel that needs to check entitlement:

@Observable
final class SiteDetailViewModel {
    private(set) var canPlayPremiumAudio = false
    private let checkEntitlements: CheckEntitlementsUseCase

    func onAppear(for site: HistoricalSite) async {
        canPlayPremiumAudio = (try? await checkEntitlements.isPremium()) ?? false
    }
}
```

### Paywall View

```swift
// Presentation/Onboarding/PaywallView.swift
// Called from anywhere a premium feature is gate-blocked

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    let source: PaywallSource   // onboarding, audio_limit, feature_gate

    var body: some View {
        VStack(spacing: HHSpacing.lg) {
            // Trial badge
            Text("Try free for 7 days")
                .font(HHTypography.label)
                .foregroundStyle(.white)
                .padding(.horizontal, HHSpacing.md)
                .padding(.vertical, HHSpacing.xs)
                .background(HHColors.accent)
                .clipShape(Capsule())

            // Headline
            Text("Unlock the full story")
                .font(HHTypography.displaySmall)
                .foregroundStyle(HHColors.textPrimary)

            // Feature list
            FeatureRow(icon: "waveform", text: "AI-narrated audio in HD voice")
            FeatureRow(icon: "infinity", text: "Unlimited listens, every day")
            FeatureRow(icon: "arrow.down.circle", text: "Download stories for offline")

            // Product selector
            ProductSelectorView(onSelect: { product in
                Task { await purchase(product) }
            })

            // CTA
            Button("Start Free Trial") {
                Analytics.capture(.paywallCtaTapped, properties: ["source": source.rawValue])
                // ... initiate purchase
            }
            .buttonStyle(HHPrimaryButtonStyle())

            // Skip
            Button("Continue with free plan") { dismiss() }
                .font(HHTypography.body)
                .foregroundStyle(HHColors.textTertiary)
        }
        .padding(HHSpacing.lg)
        .onAppear {
            Analytics.capture(.paywallShown, properties: [
                "source": source.rawValue,
                "variant": Analytics.featureFlagVariant(.onboardingPaywallPosition)
            ])
        }
    }
}
```

---

## Paywall Trigger Points

| Location | Trigger | Source value |
|----------|---------|--------------|
| Onboarding screen 7 | After interests step | `"onboarding"` |
| Audio player | 6th play attempt on free tier | `"audio_limit"` |
| Saved sites | Attempt to save 11th site | `"save_limit"` |
| History screen | Tap "view full history" on free tier | `"history_limit"` |
| Filter panel | Tap era/category filter on free tier | `"feature_gate"` |
| Map styles | Tap custom style on free tier | `"feature_gate"` |
| Offline download | Tap download button on free tier | `"feature_gate"` |

---

## Pricing Rationale

### $4.99/month

- Comparable to Spotify's lowest tier feel, much less than a museum entry
- 33% of users who subscribe will choose annual over monthly (industry average)
- Target: 1,000 subscribers at $4.99/mo = ~$4,990 MRR gross; ~$3,640 after Apple 30% cut
- At scale: Apple's fee reduces to 15% for subs held > 12 months

### Annual ($39.99)

- Effective $3.33/mo — presented as "save 33%"
- Higher LTV, lower churn risk
- Promoted prominently with toggle on paywall

### Lifetime ($99.99)

- ~20 months of equivalent monthly value
- Targeted at power users / history enthusiasts who want to support the app
- Not promoted aggressively — available on Profile > Subscription screen

### Price Testing

Use RevenueCat's Offerings + PostHog feature flags to A/B test:
- $4.99 vs $3.99 vs $5.99 monthly (after 500+ subscribers)
- 7-day vs 14-day free trial length
- Annual discount framing: "save 33%" vs "2 months free"

---

## Revenue Flow

```
User taps "Start Free Trial"
         ↓
RevenueCat SDK initiates StoreKit 2 purchase
         ↓
iOS presents native payment sheet (Apple handles all payment processing)
         ↓
StoreKit 2 delivers signed transaction to app
         ↓
RevenueCat validates server-side (no custom backend needed)
         ↓
RevenueCat grants `premium_access` entitlement
         ↓
App calls CheckEntitlementsUseCase → isPremium = true
         ↓
UI unlocks premium features
         ↓
PostHog: subscription_started event fired
         ↓
Supabase user_metadata.plan updated to "premium"
```

### Webhooks (Phase 2)

Configure RevenueCat → Supabase Edge Function webhook for:
- `INITIAL_PURCHASE` → update user_metadata.plan = "premium"
- `RENEWAL` → extend expiry date in DB
- `CANCELLATION` → schedule plan downgrade at period end
- `EXPIRATION` → downgrade to free

---

## Financial Projections (Conservative)

| Metric | Month 3 | Month 6 | Month 12 |
|--------|---------|---------|---------|
| Total installs | 500 | 2,000 | 8,000 |
| Paywall conversion | 5% | 6% | 7% |
| Active subscribers | 25 | 120 | 560 |
| Gross MRR | $125 | $600 | $2,800 |
| After Apple 30% cut | $87 | $420 | $1,960 |
| Infrastructure cost | ~$150 | ~$250 | ~$450 |
| Net (monthly) | -$63 | +$170 | +$1,510 |

Break-even: ~month 6 at current projections.
Revenue covers infrastructure cost well before ElevenLabs API costs escalate significantly.

---

## RevenueCat Dashboard Metrics to Monitor

| Metric | Target | Action if below |
|--------|--------|-----------------|
| Trial start rate | > 15% of paywalls shown | Redesign paywall copy/layout |
| Trial conversion rate | > 40% of trials | Improve trial-period experience |
| Monthly churn rate | < 5% | Add engagement features, improve value delivery |
| Annual plan mix | > 30% of new subs | Increase annual discount visibility |
| LTV (12 month) | > $30 per subscriber | Focus retention, not just acquisition |
