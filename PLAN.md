# Hidden History — Step-by-Step Build Plan

> **For agents**: Each step below is self-contained. Read the referenced `/docs/` files
> before starting a step. All architectural rules are in `docs/METHODOLOGY.md`.
> TDD is mandatory for Domain, Data, and ViewModels — tests before implementation, always.

---

## How to Use This Plan

1. Scan the Summary Table at the bottom — find the first step where **Status** is `NOT STARTED` or `IN PROGRESS`.
2. Read the linked docs listed in that step's **Context** block.
3. When you begin a step, change its `**Status**` line to `IN PROGRESS`.
4. Complete every deliverable checkbox in that step.
5. When all checkboxes are ticked, change `**Status**` to `COMPLETE`.
6. Do NOT skip steps — later steps depend on earlier ones.

**Status values**: `NOT STARTED` · `IN PROGRESS` · `COMPLETE` · `BLOCKED` (add a note if blocked)

---

## STEP 0 — Xcode Project Skeleton

**Status**: `NOT STARTED`

**Goal**: Create the iOS project with the correct folder structure, minimum deployment target, and SPM dependencies added.

**Context**: `docs/MASTER_PLAN.md` (iOS Project Structure, Tech Stack)

**Deliverables**:
- [ ] New Xcode project: `HiddenHistory`, SwiftUI lifecycle, Swift 6, iOS 16+ minimum, bundle ID `com.hiddenhistory.app`
- [ ] Create all folders matching the project structure in `MASTER_PLAN.md`:
  `App/`, `Core/DesignSystem/`, `Core/Extensions/`, `Core/Utils/`,
  `Domain/Entities/`, `Domain/UseCases/`, `Domain/Repositories/`,
  `Data/Repositories/`, `Data/Remote/DTOs/`, `Data/Local/`,
  `Presentation/Onboarding/`, `Presentation/Map/Pins/`, `Presentation/SiteDetail/`,
  `Presentation/AudioPlayer/`, `Presentation/Saved/`, `Presentation/Profile/`,
  `Presentation/Shared/`, `Resources/`
