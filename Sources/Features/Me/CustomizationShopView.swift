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

  /// Editable working copy of the mood catalog, persisted on change.
  @State private var moods: [MoodOption] = []

  /// Preset colors offered when recoloring a mood.
  private let moodPalette = ["E5484D", "F0883E", "F5C84B", "8CCF4D", "34C759", "30B0C7", "5AC8FA", "7E5BEF", "AF52DE", "FF5C8A"]

  var body: some View {
    ZStack {
      DLColor.background.ignoresSafeArea()
      ScrollView {
        VStack(spacing: DLSpace.lg) {
          header

          gradientThemesCard

          moodsCard

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
    .keyboardDismissButton()
    .onAppear {
      syncUnlocks()
      if moods.isEmpty { moods = MoodCatalog.shared.options }
    }
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

  // MARK: Gradient themes (recolor the whole app)

  private var gradientThemesCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        Label(L("Themes"), systemImage: "paintpalette.fill")
          .font(.dl(.headline, weight: .semibold))
          .foregroundStyle(progress.accentColor)

        LazyVGrid(
          columns: Array(repeating: GridItem(.flexible(), spacing: DLSpace.md), count: 3),
          spacing: DLSpace.md
        ) {
          ForEach(GradientThemeCatalog.all) { theme in
            themeSwatch(theme)
          }
        }

        Text(L("Tap a theme to recolor the whole app."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)
      }
    }
  }

  private func themeSwatch(_ theme: GradientTheme) -> some View {
    let selected = progress.gradientThemeID == theme.id
    return Button {
      selectGradientTheme(theme)
    } label: {
      VStack(spacing: DLSpace.xs) {
        ZStack {
          RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
            .fill(theme.accentGradient)
            .frame(height: 56)
            .overlay(
              RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
                .strokeBorder(
                  selected ? DLColor.textPrimary : DLColor.separator.opacity(0.6),
                  lineWidth: selected ? 3 : 1
                )
            )
          if selected {
            Image(systemName: "checkmark")
              .font(.system(size: 18, weight: .bold))
              .foregroundStyle(.white)
              .shadow(radius: 1)
          }
        }
        Text(L(theme.name))
          .font(.dl(.caption2, weight: selected ? .bold : .medium))
          .foregroundStyle(selected ? DLColor.textPrimary : DLColor.textSecondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .bounceTap()
    .accessibilityLabel(L(theme.name))
    .accessibilityAddTraits(selected ? [.isSelected] : [])
  }

  private func selectGradientTheme(_ theme: GradientTheme) {
    progress.gradientThemeID = theme.id
    progress.accentColorHex = theme.accentHexString
    try? context.save()
    Haptics.selection()
  }

  // MARK: Moods (rename / recolor built-ins, add custom moods — applied app-wide)

  private var moodsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        HStack {
          Label(L("Moods"), systemImage: "face.smiling")
            .font(.dl(.headline, weight: .semibold))
            .foregroundStyle(progress.accentColor)
          Spacer()
          if moods != MoodCatalog.defaults {
            Button(L("Reset")) { resetMoods() }
              .font(.dl(.subheadline, weight: .semibold))
              .foregroundStyle(progress.accentColor)
          }
        }

        Text(L("Set an emoji and color for each mood, or add your own — moods show everywhere."))
          .font(.dl(.caption2))
          .foregroundStyle(DLColor.textTertiary)

        ForEach(Array(moods.enumerated()), id: \.element.id) { index, mood in
          moodEditorRow(index: index, mood: mood)
          if mood.id != moods.last?.id {
            Divider().overlay(DLColor.separator.opacity(0.5))
          }
        }

        Button {
          addMood()
        } label: {
          Label(L("Add mood"), systemImage: "plus.circle.fill")
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(progress.accentColor)
        }
        .buttonStyle(.plain)
        .padding(.top, DLSpace.xs)
      }
    }
    .onChange(of: moods) { _, _ in persistMoods() }
  }

  @ViewBuilder
  private func moodEditorRow(index: Int, mood: MoodOption) -> some View {
    HStack(spacing: DLSpace.sm) {
      // Color picker (preset palette).
      Menu {
        ForEach(moodPalette, id: \.self) { hex in
          Button { setColor(index, to: hex) } label: {
            Label {
              Text(verbatim: "#\(hex)")
            } icon: {
              Image(systemName: "circle.fill").foregroundStyle(Color(hexString: hex))
            }
          }
        }
      } label: {
        Circle()
          .fill(Color(hexString: mood.colorHex))
          .frame(width: 26, height: 26)
          .overlay(Circle().strokeBorder(DLColor.separator, lineWidth: 1))
      }
      .accessibilityLabel(L("Mood color"))

      // Emoji (one grapheme).
      TextField("🙂", text: emojiBinding(index))
        .multilineTextAlignment(.center)
        .font(.system(size: 22))
        .frame(width: 46)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
            .fill(DLColor.separator.opacity(0.35))
        )

      // Name — built-ins keep their localized label; custom moods are editable.
      if mood.isBuiltIn {
        Text(mood.displayName)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        TextField(L("Mood name"), text: nameBinding(index))
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
          .textInputAutocapitalization(.words)
          .frame(maxWidth: .infinity, alignment: .leading)
        Button { removeMood(mood) } label: {
          Image(systemName: "minus.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(DLColor.streakEnd)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Remove mood"))
      }
    }
    .padding(.vertical, 2)
  }

  // MARK: Mood editing

  private func emojiBinding(_ index: Int) -> Binding<String> {
    Binding(
      get: { moods.indices.contains(index) ? moods[index].emoji : "" },
      set: { newValue in
        guard moods.indices.contains(index) else { return }
        moods[index].emoji = String(newValue.prefix(1))
      }
    )
  }

  private func nameBinding(_ index: Int) -> Binding<String> {
    Binding(
      get: { moods.indices.contains(index) ? moods[index].label : "" },
      set: { newValue in
        guard moods.indices.contains(index) else { return }
        moods[index].label = newValue
      }
    )
  }

  private func setColor(_ index: Int, to hex: String) {
    guard moods.indices.contains(index) else { return }
    moods[index].colorHex = hex
    Haptics.selection()
  }

  private func addMood() {
    let newValue = (moods.map(\.value).max() ?? 5) + 1
    moods.append(
      MoodOption(value: newValue, emoji: "⭐️", label: "\(L("Mood")) \(newValue)", colorHex: "5AC8FA", isBuiltIn: false)
    )
    Haptics.success()
  }

  private func removeMood(_ mood: MoodOption) {
    guard !mood.isBuiltIn else { return }
    moods.removeAll { $0.value == mood.value }
    Haptics.medium()
  }

  private func resetMoods() {
    progress.moodCatalogJSON = ""
    progress.moodEmojis = []
    MoodCatalog.shared.apply(from: progress)
    moods = MoodCatalog.shared.options
    try? context.save()
    Haptics.medium()
  }

  /// Persist the working copy to the catalog + store (no reassignment, so text
  /// fields keep their cursor while editing).
  private func persistMoods() {
    MoodCatalog.shared.save(moods, to: progress)
    try? context.save()
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
