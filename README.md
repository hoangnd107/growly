# Daily Loop 🔁

A native **SwiftUI** daily-reflection journal built around a simple, powerful loop —
**Win · Mistake · Lesson · Adjustment** — wrapped in calm, premium UI and healthy
gamification (XP, levels, streaks, badges, challenges) that keeps you coming back
without turning reflection into a numbers game.

> Built to install on your iPhone **without a Mac**: the Xcode project is generated
> from [`project.yml`](project.yml) with **XcodeGen** and compiled into an
> **unsigned IPA** on free GitHub Actions, ready for **Sideloadly**.

---

## Why "Daily Loop"

The prompt suggested *Reflectly* — but that's an existing trademarked App Store app,
so this project is named **Daily Loop**: short, memorable, and it names the core
mechanic (the daily feedback loop).

## Features

- **The Loop** — four focused fields (Win, Mistake, Lesson, Adjustment) with quality
  detection, gentle AI-style suggestion chips, and a morning/evening flow.
- **Mood & energy** tracking, photo attachment, tags.
- **Gamification** — XP with early-bird & quality bonuses, a 50+ level curve, streaks
  with ×1.5 / ×2 multipliers, 13 badges across 6 categories, daily/weekly challenges,
  and a compound **Growth Score**.
- **Insights** — weekly coach summary + growth visualization.
- **Profile (Me)** — level, XP, streak, badge gallery with locked/earned states.
- **History** — searchable timeline of entries.
- **Privacy-first** — 100% on-device **SwiftData**, optional **Face ID** lock, no
  account required, no tracking.
- **Premium feel** — dark-first design (#0A0A0A), glassmorphism, rounded typography,
  spring micro-interactions, confetti & level-up celebration — all respecting
  **Reduce Motion**.

## Tech

- **SwiftUI** + **SwiftData** (iOS 17+), Swift Charts-ready, `LocalAuthentication`,
  `PhotosUI`.
- Project-as-code via **XcodeGen**; CI builds an unsigned IPA on `macos-latest`.

### Capabilities gated for free sideloading

A *free* Apple ID cannot sign certain entitlements, so these are behind
[`FeatureFlags`](Sources/App/FeatureFlags.swift) and **off** in the sideload build
(code is present; flip them on with a paid Apple Developer account):

| Capability | Flag | Sideload (free) |
|---|---|---|
| HealthKit | `healthKit` | ❌ |
| Live Activities / push | `liveActivities` | ❌ |
| iCloud / CloudKit sync | `iCloudSync` | ❌ |
| Apple Intelligence coach | `appleIntelligence` | ❌ |
| Local reminders | `reminders` | ✅ (permission) |
| Voice input (Speech) | `voiceInput` | ✅ (permission) |

Everything else — the full loop, gamification, insights, history, Face ID — runs on a
free sideload.

## Documentation

- [Design specs (Figma-style, per screen)](docs/DESIGN.md)
- [Gamification logic (XP · streaks · badges · levels)](docs/GAMIFICATION.md)
- [Architecture, privacy & performance](docs/ARCHITECTURE.md)
- [Build & install (Sideloadly)](docs/BUILD.md)

## Get the app

1. **Actions → iOS Build → Run workflow** (or push to `main`).
2. Download the `DailyLoop-<version>-<run>.ipa` artifact (unzip once).
3. Sideload with [Sideloadly](https://sideloadly.io/) + a free Apple ID.

## Project layout

```text
DailyLoop/
├── project.yml                 # XcodeGen spec (the Xcode project is generated)
├── .github/workflows/          # ios-build.yml (IPA), tests.yml (simulator)
├── Sources/
│   ├── App/                    # entry, RootView, tab bar, Face ID lock, FeatureFlags
│   ├── Models/                 # SwiftData @Model + enums + Badge catalog
│   ├── Gamification/           # Level/Streak/XP/Badge/Challenge engines + service
│   ├── Persistence/            # ModelContainer + seed
│   ├── Theme/                  # colors, spacing, typography tokens
│   ├── Services/               # AICoach (local), Haptics
│   ├── Components/             # GlassCard, XP bar, streak flame, confetti, …
│   └── Features/               # Today, Insights, Me, History, Onboarding
├── Resources/Assets.xcassets/
└── Tests/                      # gamification logic unit tests
```

## License

MIT — see [LICENSE](LICENSE).