- [ ] Add SPM packages: `supabase/supabase-swift`, `RevenueCat/purchases-ios`, `PostHog/posthog-ios`
- [ ] Add Inter font TTF files to `Resources/` and register in `Info.plist`
- [ ] Create `HiddenHistoryTests/` and `HiddenHistoryUITests/` targets
- [ ] Create `.gitignore` ignoring `*.xcconfig`, `DerivedData/`, `.DS_Store`
- [ ] Create `Config.xcconfig.example` with keys: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY`, `POSTHOG_API_KEY`
- [ ] Create `App/Config.swift` that reads those keys from `Bundle.main.infoDictionary`
- [ ] Build succeeds (zero errors, zero warnings)

---

## STEP 1 — Design System Tokens

**Status**: `NOT STARTED`

**Goal**: Implement all design system tokens (`HHColors`, `HHTypography`, `HHSpacing`) so every subsequent view can reference them without hardcoding values.

**Context**: `docs/DESIGN_SYSTEM.md` (Color System, Typography, Spacing & Layout sections)

**Deliverables**:
- [ ] `Core/DesignSystem/Colors.swift` — full `HHColors` enum with all tokens exactly as specified in DESIGN_SYSTEM.md (brand, background, text, status, map, dividers). Includes the private `Color(hex:)` extension.
- [ ] `Assets.xcassets` — adaptive color sets for all tokens listed as "Asset catalog adaptive" (`BackgroundPrimary/Secondary/Tertiary`, `TextPrimary/Secondary/Tertiary/Disabled`, `Divider`, `Border`) with light and dark hex values from the doc.
- [ ] `Core/DesignSystem/Typography.swift` — full `HHTypography` enum with all 9 type styles.
- [ ] `Core/DesignSystem/Spacing.swift` — `HHSpacing` and `HHRadius` enums with all values.
- [ ] `Core/DesignSystem/Components/` — empty folder placeholder (components added in later steps).
- [ ] Build succeeds. No hardcoded hex or numeric values outside these files.

---

## STEP 2 — Analytics Helper

**Status**: `NOT STARTED`

**Goal**: Implement the `Analytics` wrapper and the `App` entry point with all three SDKs initialised.

**Context**: `docs/ONBOARDING_ANALYTICS.md` (PostHog Setup, Analytics Helper — Swift section), `docs/MONETIZATION.md` (RevenueCat SDK Setup)

**Deliverables**:
- [ ] `Core/Utils/Analytics.swift` — full `Analytics` enum with `Event` and `FeatureFlag` nested enums, all event cases from ONBOARDING_ANALYTICS.md, all helper static methods (`capture`, `identify`, `reset`, `isFeatureEnabled`, `featureFlagVariant`).
- [ ] `App/HiddenHistoryApp.swift` — `@main` struct: initialises PostHog (with config from ONBOARDING_ANALYTICS.md), initialises RevenueCat (anonymous ID until sign-in), sets up `WindowGroup { RootView() }`.
- [ ] `App/RootView.swift` — placeholder `NavigationStack` showing "Hidden History" text (replaced in Step 14).
- [ ] `App/DependencyContainer.swift` — empty class, will be filled as dependencies are added in later steps.
- [ ] Build succeeds.

---

## STEP 3 — Supabase Schema & Migrations

**Status**: `NOT STARTED`

**Goal**: Set up the Supabase project schema, RLS policies, and storage bucket entirely in SQL migration files committed to the repo.

**Context**: `docs/DATA_ARCHITECTURE.md` (entire document)

**Deliverables**:
- [ ] `supabase/migrations/001_extensions.sql` — enable `postgis` and `pg_trgm` extensions.
- [ ] `supabase/migrations/002_historical_sites.sql` — `historical_sites` table with all columns, all indexes (spatial GIST, country, city, era, site_type, verified, name trigram).
- [ ] `supabase/migrations/003_site_categories.sql` — `site_categories` table.
- [ ] `supabase/migrations/004_user_history.sql` — `user_history` table with indexes.
- [ ] `supabase/migrations/005_site_images.sql` — `site_images` table.
- [ ] `supabase/migrations/006_rls.sql` — all RLS policies from DATA_ARCHITECTURE.md (public read on verified sites, user-scoped read/write/update on user_history).
- [ ] `supabase/migrations/007_nearby_sites_rpc.sql` — a PostgreSQL function `nearby_sites(lat float8, lng float8, radius_meters float8)` that executes the proximity query from DATA_ARCHITECTURE.md and returns the result set.
- [ ] `supabase/migrations/008_storage.sql` — creates `hidden-history-assets` storage bucket (public, CDN-backed) with folder structure noted in the doc.
- [ ] `supabase/config.toml` — local Supabase config referencing the project.
- [ ] All migration files are valid SQL and can be applied in order without errors.

---

## STEP 4 — Domain Entities (TDD)

**Status**: `NOT STARTED`

**Goal**: Define all domain entities as pure Swift structs/enums. Zero third-party imports.

**Context**: `docs/MASTER_PLAN.md` (iOS Project Structure — Domain/Entities), `docs/DATA_ARCHITECTURE.md` (Core Schema, Enum Values), `docs/METHODOLOGY.md` (TDD rules, test file conventions)

**Deliverables — tests first (RED), then implementation (GREEN)**:

Tests:
- [ ] `HiddenHistoryTests/Domain/Entities/HistoricalSiteTests.swift` — tests for: valid construction, `distance(to:)` helper (haversine), `SiteType` and `Era` raw values round-trip, `HistoricalSite.stub(...)` factory method.
- [ ] `HiddenHistoryTests/Domain/Entities/UserProfileTests.swift` — tests for: construction, `isPremium` computed property.
- [ ] `HiddenHistoryTests/Domain/Entities/AudioNarrationTests.swift` — tests for: construction, `tier` enum (free/premium).

Implementation:
- [ ] `Domain/Entities/HistoricalSite.swift` — struct with all fields matching DB schema (id, name, slug, shortBio, coordinate, siteType, era, builtYear, heroImageUrl, audioUrlFree, audioUrlPremium, audioDurationSec, verified, viewCount). Includes `Coordinate` struct with lat/lng and `distance(to:)` method. `SiteType` and `Era` enums with all values from DATA_ARCHITECTURE.md.
- [ ] `Domain/Entities/UserProfile.swift` — struct: userId, email, plan (enum: free/premium), preferredEras, preferredCategories, onboardingCompleted.
- [ ] `Domain/Entities/AudioNarration.swift` — struct: siteId, url, tier (enum: free/premium), durationSec, isDownloaded.
- [ ] `HiddenHistoryTests/Mocks/` folder with stub extensions for all entities.
- [ ] All tests pass.

---

## STEP 5 — Domain Repository Protocols

**Status**: `NOT STARTED`

**Goal**: Define all repository protocols (interfaces) and use case protocols. Zero implementation — protocols only.

**Context**: `docs/MASTER_PLAN.md` (Domain/Repositories), `docs/DATA_ARCHITECTURE.md` (iOS Data Flow, Audio Flow), `docs/METHODOLOGY.md` (Architecture Rules)

**Deliverables**:
- [ ] `Domain/Repositories/SiteRepositoryProtocol.swift` — protocol with: `fetchNearbySites(near:radiusMeters:) async throws -> [HistoricalSite]`, `fetchSitesInViewport(minLat:maxLat:minLng:maxLng:) async throws -> [HistoricalSite]`, `fetchSiteDetail(id:) async throws -> HistoricalSite`, `search(query:) async throws -> [HistoricalSite]`.
- [ ] `Domain/Repositories/AudioRepositoryProtocol.swift` — protocol with: `getStreamURL(siteId:tier:) async throws -> URL`, `downloadAudio(siteId:tier:) async throws -> URL`, `cachedURL(siteId:tier:) -> URL?`.
- [ ] `Domain/Repositories/UserRepositoryProtocol.swift` — protocol with: `fetchProfile() async throws -> UserProfile`, `updateProfile(_:) async throws`, `recordVisit(siteId:listenPct:) async throws`, `saveSite(siteId:) async throws`, `unsaveSite(siteId:) async throws`, `fetchSavedSites() async throws -> [HistoricalSite]`, `fetchHistory() async throws -> [HistoricalSite]`.
- [ ] `Domain/Repositories/EntitlementRepositoryProtocol.swift` — protocol from MONETIZATION.md: `fetchCustomerInfo() async throws -> CustomerEntitlements`. Plus `CustomerEntitlements` struct.
- [ ] `Domain/Repositories/AuthRepositoryProtocol.swift` — protocol: `signInWithApple(token:nonce:) async throws -> UserProfile`, `signInWithMagicLink(email:) async throws`, `signOut() async throws`, `currentUser() -> UserProfile?`.
- [ ] Build succeeds. No implementations yet.

---

## STEP 6 — Domain Use Cases (TDD)

**Status**: `NOT STARTED`

**Goal**: Implement all domain use cases with tests first.

**Context**: `docs/MASTER_PLAN.md` (Domain/UseCases), `docs/METHODOLOGY.md` (TDD cycle, mock pattern), `docs/MONETIZATION.md` (CheckEntitlementsUseCase), `docs/DATA_ARCHITECTURE.md` (iOS Data Flow)

**Deliverables — each use case: test (RED) → implementation (GREEN)**:

- [ ] `HiddenHistoryTests/Mocks/MockSiteRepository.swift` — mock conforming to `SiteRepositoryProtocol`.
- [ ] `HiddenHistoryTests/Mocks/MockAudioRepository.swift` — mock conforming to `AudioRepositoryProtocol`.
- [ ] `HiddenHistoryTests/Mocks/MockUserRepository.swift` — mock conforming to `UserRepositoryProtocol`.
- [ ] `HiddenHistoryTests/Mocks/MockEntitlementRepository.swift` — mock conforming to `EntitlementRepositoryProtocol`.

Use cases (test file then implementation file for each):

- [ ] `FetchNearbySitesUseCase` — executes proximity fetch, filters by radius, returns sorted array.
- [ ] `FetchSiteDetailUseCase` — fetches single site, returns detail.
- [ ] `PlayAudioUseCase` — checks entitlement tier, returns correct URL (free vs premium), triggers generation if URL is nil.
- [ ] `SaveSiteUseCase` — checks free-tier save limit (10), throws `SaveLimitReached` if exceeded, otherwise delegates to repository.
- [ ] `CheckEntitlementsUseCase` — wraps `EntitlementRepositoryProtocol.fetchCustomerInfo()`, exposes `isPremium()` and `isInTrial()`.
- [ ] All tests pass. Domain layer has zero UIKit/SwiftUI/Supabase imports.

---

## STEP 7 — Data Layer: DTOs & Supabase Client

**Status**: `NOT STARTED`

**Goal**: Implement Codable DTOs that map Supabase JSON responses to domain entities, plus the Supabase client wrapper.

**Context**: `docs/DATA_ARCHITECTURE.md` (Core Schema, iOS Data Flow), `docs/METHODOLOGY.md` (Data layer rules)

**Deliverables**:

Tests:
- [ ] `HiddenHistoryTests/Data/DTOs/HistoricalSiteDTOTests.swift` — Codable round-trip test with sample JSON matching the DB column names.

Implementation:
- [ ] `Data/Remote/SupabaseClient.swift` — singleton wrapper: `SupabaseManager` initialised from `Config.swift`, exposes typed `client: SupabaseClient`.
- [ ] `Data/Remote/DTOs/HistoricalSiteDTO.swift` — `Codable` struct with snake_case keys matching DB columns. `toDomain()` method returning `HistoricalSite`.
- [ ] `Data/Remote/DTOs/UserHistoryDTO.swift` — Codable, `toDomain()`.
- [ ] `Data/Remote/DTOs/SiteCategoryDTO.swift` — Codable.
- [ ] Build succeeds. All DTO tests pass.

---

## STEP 8 — Data Layer: Repository Implementations (TDD)

**Status**: `NOT STARTED`

**Goal**: Implement the three Supabase-backed repositories.

**Context**: `docs/DATA_ARCHITECTURE.md` (Key Database Queries, Audio Flow, iOS Data Flow), `docs/METHODOLOGY.md` (Data layer TDD rules)

**Deliverables**:

Tests (use `MockSupabaseClient` — no live network):
- [ ] `HiddenHistoryTests/Data/Repositories/SupabaseSiteRepositoryTests.swift` — tests: nearby fetch calls correct RPC with correct params, viewport fetch calls correct table filter, search uses trigram query, decodes DTOs correctly.
- [ ] `HiddenHistoryTests/Data/Repositories/SupabaseAudioRepositoryTests.swift` — tests: returns cached URL when available, constructs CDN URL correctly.
- [ ] `HiddenHistoryTests/Data/Repositories/SupabaseUserRepositoryTests.swift` — tests: fetches profile, records visit upserts with correct fields, save limit enforced via repository count.

Implementation:
- [ ] `Data/Repositories/SupabaseSiteRepository.swift` — conforms to `SiteRepositoryProtocol`, calls `nearby_sites` RPC for proximity, table filter for viewport, `pg_trgm` for search.
- [ ] `Data/Repositories/SupabaseAudioRepository.swift` — conforms to `AudioRepositoryProtocol`, checks `AudioCache` first, constructs CDN URL from storage path, calls `generate-audio` Edge Function if URL missing.
- [ ] `Data/Repositories/SupabaseUserRepository.swift` — conforms to `UserRepositoryProtocol`, all CRUD operations on `user_history`.
- [ ] `Data/Local/AudioCache.swift` — file-system cache: maps `siteId + tier` to local file URL, persists mapping in `UserDefaults` (acceptable here — UI preference), checks `FileManager` for file existence.
- [ ] All tests pass.

---

## STEP 9 — Data Layer: Auth & Entitlements (TDD)

**Status**: `NOT STARTED`

**Goal**: Implement auth (Supabase Apple Sign In + magic link) and RevenueCat entitlement repository.

**Context**: `docs/MONETIZATION.md` (iOS Implementation — RevenueCat SDK, Entitlement Repository), `docs/ONBOARDING_ANALYTICS.md` (Identifying Users)

**Deliverables**:

Tests:
- [ ] `HiddenHistoryTests/Data/Repositories/RevenueCatEntitlementRepositoryTests.swift` — tests: active entitlement returns `isPremium = true`, expired entitlement returns `false`, trial period sets `isInTrial = true`.
- [ ] `HiddenHistoryTests/Data/Repositories/SupabaseAuthRepositoryTests.swift` — tests: successful sign-in returns `UserProfile`, sign-out calls reset.

Implementation:
- [ ] `Data/Repositories/RevenueCatEntitlementRepository.swift` — exact implementation from MONETIZATION.md, conforms to `EntitlementRepositoryProtocol`.
- [ ] `Data/Repositories/SupabaseAuthRepository.swift` — conforms to `AuthRepositoryProtocol`, Apple Sign In via Supabase Auth, magic link via `supabase.auth.signInWithOTP`, links RevenueCat user ID after sign-in.
- [ ] All tests pass.

---

## STEP 10 — Map ViewModel & MapView (TDD ViewModel)

**Status**: `NOT STARTED`

**Goal**: Build the core map screen — the primary app screen users see after onboarding.

**Context**: `docs/MASTER_PLAN.md` (Presentation/Map), `docs/DESIGN_SYSTEM.md` (Map Pins, Bottom Navigation), `docs/ONBOARDING_ANALYTICS.md` (Core Discovery Events), `docs/METHODOLOGY.md` (ViewModel pattern)

**Deliverables**:

Tests:
- [ ] `HiddenHistoryTests/Presentation/MapViewModelTests.swift` — tests: initial state is empty/not loading, `loadSites(near:)` sets `isLoading = true` then `false`, success populates `sites`, error sets `error`, analytics `map_loaded` event fired.

Implementation:
- [ ] `Presentation/Map/MapViewModel.swift` — `@Observable` class: `sites`, `isLoading`, `error`, `selectedSite`, `userLocation`. Methods: `loadSites(near:)`, `loadSitesInViewport(region:)`, `selectSite(_:)`. Fires `map_loaded` and `pin_tapped` analytics events.
- [ ] `Presentation/Map/MapView.swift` — SwiftUI `Map` (MapKit), shows `SitePin` annotations for each site, user location dot, calls `mapViewModel.loadSitesInViewport` on region change, tapping pin sets `selectedSite` and presents `SiteDetailView` as sheet.
- [ ] `Presentation/Map/Pins/SitePin.swift` — custom `MapAnnotation`: teardrop shape, amber for unvisited, green for visited, scale animation on selection. Exact spec from DESIGN_SYSTEM.md.
- [ ] `Presentation/Map/Pins/ClusterPin.swift` — circle with count label, purple fill per DESIGN_SYSTEM.md.
- [ ] All ViewModel tests pass. MapView has `#Preview` with mock data.

