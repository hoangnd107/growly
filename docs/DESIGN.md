# Design specs (Figma-style)

Dark-first, calm, premium. The app should feel like a kind, encouraging companion.

## Design tokens

**Color** (`Sources/Theme/Theme.swift`, adaptive light/dark)

| Token | Light | Dark |
|---|---|---|
| `background` | `#F6F6F8` | `#0A0A0A` |
| `surface` | `#FFFFFF` | `#161618` |
| `surfaceElevated` | `#FFFFFF` | `#202024` |
| `textPrimary` | `#0B0B0C` | `#F4F4F6` |
| `textSecondary` | `#6A6A70` | `#9B9BA2` |
| `separator` | `#E6E6EB` | `#2A2A30` |
| `xpGold` | `#FFC83D` | accent for XP |
| `streakStart→End` | `#FF9A3D → #FF3D5A` | flame gradient |
| `success` | `#34C759` | completion |

Accent is user-selectable (default Violet `#7E5BEF`) and drives `.tint` app-wide.

**Spacing** 4 / 8 / 16 / 24 / 32 / 48 · **Radius** card 24, control 14, pill ∞ ·
**Type** SF Rounded throughout (`Font.dl(...)`) · **Motion** quick 0.2s ease-out,
standard spring (response 0.42), bouncy spring (response 0.5); all gated by Reduce
Motion.

**Core component**: `GlassCard` — `.ultraThinMaterial`, 24pt continuous radius, hairline
border at 60% separator. Used for every content block.

---

## 1 · Onboarding  (`Features/Onboarding`)

Paged `TabView` (3 pages, dotted index), tinted by the live accent selection.

1. **Welcome** — large looping arrows glyph, "Growly" title, one-line value prop
   (the loop), `Continue`.
2. **Gamification intro** — gold bolt, "Earn XP every day", three perks (XP / streak
   multipliers / badges) as icon+text rows, `Continue`.
3. **Make it yours** — goal text field, accent color swatch row (5 circles, selected
   ring), `Start my loop` → sets `onboarded = true`, persists accent + goal.

*Empty/again*: never shown after completion.

---

## 2 · Today  (`Features/Today`) — the core

`NavigationStack`, title "Today" (inline). Top: **LevelHeader** card — level circle,
rank title + "Level n", streak flame (animated), XP-into-level gradient bar,
"+N today" gold pill. Below: segmented **Evening / Morning** picker (auto-selects by
clock: morning before noon).

**Evening Review** (vertical scroll, 16pt gutters):
- 4 × **ReflectionCard** (Win 🏆 green, Mistake ⚠️ orange, Lesson 💡 blue, Adjustment ♻️
  violet): icon chip + title + prompt, a check appears when filled; growing multiline
  `TextField`; a horizontal row of tappable suggestion chips that append text.
- **MoodEnergyCard**: 5 emoji mood selector (selected grows + tinted pill) + energy
  slider 1–5 with bolt + "n/5".
- **Photo card**: PhotosPicker → thumbnail + remove.
- **Completion card**: "n/4" + gold progress bar.
- Primary CTA **"Complete the day"** (enabled only at 4/4). After completion the CTA is
  replaced by a green "Day complete · +N XP earned" banner.
- On complete → **CompletionCelebration** overlay: dimmed scrim, confetti, "Day
  complete!" / "Level Up!", "+N XP", streak ×multiplier, any new badges, an AI quote,
  `Continue`. Spring-in, tap-to-dismiss, Reduce-Motion aware.

**Morning Quick Start**:
- Yesterday's Adjustment with a switch (checks it off → counts toward badges).
- Today's intention field.
- Morning prompt card (rotating).
- Habit checklist (emoji + name + "+XP" + check toggle).

---

## 3 · Insights  (`Features/Insights`)

`NavigationStack` "Insights". Weekly **coach** GlassCard (sparkles) with a heuristic
summary; **Growth Score** card (big tabular number + caption). *Roadmap*: Swift Charts
mood-over-time line, XP-per-day bars, streak calendar heatmap, "top 10% in health
streak"-style positive comparisons.

---

## 4 · Me / Profile  (`Features/Me`)

`NavigationStack` "Me". **LevelHeader** at top. **Badge gallery** GlassCard: "earned/total"
counter + 3-column grid; earned badges show their colored SF Symbol on a tinted disc,
locked ones show a lock at reduced opacity. *Roadmap*: XP history chart, customization
shop (spend XP on themes/icons), anonymous friend streak compare.

---

## 5 · History  (`Features/History`)

`NavigationStack` "History" with `.searchable`. Empty → `ContentUnavailableView`.
Otherwise a `LazyVStack` of day cards (mood emoji + weekday/date + XP pill + Win
preview). *Roadmap*: month calendar with mood dots + filters.

---

## Accessibility & quality bar

- Touch targets ≥ 44pt; icon-only controls carry labels/tooltips.
- Dynamic Type via system text styles; no hard-coded tiny fonts.
- Color is never the only signal (icons + labels accompany mood/state).
- Modal scrim 55% black; one primary CTA per screen.
- Reduce Motion disables confetti/pulse/level-up and shortens transitions.
