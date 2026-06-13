# Gamification logic

All gamification is pure, testable Swift in `Sources/Gamification/`. The UI never
computes XP itself — it calls `GamificationService.completeReview(...)`, which returns
a `ReviewResult` that drives the celebration.

## XP — `XPEngine`

When a daily review is completed, XP is summed then multiplied by the streak factor:

| Source | XP | Rule |
|---|---|---|
| Daily review | **+50** | Always, on first completion of the day |
| Early-bird bonus | **+20** | Completed before 20:00 local |
| Quality field | **+12** each | A field with ≥ 4 words (Win/Mistake/Lesson/Adjustment) |
| Morning intention | **+10** | Non-empty intention |
| Habit complete | **+10–20** | Per habit completed today (`Habit.xpValue`) |

```
total = round( (Σ base items) × streakMultiplier )
```

Awarding is **idempotent per entry**: `completeReview` returns `.none` if the entry
already has `xpAwarded > 0`, so XP can never be double-counted.

## Levels — `LevelSystem`

Levels start at 1. The XP needed to advance grows linearly so early levels feel fast
and later ones feel earned:

```
requirement(toReach level) = 100 + (level - 2) × 25     // level ≥ 2
```

So: L2 = 100, L3 = 125, L4 = 150, … `levelInfo(totalXP:)` returns the current level,
XP into the level, XP needed for the next, and a 0–1 progress value used by the header
bar. Rank titles change with level (Beginner → Seeker → Reflector → Sage → Mentor →
Master → Luminary).

## Streaks — `StreakEngine`

On completing a review on day *D* (relative to the last review day):

- no previous review → streak = **1**
- last review was **yesterday** → streak **+1**
- last review was **today** → unchanged (already done)
- otherwise (gap) → streak resets to **1**

`longestStreak` tracks the max. Multiplier:

| Streak | Multiplier |
|---|---|
| 1–6 | ×1.0 |
| 7–29 | **×1.5** |
| 30+ | **×2.0** |

## Badges — `BadgeEngine` + `BadgeCatalog`

13 badges across 6 categories (milestone, consistency, mastery, health, career,
relationships). `earnedBadgeIDs(stats)` returns everything currently qualified; the
service diffs against already-earned `BadgeRecord`s and inserts only the new ones (so
the celebration shows truly new unlocks). `progress(for:stats:)` powers the locked
gallery rings.

| Badge | Unlock rule |
|---|---|
| First Reflection | 1 completed review |
| 7-Day Sage | longest streak ≥ 7 |
| Perfectionist | longest streak ≥ 30 |
| Insight Master | 50 lessons captured |
| The Adjuster | 25 adjustments completed |
| Habit Hero | 100 habit completions |
| Wordsmith | 10,000 words written |
| Early Bird | 10 morning reviews |
| Rising / Ascendant | reach level 10 / 25 |
| Health Transformer / Career Climber / Connector | 10 reflections tagged health / career / relationships |

## Challenges — `ChallengeEngine`

Computed live from entries/habits (no extra storage), returned as `ChallengeProgress`
(0–1 + complete flag):

- **Daily** — "Make it measurable" (Adjustment contains a number), "Close the loop"
  (all 4 fields today).
- **Weekly** — "Five of seven" (5 complete reviews in the last 7 days), "Habit
  momentum" (5 habits this week).

## Growth Score

A compound score rewarding consistency and depth over raw volume:

```
growthScore = round( totalReviews + longestStreak×0.5 + lessonsCount×0.3 )
```

## Healthy by design

No public leaderboard; comparison is only against your own past. Multipliers reward
returning, not bingeing (idempotent per day). Celebrations are brief and skippable,
and every animation honours **Reduce Motion**.

## Tested

`Tests/GamificationTests.swift` covers level thresholds/progression, streak transitions
(new/continue/break/same-day), XP (early + quality + multiplier), and badge unlock +
progress math.