---

## STEP 11 — SiteDetail ViewModel & View (TDD ViewModel)

**Status**: `NOT STARTED`

**Goal**: The full-screen site detail view — text, image, audio trigger, save/unsave.

**Context**: `docs/DESIGN_SYSTEM.md` (Place Card — Expanded section), `docs/ONBOARDING_ANALYTICS.md` (Core Discovery Events), `docs/MONETIZATION.md` (Feature Gating Pattern)

**Deliverables**:

Tests:
- [ ] `HiddenHistoryTests/Presentation/SiteDetailViewModelTests.swift` — tests: `onAppear` checks entitlement, `canPlayPremiumAudio` reflects entitlement, `saveSite()` calls use case, `saveSite()` presents paywall when limit hit, analytics events fired.

Implementation:
- [ ] `Presentation/SiteDetail/SiteDetailViewModel.swift` — `@Observable`: `site`, `canPlayPremiumAudio`, `isSaved`, `isLoadingAudio`. Methods: `onAppear(site:)`, `saveSite()`, `unsaveSite()`, `startListening()`. Fires `site_detail_viewed`, `site_saved`, `site_unsaved`.
- [ ] `Presentation/SiteDetail/SiteDetailView.swift` — full-screen view: hero image (edge-to-edge, 240pt), category chips (horizontal scroll), site name (`displayLarge`), metadata row (distance · duration · era), description text, mini-map (160pt MapKit embed), related sites carousel (placeholder for MVP), sticky "Listen" button at bottom. All layout from DESIGN_SYSTEM.md.
- [ ] All ViewModel tests pass. View has `#Preview`.

