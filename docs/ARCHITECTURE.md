# Architecture, privacy & performance

## Layers

```
App (entry, RootView, tab bar, lock, FeatureFlags)
  └─ Features (Today / Insights / Me / History / Onboarding)  ← SwiftUI views
        └─ Gamification (pure engines + GamificationService)   ← no UIKit/SwiftUI
        └─ Services (AICoach, Haptics)
  └─ Models (SwiftData @Model + enums + Badge catalog)
  └─ Persistence (ModelContainer + Seed)
  └─ Theme / Components (design system + reusable views)
```

The **gamification engines are pure value-logic** (no UI imports), which is why they're
unit-tested directly. Views own no business rules — they read SwiftData via `@Query`
and call `GamificationService`.

## Data model (SwiftData)

| Model | Purpose | Notable |
|---|---|---|
| `Entry` | one day's loop | `day` normalized to start-of-day; `@Attribute(.externalStorage) photo`; `text(for:)/setText(for:)` |
| `Habit` | a tracked habit | `@Relationship(.cascade, inverse: \HabitLog.habit) logs`; `xpValue` |
| `HabitLog` | completion on a day | back-reference to `Habit` |
| `UserProgress` | single-row state | XP, streaks, unlocks, prefs (`accentColorHex`, `theme`), `levelInfo` computed |
| `XPTransaction` | XP ledger | reason + multiplier (powers history/insights) |
| `BadgeRecord` | earned badge | `badgeID` → `BadgeCatalog` |

`AppModelContainer.shared` builds the container from a single `Schema`; `Seed.ensure`
creates the `UserProgress` row and starter habits on first launch.

## State & data flow

- `@main GrowlyApp` injects the container via `.modelContainer`.
- `RootView` decides Onboarding → Face ID lock → `MainTabView`, applies the user's
  accent (`.tint`) and theme (`.preferredColorScheme`).
- Views use `@Query` for reads and `@Bindable` on `@Model` objects so text fields bind
  straight to the store; writes are saved via the `modelContext`.
- Completing a review is the one orchestrated mutation: `GamificationService` updates
  `UserProgress`, inserts an `XPTransaction`, evaluates and inserts new `BadgeRecord`s,
  and returns a `ReviewResult` for the celebration.

## Privacy

- **On-device only.** All data lives in the local SwiftData store; no network calls, no
  analytics, no account.
- **No data leaves the device** unless the user explicitly exports/shares.
- **Face ID lock** (`LocalAuthentication`, `.deviceOwnerAuthentication`) is optional and
  fails open only when no biometrics/passcode exist (never locks the user out).
- The "AI" coach is **local heuristics** — no prompts are sent anywhere. (When
  `appleIntelligence` is enabled it would use on-device FoundationModels.)
- Photos are stored with `@Attribute(.externalStorage)` so large blobs stay out of the
  primary store.

## Performance

- Pure-Swift engines run in microseconds; no work on the main thread beyond UI.
- `@Query` fetches are scoped and sorted in the store; History uses `LazyVStack` so rows
  render on demand. (For very large stores, switch to a windowed/predicate query.)
- Celebrations/confetti are short, `transform`/`opacity`-only animations and are fully
  disabled under Reduce Motion.
- No retain cycles: views hold `@Query`/`@Bindable` references managed by SwiftData; the
  service is a stateless `@MainActor enum`.

## Build & signing

- Project generated from `project.yml` (XcodeGen) → no committed `.xcodeproj`.
- CI builds **unsigned** (`CODE_SIGNING_ALLOWED=NO`) and packages a `Payload/*.app` zip
  into an `.ipa`; Sideloadly re-signs on-device with a free Apple ID.
- Entitlement-gated capabilities are isolated behind `FeatureFlags` so the unsigned
  build stays installable.

## Roadmap (paid Apple Developer account)

Flip the flags and add the matching entitlements/extensions: HealthKit import, a
WidgetKit + App Intents widget and Live Activity (App Group shared store), iCloud/CloudKit
sync, local notification reminders, and a FoundationModels coach.
