# Growly 🔁

A native **SwiftUI** daily-reflection journal built around a simple, powerful loop —
**Win · Mistake · Lesson · Adjustment** — wrapped in calm, premium UI and healthy
gamification (XP, levels, streaks, badges, challenges) that keeps you coming back
without turning reflection into a numbers game.

> Built to install on your iPhone **without a Mac**: the Xcode project is generated
> from [`project.yml`](project.yml) with **XcodeGen** and compiled into an
> **unsigned IPA** on free GitHub Actions, ready for **Sideloadly**.

---

## Why "Growly"

The prompt suggested *Reflectly* — but that's an existing trademarked App Store app,
so this project is named **Growly**: short, memorable, and it names the core
mechanic (the daily feedback loop).

## Features

- **The Loop** — four focused fields (Win, Mistake, Lesson, Adjustment) with quality
  detection, gentle suggestion chips, and a morning/evening flow.
- **Notes** — a dedicated tab for free-form notes: many per day, full editor, an
  **editable creation date**, pin/colour-label/mood/tags, flexible filters (All /
  Today / This week / Pinned / by tag) + search.
- **Photos & videos** — attach multiple images and videos to entries and notes, with
  an in-app zoomable image viewer and AVKit video playback.
- **Mood & energy** tracking, tags.
- **Gamification** — XP with early-bird & quality bonuses, a 50+ level curve, streaks
  with ×1.5 / ×2 multipliers, 13 badges across 6 categories, daily/weekly challenges,
  and a compound **Growth Score**.
- **Insights** — weekly coach, **tappable** Swift Charts (mood, XP/day, distribution,
  growth curve), and a GitHub-style **mood heatmap**.
- **Profile (Me)** — level, XP, streak, badge gallery, 30-day XP chart, level-gated
  accent shop.
- **History** — month calendar + searchable timeline + entry detail.
- **Languages** — switch in-app between **English, Tiếng Việt, 中文, 한국어**.
- **Daily reminders** — opt-in local notification at a time you choose.
- **Local backup & restore** — one-tap JSON snapshot of all data to the device, with
  restore (a safety net beyond SwiftData's own persistence).
- **Privacy-first** — 100% on-device **SwiftData**, optional **Face ID** lock, no
  account required, no tracking, no network calls.
- **Premium feel** — dark-first design (#0A0A0A), glassmorphism, rounded typography,
  spring micro-interactions, confetti & level-up celebration, a custom flame app icon
  (light/dark) — all respecting **Reduce Motion**.
- **Testing switch** — Settings → *Unlock everything (testing)* unlocks all gated
  content on/off without affecting your real progress.

## Tech

- **SwiftUI** + **SwiftData** (iOS 17+), **Swift Charts**, **AVKit**, **PhotosUI**,
  **UserNotifications**, `LocalAuthentication`.
- Fully on-device. This build deliberately uses **no entitlement-gated capabilities**
  (no HealthKit / Live Activities / push / iCloud / Apple Intelligence), so it installs
  and runs from a free Sideloadly sign with nothing disabled.
- Project-as-code via **XcodeGen**; CI builds an unsigned IPA on `macos-latest` and
  bumps to Node-24 GitHub Actions (`checkout@v5`, `setup-java@v5`).

## Documentation

- [Design specs (Figma-style, per screen)](docs/DESIGN.md)
- [Gamification logic (XP · streaks · badges · levels)](docs/GAMIFICATION.md)
- [Architecture, privacy & performance](docs/ARCHITECTURE.md)
- [Build & install (Sideloadly)](docs/BUILD.md)

## Get the app

1. **Actions → iOS Build → Run workflow** (or push to `main`).
2. Download the `Growly-<version>-<run>.ipa` artifact (unzip once).
3. Sideload with [Sideloadly](https://sideloadly.io/) + a free Apple ID.

## Project layout

```text
Growly/
├── project.yml                 # XcodeGen spec (the Xcode project is generated)
├── .github/workflows/          # ios-build.yml (IPA), tests.yml (simulator)
├── Sources/
│   ├── App/                    # entry, RootView, tab bar, Face ID lock
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