---

## STEP 12 — AudioPlayer ViewModel & View (TDD ViewModel)

**Status**: `NOT STARTED`

**Goal**: The persistent audio player bar with collapsed and expanded states.

**Context**: `docs/DESIGN_SYSTEM.md` (Audio Player Bar — full spec), `docs/ONBOARDING_ANALYTICS.md` (Core Discovery Events — audio events), `docs/DATA_ARCHITECTURE.md` (Audio Flow)

**Deliverables**:

Tests:
- [ ] `HiddenHistoryTests/Presentation/AudioPlayerViewModelTests.swift` — tests: state machine transitions (idle → loading → playing → paused → idle), `play()` calls `PlayAudioUseCase`, `pause()` pauses AVPlayer, `seek(to:)` updates position, `skipForward15()` and `skipBack15()` adjust position, analytics events fired at correct states.

Implementation:
- [ ] `Presentation/AudioPlayer/AudioPlayerViewModel.swift` — `@Observable`, state enum (`idle/loading/playing/paused/error`), `currentSite`, `progress` (0–1), `currentTime`, `duration`, `playbackSpeed` (0.75/1/1.25/1.5/2). Uses `AVPlayer` internally. Fires `audio_play_started`, `audio_paused`, `audio_resumed`, `audio_completed`, `audio_abandoned`.
- [ ] `Presentation/AudioPlayer/AudioPlayerView.swift` — collapsed bar (72pt, thumbnail, title, progress line, play/pause button) AND expanded sheet (hero image, site name, time display, progress bar with thumb, controls row, speed picker, share + download icons). Exact spec from DESIGN_SYSTEM.md.
- [ ] All ViewModel tests pass. View has `#Preview` for both collapsed and expanded states.

