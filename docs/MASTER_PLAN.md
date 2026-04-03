# Hidden History — Master Plan

> **For agents**: This is the top-level reference document. All architectural, product, and
> technical decisions are recorded here. Read this first, then consult the specialist docs
> in this folder for deep detail.

---

## What Is This App?

**Hidden History** is an iOS app that places historical monuments, buildings, battlefields,
and culturally significant sites on a map around the user. The primary experience is
**listening** — AI-generated audio narrations bring each place to life. Text is always
available as a fallback.

**Tagline**: "Stories beneath your feet"

---

## Confirmed Decisions

| Question | Decision |
|----------|----------|
| Platform | iOS (SwiftUI, iOS 16+) |
| MVP geographic focus | London + NYC |
| Solo developer | Yes — simple branching, no PR review gate required |
| ElevenLabs (premium audio) | From day 1 — free users get Polly, paid get ElevenLabs |
| Existing accounts | None — all services set up fresh |
| Android | iOS only; React Native is a future option if needed |
| Admin panel | Supabase Studio for MVP; no custom CMS initially |

---

## Tech Stack

### iOS App

| Concern | Choice | Reason |
|---------|--------|--------|
| Language | Swift 6 | Latest, strict concurrency |
| UI | SwiftUI | Modern, iOS 16+ native |
| Maps | MapKit | Free, native, sufficient for MVP |
| Audio | AVFoundation | Native streaming + caching |
| Backend client | Supabase Swift SDK | Type-safe, real-time capable |
| Subscriptions | RevenueCat SDK (StoreKit 2) | Server-side validation, analytics |
| Analytics | PostHog iOS SDK | Feature flags + funnels |
| Architecture | Clean Architecture | Testable, mockable layers |
| Testing | Swift Testing + XCTest | See METHODOLOGY.md |

### Backend (Supabase)

| Concern | Choice |
|---------|--------|
| Database | PostgreSQL + PostGIS extension |
| Geospatial queries | ST_DWithin (proximity), ST_Intersects (viewport) |
| Storage | Supabase Storage (audio .mp3, images, PDFs) |
| Serverless logic | Edge Functions (TypeScript/Deno) |
| Auth | Supabase Auth — Apple Sign In + email magic link |
| Realtime | Supabase Realtime (future: live site additions) |

### Third-Party Services

| Service | Role | Tier |
|---------|------|------|
| ElevenLabs | Premium AI narration | API Pro (~$99/mo) |
| AWS Polly | Standard narration (free users) | Pay-as-you-go |
| Wikidata SPARQL | Historical content + coordinates | Free |
| OSM Overpass API | `historic=*` location data | Free |
| Wikipedia REST API | Rich descriptions + images | Free |
| Historic England API | UK historical sites dataset | Free (open data) |
| NPS / NRHP | US historical places dataset | Free |
| RevenueCat | Subscription management | Free to $2.5k MRR |
| PostHog | Analytics + feature flags | Free (1M events/mo) |

---

## System Architecture

```
┌──────────────────────────────────────────────────────────┐
│                  iOS App (SwiftUI)                        │
│                                                          │
│  Presentation Layer  ←→  ViewModels                      │
│  Domain Layer         →  Use Cases + Entities            │
│  Data Layer           →  Repository Implementations      │
│       │                                                  │
│   Supabase SDK · RevenueCat SDK · PostHog SDK · AVFoundation │
└──────────────────────┬───────────────────────────────────┘
                       │ HTTPS
┌──────────────────────▼───────────────────────────────────┐
│                    Supabase                               │
│                                                          │
│  PostgreSQL + PostGIS  →  historical_sites table         │
│  Supabase Storage      →  narrations/ · images/          │
│  Edge Functions        →  generate-audio · enrich-site   │
│                            sync-osm (nightly cron)       │
│  Supabase Auth         →  Apple Sign In · magic link     │
└──────────────────────┬───────────────────────────────────┘
                       │
        ┌──────────────┼──────────────────┐
        ▼              ▼                  ▼
  Wikidata SPARQL  OSM Overpass   Wikipedia REST API
  (content+coords) (historic=*)   (descriptions+images)
        │
  Historic England API · NPS/NRHP (batch import only)
```

---

## iOS Project Structure

```
HiddenHistory/
├── App/
│   ├── HiddenHistoryApp.swift        Entry point, SDK init
│   └── AppDelegate.swift
│
├── Core/
│   ├── DesignSystem/
│   │   ├── Colors.swift              HHColors token namespace
│   │   ├── Typography.swift          HHTypography token namespace
│   │   ├── Spacing.swift             HHSpacing constants
│   │   └── Components/               Reusable SwiftUI components
│   ├── Extensions/
│   └── Utils/
│
├── Domain/                           ← Pure Swift, zero UIKit/SwiftUI imports
│   ├── Entities/
│   │   ├── HistoricalSite.swift
│   │   ├── UserProfile.swift
│   │   └── AudioNarration.swift
│   ├── UseCases/
│   │   ├── FetchNearbySitesUseCase.swift
│   │   ├── FetchSiteDetailUseCase.swift
│   │   ├── PlayAudioUseCase.swift
│   │   ├── SaveSiteUseCase.swift
│   │   └── CheckEntitlementsUseCase.swift
│   └── Repositories/                 Protocol definitions only
│       ├── SiteRepositoryProtocol.swift
│       ├── AudioRepositoryProtocol.swift
│       └── UserRepositoryProtocol.swift
│
├── Data/                             ← Implements domain protocols
│   ├── Repositories/
│   │   ├── SupabaseSiteRepository.swift
│   │   ├── SupabaseAudioRepository.swift
│   │   └── SupabaseUserRepository.swift
│   ├── Remote/
│   │   ├── SupabaseClient.swift
│   │   └── DTOs/                     Codable response types
│   └── Local/
│       └── AudioCache.swift          File-system audio caching
│
├── Presentation/
│   ├── Onboarding/
│   │   ├── SplashView.swift
│   │   ├── ValuePropView.swift
│   │   ├── PermissionsView.swift
│   │   ├── AuthView.swift
│   │   ├── InterestsView.swift
│   │   └── PaywallView.swift
│   ├── Map/
│   │   ├── MapView.swift
│   │   ├── MapViewModel.swift
│   │   └── Pins/
│   │       ├── SitePin.swift
│   │       └── ClusterPin.swift
│   ├── SiteDetail/
│   │   ├── SiteDetailView.swift
│   │   └── SiteDetailViewModel.swift
│   ├── AudioPlayer/
│   │   ├── AudioPlayerView.swift     Collapsed + expanded states
│   │   └── AudioPlayerViewModel.swift
│   ├── Saved/
│   │   ├── SavedView.swift
│   │   └── SavedViewModel.swift
│   ├── Profile/
│   │   ├── ProfileView.swift
│   │   └── ProfileViewModel.swift
│   └── Shared/
│       ├── PlaceCard.swift
│       ├── CategoryChip.swift
│       └── LoadingView.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings

HiddenHistoryTests/                   ← Tests written BEFORE implementation
HiddenHistoryUITests/                 ← XCUITest smoke tests
```

