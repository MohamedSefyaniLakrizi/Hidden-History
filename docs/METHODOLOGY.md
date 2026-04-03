# Hidden History — Development Methodology

> **For agents**: This document defines the non-negotiable rules for how code is written,
> tested, and committed in this project. Read this before writing any implementation code.
> When in doubt, this document takes precedence.

---

## Core Principle: Test-Driven Development (TDD)

**Tests are written before the implementation code, always.**

This is not optional. Every new `*.swift` implementation file in `Domain/` or `Data/` must
have a corresponding test file written and failing before the implementation begins.

### The TDD Cycle

```
1. RED    →  Write a failing test that precisely describes the desired behaviour
2. GREEN  →  Write the minimum code necessary to make the test pass
3. REFACTOR → Clean up the code while keeping all tests green
```

Never skip straight to GREEN. If you find yourself writing implementation code with no
associated failing test, stop and write the test first.

---

## What Gets TDD

| Layer | Test Type | Requirement |
|-------|-----------|-------------|
| `Domain/Entities/` | Swift Testing unit tests | MUST |
| `Domain/UseCases/` | Swift Testing unit tests | MUST |
| `Domain/Repositories/` (protocols) | n/a (protocols have no logic) | — |
| `Data/Repositories/` | XCTest with mocked protocols | MUST |
| `Data/Remote/DTOs/` | Swift Testing (Codable round-trip) | MUST |
| `Presentation/*/ViewModel` | Swift Testing unit tests | MUST |
| `Presentation/*/View` | XCUITest smoke tests | SHOULD (critical flows) |
| `Core/DesignSystem/` | Visual snapshot tests (optional) | MAY |
| Edge Functions (TypeScript) | Deno test runner | MUST for business logic |

---

## Test File Conventions

### Naming
- Source file: `FetchNearbySitesUseCase.swift`
- Test file:   `FetchNearbySitesUseCaseTests.swift`
- Test files mirror the source tree under `HiddenHistoryTests/`

### Structure (Swift Testing)

```swift
// HiddenHistoryTests/Domain/UseCases/FetchNearbySitesUseCaseTests.swift

import Testing
@testable import HiddenHistory

@Suite("FetchNearbySitesUseCase")
struct FetchNearbySitesUseCaseTests {

    // Arrange shared dependencies
    var mockRepository: MockSiteRepository
    var useCase: FetchNearbySitesUseCase

    init() {
        mockRepository = MockSiteRepository()
        useCase = FetchNearbySitesUseCase(repository: mockRepository)
    }

    @Test("returns sites within the given radius")
    func returnsNearby() async throws {
        // Arrange
        let london = Coordinate(lat: 51.5074, lng: -0.1278)
        mockRepository.stubbedSites = [
            .stub(lat: 51.5080, lng: -0.1270),  // ~90m away — should be included
            .stub(lat: 51.6000, lng: -0.1278),  // ~10km away — should be excluded
        ]

        // Act
        let result = try await useCase.execute(near: london, radiusMeters: 500)

        // Assert
        #expect(result.count == 1)
    }

    @Test("throws when repository fails")
    func throwsOnRepositoryError() async {
        mockRepository.shouldThrow = true
        await #expect(throws: SiteError.fetchFailed) {
            try await useCase.execute(near: .london, radiusMeters: 500)
        }
    }
}
```

### Mocking Pattern

Use protocol-based mocks. **No live network calls in unit tests.**

```swift
// HiddenHistoryTests/Mocks/MockSiteRepository.swift

final class MockSiteRepository: SiteRepositoryProtocol {
    var stubbedSites: [HistoricalSite] = []
    var shouldThrow = false

    func fetchNearbySites(near coordinate: Coordinate, radiusMeters: Double) async throws -> [HistoricalSite] {
        if shouldThrow { throw SiteError.fetchFailed }
        return stubbedSites
    }
}
```

### Test Data Helpers

Use static `.stub(...)` factory methods on domain entities for test data:

```swift
extension HistoricalSite {
    static func stub(
        id: UUID = UUID(),
        name: String = "Test Site",
        lat: Double = 51.5074,
        lng: Double = -0.1278,
        era: Era = .victorian
    ) -> HistoricalSite {
        HistoricalSite(id: id, name: name, coordinate: .init(lat: lat, lng: lng), era: era)
    }
}
```

---

## Coverage Targets

| Layer | Target | Minimum |
|-------|--------|---------|
| `Domain/` | 90% | 85% |
| `Data/` | 80% | 75% |
| `Presentation/ViewModels` | 75% | 70% |
| `Presentation/Views` | Smoke tests only | — |

Coverage is measured per CI run. Falling below minimum on `Domain/` blocks a merge to main.

---

## XCUITest Smoke Tests

UI tests cover the **critical happy paths** only — not exhaustive edge cases.

Required smoke tests:
1. Onboarding completes and lands on Map
2. Tapping a map pin opens Site Detail
3. Tapping "Listen" starts audio playback
4. Paywall appears when a free-tier user hits the limit
5. Subscription purchase flow completes (StoreKit test environment)

---

## Architecture Rules

### Clean Architecture Layers

```
Domain  →  no imports of UIKit, SwiftUI, Supabase, or any third-party framework
           Only Swift standard library + Foundation
           This makes it trivially testable

Data    →  implements Domain protocols
           May import Supabase SDK, AVFoundation, etc.
           Must be fully mockable from tests via protocol injection

Presentation →  imports SwiftUI only (plus Domain entities/use cases via protocol)
                ViewModels are plain @Observable classes (no SwiftUI in ViewModel)
                Views are thin — no business logic
```

### Dependency Injection

All dependencies are injected via initialiser parameters. **No singletons in Domain or Data layers.**

```swift
// Good
final class FetchNearbySitesUseCase {
    private let repository: SiteRepositoryProtocol
    init(repository: SiteRepositoryProtocol) { self.repository = repository }
}

// Bad — untestable
final class FetchNearbySitesUseCase {
    func execute() async throws { SupabaseClient.shared.query(...) }
}
```

Service location / dependency graph is assembled in `App/DependencyContainer.swift`.

### ViewModel Pattern

```swift
@Observable
final class MapViewModel {
    // State — read by View
    private(set) var sites: [HistoricalSite] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    // Dependencies — injected
    private let fetchSites: FetchNearbySitesUseCase

    init(fetchSites: FetchNearbySitesUseCase) {
        self.fetchSites = fetchSites
    }

    // Intent — called by View
    func loadSites(near coordinate: Coordinate) async {
        isLoading = true
        defer { isLoading = false }
        do {
            sites = try await fetchSites.execute(near: coordinate, radiusMeters: 2000)
        } catch {
            self.error = error
        }
    }
}
```

---

## Git Workflow

### Branch Strategy (Solo Developer)

```
main          — production-ready, protected (no direct push)
develop       — integration branch, all feature branches merge here
feature/*     — one feature per branch (e.g. feature/audio-player)
fix/*         — bug fixes
chore/*       — tooling, dependencies, refactoring
docs/*        — documentation only
```

### Commit Message Format

Use Conventional Commits:

```
<type>(<scope>): <short description>

[optional body]

[optional footer]
```

Types:
- `feat` — new feature
- `fix` — bug fix
- `test` — adding or updating tests (use this when writing TDD tests before implementation)
- `refactor` — code change that neither fixes a bug nor adds a feature
- `chore` — build system, dependencies
- `docs` — documentation changes
- `perf` — performance improvement

Examples:
```
test(domain): add FetchNearbySitesUseCase tests (TDD step 1 — RED)
feat(domain): implement FetchNearbySitesUseCase (TDD step 2 — GREEN)
refactor(domain): simplify distance filtering logic (TDD step 3 — REFACTOR)

test(presentation): add MapViewModel state machine tests
feat(presentation): implement MapViewModel with site loading
```

### TDD Commit Sequence

For every new feature, commit in this exact order:
1. `test(<scope>): add <FeatureName> tests (RED)` — failing tests only, no implementation
2. `feat(<scope>): implement <FeatureName> (GREEN)` — minimal implementation to pass
3. `refactor(<scope>): <description> (REFACTOR)` — if cleanup is needed