---

## STEP 13 — Shared UI Components

**Status**: `NOT STARTED`

**Goal**: Implement all reusable components referenced across views.

**Context**: `docs/DESIGN_SYSTEM.md` (Place Card Compact, Category Chips, Bottom Navigation, Buttons, Text Input)

**Deliverables**:
- [ ] `Presentation/Shared/PlaceCard.swift` — compact card (120pt height, thumbnail, chip, name, distance+era, short bio snippet). Tap feedback: 0.98 scale spring.
- [ ] `Presentation/Shared/CategoryChip.swift` — 30pt height chip, default/selected/disabled states, category colour accents per DESIGN_SYSTEM.md.
- [ ] `Presentation/Shared/LoadingView.swift` — simple spinner using `HHColors.accent`.
- [ ] `Core/DesignSystem/Components/HHPrimaryButton.swift` — `ButtonStyle` conformance: 56pt height, accent fill, headline white text, 12pt radius, press state (0.94 opacity, 0.97 scale).
- [ ] `Core/DesignSystem/Components/HHSecondaryButton.swift` — 48pt, transparent, 1.5pt border, title text style.
- [ ] `Core/DesignSystem/Components/MainTabView.swift` — 4-tab bar (Discover, Map, Saved, Profile), accent active color, tertiary inactive, 0.2s crossfade on switch, per DESIGN_SYSTEM.md Bottom Navigation spec.
- [ ] Each component has a `#Preview`.

---

## STEP 14 — Onboarding Flow: Screens 1–4

**Status**: `NOT STARTED`

**Goal**: Implement the first half of onboarding (Splash, Value Prop carousel, Location permission, Notification permission).

**Context**: `docs/ONBOARDING_ANALYTICS.md` (Screens 1–4, analytics events), `docs/DESIGN_SYSTEM.md` (Buttons, Typography)

**Deliverables**:
- [ ] `Presentation/Onboarding/SplashView.swift` — full-screen Deep Slate background, centred icon + wordmark + tagline, 0.4s fade-in, auto-advances after 2s, fires `onboarding_splash_viewed`.
- [ ] `Presentation/Onboarding/ValuePropView.swift` — 3-card horizontal swipe carousel with page dots, skip button (top-right), "Get Started" + "I already have an account" on last card. Card content exactly from ONBOARDING_ANALYTICS.md. Fires `onboarding_value_prop_viewed` per card and `onboarding_value_prop_skipped`.
- [ ] `Presentation/Onboarding/PermissionsView.swift` — location permission pre-prompt screen (screen 3): illustration area, headline, body, "Allow Location Access" primary button (triggers `CLLocationManager.requestWhenInUseAuthorization`), "Not Now" link. Fires `location_permission_screen_viewed` and `location_permission_result`.
- [ ] `Presentation/Onboarding/NotificationPermView.swift` — notification permission pre-prompt screen (screen 4): illustration area, headline, body, "Turn On Notifications" primary button (triggers `UNUserNotificationCenter.requestAuthorization`), "Skip for Now" link. Only shown if location granted. Fires `notification_permission_screen_viewed` and `notification_permission_result`.
- [ ] `App/RootView.swift` updated — shows `SplashView` → `ValuePropView` → `PermissionsView` → `NotificationPermView` → (then auth, step 15).
- [ ] All views have `#Preview`.

---

## STEP 15 — Onboarding Flow: Screens 5–7 (Auth, Interests, Paywall)

**Status**: `NOT STARTED`

**Goal**: Implement auth screen, interest selection, and soft paywall.

**Context**: `docs/ONBOARDING_ANALYTICS.md` (Screens 5–7), `docs/MONETIZATION.md` (PaywallView, Paywall Trigger Points), `docs/DESIGN_SYSTEM.md` (Buttons)