---

## Implementation Phases

### Phase 0 — Foundation (Week 1–2)
- [ ] Create all `/docs/` MD files and commit to repo
- [ ] Xcode project: SwiftUI app, iOS 16+, Swift 6, Swift Package Manager
- [ ] Add SPM packages: supabase-swift, purchases-ios (RevenueCat), posthog-ios
- [ ] Implement design system tokens: Colors, Typography, Spacing
- [ ] CI: GitHub Actions — run Swift tests on push to main and PRs
- [ ] Supabase: create project, enable PostGIS, run schema migrations
- [ ] Seed 500 historical sites (London + NYC, from OSM + Wikidata)

### Phase 1 — Core MVP (Week 3–6)
> All Domain + Data code requires tests written first (see METHODOLOGY.md)

- [ ] **[TDD]** HistoricalSite entity + FetchNearbySitesUseCase
- [ ] **[TDD]** SupabaseSiteRepository (PostGIS proximity query)
- [ ] **[TDD]** AudioPlayerViewModel state machine (idle/loading/playing/paused/error)
- [ ] MapView with custom pins (MapKit, Amber for unvisited, Green for visited)
- [ ] SiteDetailView (text + image + audio trigger)
- [ ] AudioPlayerView (bottom sheet, collapsed + expanded)
- [ ] Audio streaming (AWS Polly via AVPlayer)
- [ ] Basic onboarding: Splash → Location Permission → Map
- [ ] PostHog: wire core funnel events

### Phase 2 — Auth + Subscriptions (Week 7–9)
- [ ] **[TDD]** CheckEntitlementsUseCase (RevenueCat wrapper)
- [ ] **[TDD]** SupabaseUserRepository + AuthRepository
- [ ] Apple Sign In + email magic link
- [ ] RevenueCat: configure products (monthly $4.99, annual $39.99, lifetime $99.99)
- [ ] PaywallView (soft gate in onboarding, hard gate on premium features)
- [ ] ElevenLabs audio path for premium entitlement
- [ ] All premium feature gates applied throughout UI

### Phase 3 — Full Onboarding + Analytics (Week 10–11)
- [ ] Complete 9-screen onboarding flow (see ONBOARDING_ANALYTICS.md)
- [ ] Interest selection → personalised initial map filter
- [ ] All PostHog events + feature flags wired (see ONBOARDING_ANALYTICS.md)
- [ ] Offline audio download + playback (premium)
- [ ] Saved/bookmarked sites with user_history table

### Phase 4 — Polish + Launch (Week 12–14)
- [ ] Dark mode (all HHColors dark tokens applied)
- [ ] Accessibility: Dynamic Type, VoiceOver labels, minimum 44pt touch targets
- [ ] Push notifications (nearby site, new discovery in area)
- [ ] App Store Connect: screenshots, preview video, description copy
- [ ] TestFlight beta
- [ ] Data expansion: Historic England + NRHP datasets
- [ ] Instruments profiling (CPU, memory, audio buffer)

---

## Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Map SDK | MapKit | Free, native, performant; Mapbox if clustering needed |
| Backend | Supabase | PostGIS geospatial, relational SQL, predictable pricing |
| Audio (free tier) | AWS Polly | ~$0.004/1K chars — cheap enough to offer free |
| Audio (premium) | ElevenLabs | Noticeably better quality; justifies subscription |
| Subscriptions | RevenueCat | StoreKit 2 abstraction, server-side validation, analytics |
| Analytics | PostHog | Feature flags, open source, 1M events/mo free |
| App architecture | Clean Architecture | Testable domain layer, swappable data layer |
| TDD enforcement | Tests first, always | Prevents regression, forces good API design |
| iOS minimum version | iOS 16 | SwiftUI stability + StoreKit 2; ~95% device coverage |

---

## Related Documents

| Document | Contents |
|----------|----------|
| [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) | Colors, typography, components, logo, branding |
| [METHODOLOGY.md](./METHODOLOGY.md) | TDD rules, git workflow, code standards |
| [DATA_ARCHITECTURE.md](./DATA_ARCHITECTURE.md) | DB schema, data sources, enrichment pipeline |
| [ONBOARDING_ANALYTICS.md](./ONBOARDING_ANALYTICS.md) | Onboarding flow, PostHog events, A/B tests |
| [MONETIZATION.md](./MONETIZATION.md) | Free/paid matrix, RevenueCat config, pricing |