This makes the TDD progression visible in git history.

---

## Code Standards

### Swift Style

- **Formatting**: Use Swift Format with the project's `.swift-format` config
- **Naming**: Follow Swift API Design Guidelines
  - Types: `UpperCamelCase`
  - Functions/variables: `lowerCamelCase`
  - Constants: `lowerCamelCase` (no ALL_CAPS)
  - Protocols: noun (e.g. `SiteRepository`) or adjective (e.g. `Cacheable`)
- **Access control**: be explicit — `private`, `fileprivate`, `internal`, `public`
- **Async/await**: always prefer over completion handlers or Combine for new code
- **Error handling**: typed errors using enums conforming to `Error`, never `Error` as a bare type

### Prohibited Patterns

- ❌ No `UserDefaults` for anything other than simple UI preferences
- ❌ No `NotificationCenter` for business logic (use delegate protocols or async streams)
- ❌ No force unwrapping (`!`) except in test files and SwiftUI previews
- ❌ No hardcoded color or font values — always use `HHColors` / `HHTypography`
- ❌ No hardcoded spacing values — always use `HHSpacing` / `HHRadius`
- ❌ No network calls in ViewModels (delegate to Use Cases → Repositories)
- ❌ No business logic in SwiftUI Views
- ❌ No `print()` in production code — use `Logger` (OSLog)

### SwiftUI View Rules

- Views are structs, always
- Views declare their dependencies as constructor parameters (no `@EnvironmentObject` except for globally shared state like auth)
- Extract subviews aggressively — any view body exceeding ~60 lines should be split
- Use `@ViewBuilder` for conditional content, not ternary operators returning `AnyView`
- Preview every view with `#Preview` macro (at least one light + one dark)

---

## CI / GitHub Actions

### Workflow: `.github/workflows/ci.yml`

Triggers: push to `main`, push to `develop`, all PRs targeting `main` or `develop`

Steps:
1. Checkout
2. Select Xcode version (latest stable)
3. Resolve SPM packages
4. Build (Debug) — `xcodebuild build`
5. Run unit tests — `xcodebuild test -scheme HiddenHistoryTests`
6. Run UI tests (on iPhone 16 simulator) — `xcodebuild test -scheme HiddenHistoryUITests`
7. Report code coverage
8. Fail if Domain coverage < 85%

### Edge Function Tests

Supabase Edge Functions (TypeScript/Deno) run their own test suite:
- Framework: Deno's built-in test runner
- Location: `supabase/functions/*/tests/`
- Run: `deno test` in CI after function changes

---

## Dependency Management

### iOS (Swift Package Manager only — no CocoaPods, no Carthage)

Add packages in Xcode or `Package.swift`. Lock file (`Package.resolved`) is committed.

Required packages:
- `supabase/supabase-swift` — Supabase client
- `RevenueCat/purchases-ios` — RevenueCat subscriptions
- `PostHog/posthog-ios` — PostHog analytics
- Inter font files (bundled as resources, not a package)

### Backend (Deno — no npm, no node_modules in functions)

Import via URL or `deno.json` import map. Lockfile (`deno.lock`) committed.

---

## Environment Configuration

Never commit secrets. Use:
- iOS: `Config.xcconfig` files (excluded from git) + Xcode build settings
- Backend: Supabase project secrets (set via Supabase dashboard, accessed in Edge Functions via `Deno.env.get()`)

Required iOS environment variables:

```
SUPABASE_URL
SUPABASE_ANON_KEY
REVENUECAT_API_KEY
POSTHOG_API_KEY
```

These are injected at build time via `Config.xcconfig` (gitignored) and accessed in Swift via a `Config.swift` wrapper that reads `Bundle.main.infoDictionary`.

---

## Documentation Standards

- Public interfaces (protocols, use case execute methods) get a one-line doc comment
- Complex algorithms get inline comments explaining the *why*, not the *what*
- No doc comments on private implementation details unless the logic is genuinely surprising
- This `/docs/` folder is the source of truth — keep it up to date when decisions change