**Deliverables**:
- [ ] `Presentation/Onboarding/AuthView.swift` — Apple Sign In button (full-width, ASAuthorizationAppleIDButton), divider "or", email field + "Continue with email" button, "Already have an account? Sign in" footer, privacy/terms links. Fires all auth analytics events from ONBOARDING_ANALYTICS.md.
- [ ] `Presentation/Onboarding/InterestsView.swift` — era chips (multi-select, 8 options) + category chips (multi-select, 7 options) per ONBOARDING_ANALYTICS.md, "Feeling lucky" button, "Let's go" primary button. Fires `interests_screen_viewed` and `interests_selected`.
- [ ] `Presentation/Onboarding/PaywallView.swift` — trial badge, headline, 3-feature rows, monthly/annual product selector toggle, "Start Free Trial" primary button, "Continue with free plan" skip link. Exact layout from MONETIZATION.md code sample. Fires `paywall_shown`, `paywall_cta_tapped`, `paywall_dismissed`. Accepts `PaywallSource` enum parameter.
- [ ] `App/OnboardingCoordinator.swift` — `@Observable` class managing the full 7-screen onboarding state machine, guards subsequent launches with `hasCompletedOnboarding` in UserDefaults.
- [ ] `App/RootView.swift` updated — shows `OnboardingCoordinator`-driven flow if not completed, else `MainTabView`.
- [ ] All views have `#Preview`.

---

## STEP 16 — Saved & Profile Screens (TDD ViewModels)

**Status**: `NOT STARTED`

**Goal**: Implement the Saved and Profile tabs.

**Context**: `docs/MASTER_PLAN.md` (Presentation/Saved, Presentation/Profile), `docs/MONETIZATION.md` (Free vs Premium Feature Matrix — Organisation section), `docs/ONBOARDING_ANALYTICS.md` (Engagement events)

**Deliverables**:

Tests:
- [ ] `HiddenHistoryTests/Presentation/SavedViewModelTests.swift` — tests: loads saved sites on appear, unsave removes from list, free-tier limit enforcement.
- [ ] `HiddenHistoryTests/Presentation/ProfileViewModelTests.swift` — tests: loads user profile, sign-out calls `AuthRepository.signOut` and resets analytics.

Implementation:
- [ ] `Presentation/Saved/SavedViewModel.swift` — `@Observable`: `savedSites`, `isLoading`. Methods: `loadSaved()`, `unsave(site:)`. Shows paywall if free limit hit on save attempt.
- [ ] `Presentation/Saved/SavedView.swift` — scrollable list of `PlaceCard` (compact), empty state with "Discover your first site" CTA, swipe-to-delete.
- [ ] `Presentation/Profile/ProfileViewModel.swift` — `@Observable`: `userProfile`, `isPremium`, `totalListens`, `totalSitesVisited`. Methods: `loadProfile()`, `signOut()`, `manageSubscription()`.
- [ ] `Presentation/Profile/ProfileView.swift` — avatar initial + name, subscription status badge, stats row (listens/sites), "Manage Subscription" row, "Sign Out" button, app version footer.
- [ ] All ViewModel tests pass. Views have `#Preview`.

---

## STEP 17 — Supabase Edge Function: `generate-audio`

**Status**: `NOT STARTED`

**Goal**: Implement the TypeScript/Deno Edge Function that generates both free (Polly) and premium (ElevenLabs) audio narrations and uploads to Storage.

**Context**: `docs/DATA_ARCHITECTURE.md` (Edge Function: generate-audio, Storage Structure, Narration Script Guidelines)

**Deliverables**:
- [ ] `supabase/functions/generate-audio/index.ts` — full implementation: fetch site from DB, call `buildNarrationScript()`, call AWS Polly SDK, call ElevenLabs REST API, upload both MP3s to `narrations/` bucket with `Cache-Control: public, max-age=31536000`, update `audio_url_free`, `audio_url_premium`, `audio_duration_sec`, `audio_generated_at` in DB.
- [ ] `supabase/functions/generate-audio/tests/generate-audio.test.ts` — Deno tests: `buildNarrationScript` truncates at 1500 chars, script opens with site name, upload path is correct format.
- [ ] `deno.json` import map in the function folder.
- [ ] All Deno tests pass: `deno test supabase/functions/generate-audio/tests/`.

---

## STEP 18 — Supabase Edge Function: `enrich-site`

**Status**: `NOT STARTED`

**Goal**: Edge Function that fetches Wikipedia content for a newly inserted site and triggers audio generation.

**Context**: `docs/DATA_ARCHITECTURE.md` (Edge Function: enrich-site, Wikipedia REST API section)

**Deliverables**:
- [ ] `supabase/functions/enrich-site/index.ts` — fetches Wikipedia summary by `wikipedia_id` or searches by `name + city`, stores `description`, `short_bio`, `hero_image_url` in DB, triggers `generate-audio` function.
- [ ] `supabase/functions/enrich-site/tests/enrich-site.test.ts` — tests: Wikipedia URL construction, description truncation to 500 chars for `short_bio`, hero image URL extraction, graceful handling of 404 (site not found on Wikipedia).
- [ ] DB webhook trigger SQL in `supabase/migrations/009_enrich_trigger.sql` — `AFTER INSERT ON historical_sites WHERE description IS NULL` → calls `enrich-site` via `net.http_post`.
- [ ] All Deno tests pass.

---

## STEP 19 — Supabase Edge Function: `sync-osm`

**Status**: `NOT STARTED`

**Goal**: Nightly cron function that imports London + NYC `historic=*` sites from OSM Overpass API.

**Context**: `docs/DATA_ARCHITECTURE.md` (OSM Overpass API section, Deduplication, Nightly Sync Cron)

