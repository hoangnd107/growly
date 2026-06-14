import SwiftUI
import SwiftData

/// An accent-color shop. Themes unlock at LEVEL thresholds — XP is never spent
/// or deducted (it drives the level). Selecting an unlocked accent persists
/// `UserProgress.accentColorHex`; reaching a level records the id in
/// `UserProgress.unlockedThemeIDs`.
struct CustomizationShopView: View {
  @Environment(\.modelContext) private var context
  @Bindable var progress: UserProgress

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var currentLevel: Int { progress.levelInfo.level }

  private let columns = [GridItem(.adaptive(minimum: 96), spacing: DLSpace.md)]

  var body: some View {
    ZStack {
      DLColor.background.ignoresSafeArea()
      ScrollView {
        VStack(spacing: DLSpace.lg) {
          header

          GlassCard {
            LazyVGrid(columns: columns, spacing: DLSpace.md) {
              ForEach(AccentTheme.catalog) { theme in
                accentTile(theme)
              }
            }
          }

          Text("Keep up your daily reviews to climb levels and unlock more accents.")
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        }
        .padding(DLSpace.md)
      }
    }
    .navigationTitle("Customize")
    .navigationBarTitleDisplayMode(.inline)
    .onAppear(perform: syncUnlocks)
  }

  private var header: some View {
    GlassCard {
      HStack(spacing: DLSpace.md) {
        ZStack {
          Circle().fill(progress.accentColor.opacity(0.2)).frame(width: 48, height: 48)
          Image(systemName: "paintpalette.fill")
            .font(.system(size: 20))
            .foregroundStyle(progress.accentColor)
        }
        VStack(alignment: .leading, spacing: 2) {
          Text("Accent color")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          Text("Level \(currentLevel) · \(unlockedCount) of \(AccentTheme.catalog.count) unlocked")
            .font(.dl(.caption))
            .foregroundStyle(DLColor.textSecondary)
            .monospacedDigit()
        }
        Spacer()
      }
    }
  }

  private var unlockedCount: Int {
    AccentTheme.catalog.filter { isUnlocked($0) }.count
  }

  private func isUnlocked(_ theme: AccentTheme) -> Bool {
    progress.debugUnlockAll
      || currentLevel >= theme.unlockLevel
      || progress.unlockedThemeIDs.contains(theme.id)
  }

  private func isSelected(_ theme: AccentTheme) -> Bool {
    progress.accentColorHex.caseInsensitiveCompare(theme.hexString) == .orderedSame
  }

  private func accentTile(_ theme: AccentTheme) -> some View {
    let unlocked = isUnlocked(theme)
    let selected = isSelected(theme)

    return Button {
      select(theme)
    } label: {
      VStack(spacing: DLSpace.sm) {
        ZStack {
          Circle()
            .fill(theme.color)
            .frame(width: 56, height: 56)
            .overlay(
              Circle().strokeBorder(
                selected ? DLColor.textPrimary : Color.clear,
                lineWidth: 3
              )
            )
            .shadow(color: theme.color.opacity(unlocked ? 0.45 : 0), radius: 8, y: 2)
            .opacity(unlocked ? 1 : 0.35)

          if !unlocked {
            Image(systemName: "lock.fill")
              .font(.system(size: 18, weight: .semibold))
              .foregroundStyle(.white)
          } else if selected {
            Image(systemName: "checkmark")
              .font(.system(size: 20, weight: .bold))
              .foregroundStyle(.white)
          }
        }

        Text(theme.name)
          .font(.dl(.caption2, weight: .medium))
          .foregroundStyle(unlocked ? DLColor.textPrimary : DLColor.textTertiary)
          .lineLimit(1)

        if unlocked {
          Text(selected ? "Selected" : "Tap to use")
            .font(.dl(.caption2))
            .foregroundStyle(selected ? theme.color : DLColor.textSecondary)
        } else {
          Text("Level \(theme.unlockLevel)")
            .font(.dl(.caption2, weight: .semibold))
            .foregroundStyle(DLColor.textTertiary)
            .monospacedDigit()
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, DLSpace.xs)
    }
    .buttonStyle(.plain)
    .disabled(!unlocked)
    .accessibilityLabel(
      unlocked
        ? "\(theme.name) accent, \(selected ? "selected" : "tap to use")"
        : "\(theme.name) accent, locked, unlocks at level \(theme.unlockLevel)"
    )
  }

  // MARK: Actions

  /// Persist any themes whose unlock level has been reached.
  private func syncUnlocks() {
    var changed = false
    for theme in AccentTheme.catalog where currentLevel >= theme.unlockLevel {
      if !progress.unlockedThemeIDs.contains(theme.id) {
        progress.unlockedThemeIDs.append(theme.id)
        changed = true
      }
    }
    if changed { try? context.save() }
  }

  private func select(_ theme: AccentTheme) {
    guard isUnlocked(theme) else { return }
    if !progress.unlockedThemeIDs.contains(theme.id) {
      progress.unlockedThemeIDs.append(theme.id)
    }
    withAnimation(reduceMotion ? nil : DLAnim.quick) {
      progress.accentColorHex = theme.hexString
    }
    try? context.save()
    Haptics.selection()
  }
}

/// A purchasable (by level) accent color.
struct AccentTheme: Identifiable, Hashable {
  let id: String
  let name: String
  let hex: UInt
  let unlockLevel: Int

  var color: Color { Color(hex: hex) }
  var hexString: String { String(format: "%06X", hex) }

  static let catalog: [AccentTheme] = [
    AccentTheme(id: "violet", name: "Violet", hex: 0x7E5BEF, unlockLevel: 1),
    AccentTheme(id: "ocean", name: "Ocean", hex: 0x2D9CDB, unlockLevel: 1),
    AccentTheme(id: "mint", name: "Mint", hex: 0x2EC4B6, unlockLevel: 3),
    AccentTheme(id: "sunset", name: "Sunset", hex: 0xFF7849, unlockLevel: 5),
    AccentTheme(id: "rose", name: "Rose", hex: 0xFF5C8A, unlockLevel: 8),
    AccentTheme(id: "lime", name: "Lime", hex: 0x8CCF4D, unlockLevel: 10),
    AccentTheme(id: "gold", name: "Gold", hex: 0xFFC83D, unlockLevel: 15),
    AccentTheme(id: "crimson", name: "Crimson", hex: 0xE5484D, unlockLevel: 20),
    AccentTheme(id: "indigo", name: "Indigo", hex: 0x4C5FD5, unlockLevel: 25),
    AccentTheme(id: "aurora", name: "Aurora", hex: 0x00D2A8, unlockLevel: 30),
    AccentTheme(id: "magenta", name: "Magenta", hex: 0xC640E0, unlockLevel: 40),
    AccentTheme(id: "ember", name: "Ember", hex: 0xFF3D5A, unlockLevel: 50),
  ]
}