**Deliverables**:
- [ ] `supabase/functions/sync-osm/index.ts` — accepts `{ city: "london" | "nyc" }`, builds Overpass bbox query, fetches all `historic=*` nodes/ways/relations, deduplicates against existing DB rows (exact `osm_id` match → skip, name trigram + 50m distance → flag for review), batch-upserts new records with `source = "osm"`, `verified = false`.
- [ ] `supabase/functions/sync-osm/tests/sync-osm.test.ts` — tests: Overpass query is correctly built for each city, dedup logic skips exact osm_id match, new records are inserted, malformed Overpass responses handled.
- [ ] `supabase/migrations/010_cron.sql` — `pg_cron` schedule running `sync-osm` at 02:00 UTC for London and 02:30 UTC for NYC.
- [ ] All Deno tests pass.

---

## STEP 20 — Data Seeding Script

**Status**: `NOT STARTED`

**Goal**: A one-shot script that seeds ~500 verified historical sites for London + NYC using Wikidata SPARQL + Wikipedia enrichment, to have real data from day 1.

**Context**: `docs/DATA_ARCHITECTURE.md` (Wikidata SPARQL section, Wikipedia REST API, Data Quality — Verification Levels)

**Deliverables**:
- [ ] `scripts/seed-sites.ts` — Deno script (not a Supabase function): queries Wikidata SPARQL for historic buildings/monuments in London + NYC bounding boxes (use the sample query from DATA_ARCHITECTURE.md adapted for UK/US), fetches Wikipedia summary for each, upserts into `historical_sites` with `verified = true`, `source = "wikidata"`.
- [ ] `scripts/README.md` — instructions: `deno run --allow-net --allow-env scripts/seed-sites.ts`
- [ ] Script runs successfully and inserts ≥ 500 rows (validate with a count query).

---

## STEP 21 — RevenueCat Webhooks Edge Function

**Status**: `NOT STARTED`

**Goal**: Handle RevenueCat server-to-server webhooks to keep `user_history` subscription state in sync.

**Context**: `docs/MONETIZATION.md` (Webhooks Phase 2, Revenue Flow)

**Deliverables**:
- [ ] `supabase/functions/revenuecat-webhook/index.ts` — handles `INITIAL_PURCHASE`, `RENEWAL`, `CANCELLATION`, `EXPIRATION` events. Updates `auth.users` metadata `plan` field accordingly. Validates webhook auth header.
- [ ] `supabase/functions/revenuecat-webhook/tests/webhook.test.ts` — tests: each event type updates the correct field, invalid auth header returns 401, unknown event type is ignored.
- [ ] All Deno tests pass.

---

## STEP 22 — Push Notifications

**Status**: `NOT STARTED`

**Goal**: Register for push notifications and handle "nearby site" notification tap.

**Context**: `docs/ONBOARDING_ANALYTICS.md` (Screen 4 — Notification Permission, notification events), `docs/MASTER_PLAN.md` (Phase 4 — Push notifications)

**Deliverables**:
- [ ] `App/AppDelegate.swift` — `UIApplicationDelegate`: registers APNs token with Supabase Auth, handles `UNUserNotificationCenterDelegate` for foreground notifications.
- [ ] `Core/Utils/NotificationManager.swift` — requests permission (wraps `UNUserNotificationCenter.requestAuthorization`), schedules and cancels local "nearby site" notifications, fires `notification_received` and `notification_tapped` analytics events.
- [ ] `Presentation/Shared/NotificationHandler.swift` — handles tapping a push notification that contains a `site_id` → navigates to `SiteDetailView` for that site.
- [ ] Build succeeds. Push notification flow can be tested on device.

---

## STEP 23 — Offline Audio Download (Premium)

**Status**: `NOT STARTED`

**Goal**: Allow premium users to download audio narrations for offline playback.

**Context**: `docs/MONETIZATION.md` (Offline audio download feature), `docs/DATA_ARCHITECTURE.md` (Audio Cache, Storage Structure)

**Deliverables**:
- [ ] `Data/Local/AudioCache.swift` updated — add `download(siteId:tier:fromURL:progressHandler:) async throws -> URL` using `AVAssetDownloadURLSession`. Track download state per `siteId+tier`.
- [ ] `HiddenHistoryTests/Data/Local/AudioCacheTests.swift` — tests: `cachedURL` returns nil for uncached, returns local URL after download, `deleteAll()` removes files.
- [ ] `Presentation/AudioPlayer/AudioPlayerViewModel.swift` updated — expose `downloadState` (notDownloaded/downloading(progress)/downloaded), `downloadAudio()` method that checks entitlement (shows paywall if free), delegates to `AudioCache`.
- [ ] `Presentation/AudioPlayer/AudioPlayerView.swift` updated — download button in expanded view shows state (cloud icon → progress ring → checkmark), fires `offline_pack_downloaded` analytics.
- [ ] All new tests pass.

---

## STEP 24 — GitHub Actions CI

**Status**: `NOT STARTED`

**Goal**: Set up automated CI that runs on every push to `main` and `develop` and all PRs.

**Context**: `docs/METHODOLOGY.md` (CI / GitHub Actions section)

**Deliverables**:
- [ ] `.github/workflows/ci.yml` — triggers: push to `main`/`develop`, PRs to `main`/`develop`. Steps: checkout, select latest stable Xcode, resolve SPM packages, build (Debug), run unit tests, run UI tests (iPhone 16 sim), report coverage, fail if Domain coverage < 85%.
- [ ] `.github/workflows/edge-functions.yml` — triggers: changes to `supabase/functions/**`. Steps: install Deno, run `deno test` for all functions.
- [ ] `.github/workflows/` validated (no YAML syntax errors). CI passes on clean repo.

---

## STEP 25 — Accessibility & Dark Mode Polish

**Status**: `NOT STARTED`

**Goal**: Ensure all views meet the accessibility and dark mode requirements from the design system.

**Context**: `docs/DESIGN_SYSTEM.md` (Accessibility, Dark Mode), `docs/METHODOLOGY.md` (iOS minimum version iOS 16)

**Deliverables**:
- [ ] All interactive elements verified to have ≥ 44×44pt touch targets (`HHSpacing.minTouchTarget`).
- [ ] All `Image` and icon views have `accessibilityLabel` set.
- [ ] `MapView` pins have `accessibilityLabel` = "\(site.name), \(distanceFormatted) away".
- [ ] `AudioPlayerView` controls have `accessibilityHint` (e.g. "Skip back 15 seconds").
- [ ] All views respect `@Environment(\.accessibilityReduceMotion)` — spring animations replaced with `.animation(nil)` when reduce motion is on.
- [ ] Dark mode verified: `MapView` passes `.colorScheme == .dark ? .dark : .light` to `Map`. All adaptive colors from `Assets.xcassets` render correctly in dark preview.
- [ ] Dynamic Type: all `HHTypography` text styles scale correctly (use `.scaledFont` or `@ScaledMetric` where needed).
- [ ] XCUITest smoke test added: UI test 4 from METHODOLOGY.md (paywall appears on 6th free listen attempt).

---

## STEP 26 — App Store Connect & TestFlight Prep

**Status**: `NOT STARTED`

**Goal**: Configure everything needed to submit to TestFlight for beta testing.

**Context**: `docs/MASTER_PLAN.md` (Phase 4 — App Store Connect), `docs/MONETIZATION.md` (Products)

**Deliverables**:
- [ ] `Resources/Assets.xcassets` — app icon set for all required sizes (1024×1024 App Store, all device sizes).
- [ ] `Info.plist` — all required usage description keys: `NSLocationWhenInUseUsageDescription`, `NSMicrophoneUsageDescription` (if needed), `NSUserNotificationsUsageDescription`.
- [ ] App Store Connect: create 3 IAP products (`hidden_history_premium_monthly`, `hidden_history_premium_annual`, `hidden_history_lifetime`) with 7-day trial on monthly.
- [ ] RevenueCat dashboard: configure `premium_access` entitlement, `default` offering, `onboarding_offer` offering.
- [ ] PostHog: create all 5 feature flags from ONBOARDING_ANALYTICS.md.
- [ ] `Config.xcconfig` filled with real API keys (not committed — documented in `.xcconfig.example`).
- [ ] Archive builds successfully. Upload to TestFlight succeeds.

---

## Summary Table

> Agents: scan this table first. Find the first `NOT STARTED` or `IN PROGRESS` row and go to that step.

| Step | Name | Layer | TDD Required | Status |
|------|------|-------|-------------|--------|
| 0 | Xcode Project Skeleton | Foundation | — | `NOT STARTED` |
| 1 | Design System Tokens | Core | — | `NOT STARTED` |
| 2 | Analytics Helper + App Entry | Core | — | `NOT STARTED` |
| 3 | Supabase Schema & Migrations | Backend | — | `NOT STARTED` |
| 4 | Domain Entities | Domain | Yes | `NOT STARTED` |
| 5 | Domain Repository Protocols | Domain | — | `NOT STARTED` |
| 6 | Domain Use Cases | Domain | Yes | `NOT STARTED` |
| 7 | Data Layer: DTOs & Supabase Client | Data | Yes | `NOT STARTED` |
| 8 | Data Layer: Repository Implementations | Data | Yes | `NOT STARTED` |
| 9 | Data Layer: Auth & Entitlements | Data | Yes | `NOT STARTED` |
| 10 | Map ViewModel & MapView | Presentation | Yes (VM) | `NOT STARTED` |
| 11 | SiteDetail ViewModel & View | Presentation | Yes (VM) | `NOT STARTED` |
| 12 | AudioPlayer ViewModel & View | Presentation | Yes (VM) | `NOT STARTED` |
| 13 | Shared UI Components | Presentation | — | `NOT STARTED` |
| 14 | Onboarding Screens 1–4 | Presentation | — | `NOT STARTED` |
| 15 | Onboarding Screens 5–7 (Auth, Interests, Paywall) | Presentation | — | `NOT STARTED` |
| 16 | Saved & Profile Screens | Presentation | Yes (VM) | `NOT STARTED` |
| 17 | Edge Function: generate-audio | Backend | Yes (Deno) | `NOT STARTED` |
| 18 | Edge Function: enrich-site | Backend | Yes (Deno) | `NOT STARTED` |
| 19 | Edge Function: sync-osm | Backend | Yes (Deno) | `NOT STARTED` |
| 20 | Data Seeding Script | Backend | — | `NOT STARTED` |
| 21 | RevenueCat Webhooks | Backend | Yes (Deno) | `NOT STARTED` |
| 22 | Push Notifications | iOS | — | `NOT STARTED` |
| 23 | Offline Audio Download | iOS + Data | Yes | `NOT STARTED` |
| 24 | GitHub Actions CI | DevOps | — | `NOT STARTED` |
| 25 | Accessibility & Dark Mode | iOS | — | `NOT STARTED` |
| 26 | App Store & TestFlight Prep | Release | — | `NOT STARTED` |
