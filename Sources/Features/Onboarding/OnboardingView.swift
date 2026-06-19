import SwiftUI
import SwiftData

struct OnboardingView: View {
  @Environment(\.modelContext) private var context
  @Query private var progressList: [UserProgress]

  @State private var page = 0
  @State private var goal = ""
  @State private var accentHex = "7E5BEF"

  private let accents: [(name: String, hex: String, value: UInt)] = [
    ("Violet", "7E5BEF", 0x7E5BEF),
    ("Teal", "00B4A6", 0x00B4A6),
    ("Coral", "FF6B6B", 0xFF6B6B),
    ("Ocean", "3D7BFF", 0x3D7BFF),
    ("Gold", "FFB03D", 0xFFB03D),
  ]

  var body: some View {
    ZStack {
      DLColor.background.ignoresSafeArea()
      TabView(selection: $page) {
        welcomePage.tag(0)
        gamificationPage.tag(1)
        setupPage.tag(2)
      }
      .tabViewStyle(.page)
      .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
    .tint(Color(hexString: accentHex))
    .keyboardDismissButton()
  }

  private var welcomePage: some View {
    VStack(spacing: DLSpace.lg) {
      Spacer()
      Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
        .font(.system(size: 80))
        .foregroundStyle(.tint)
      Text("Growly")
        .font(.dl(.largeTitle, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
      Text(L("Turn every day into progress with a simple loop:\nWin · Mistake · Lesson · Adjustment."))
        .font(.dl(.body))
        .multilineTextAlignment(.center)
        .foregroundStyle(DLColor.textSecondary)
        .padding(.horizontal, DLSpace.xl)
      Spacer()
      nextButton(to: 1, title: L("Continue"))
    }
    .padding(DLSpace.lg)
  }

  private var gamificationPage: some View {
    VStack(spacing: DLSpace.lg) {
      Spacer()
      Image(systemName: "bolt.fill")
        .font(.system(size: 72))
        .foregroundStyle(DLColor.xpGold)
      Text(L("Earn XP every day"))
        .font(.dl(.title, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)
      VStack(alignment: .leading, spacing: DLSpace.md) {
        perk("bolt.fill", DLColor.xpGold, L("Complete your review for +50 XP"))
        perk("flame.fill", DLColor.streakEnd, L("Build streaks for XP multipliers"))
        perk("rosette", Color(hexString: accentHex), L("Unlock badges, levels & themes"))
      }
      .padding(.horizontal, DLSpace.lg)
      Spacer()
      nextButton(to: 2, title: L("Continue"))
    }
    .padding(DLSpace.lg)
  }

  private var setupPage: some View {
    VStack(spacing: DLSpace.lg) {
      Spacer()
      Text(L("Make it yours"))
        .font(.dl(.title, weight: .bold))
        .foregroundStyle(DLColor.textPrimary)

      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Your main goal"))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textSecondary)
        TextField(L("e.g. Become more consistent"), text: $goal)
          .textFieldStyle(.roundedBorder)
      }

      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Accent color"))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textSecondary)
        HStack(spacing: DLSpace.md) {
          ForEach(accents, id: \.hex) { accent in
            Button {
              accentHex = accent.hex
              Haptics.selection()
            } label: {
              Circle()
                .fill(Color(hex: accent.value))
                .frame(width: 40, height: 40)
                .overlay(
                  Circle().strokeBorder(DLColor.textPrimary, lineWidth: accentHex == accent.hex ? 3 : 0)
                )
            }
            .buttonStyle(.plain)
          }
        }
      }

      Spacer()
      PrimaryButton(L("Start my loop"), systemImage: "sparkles") { finish() }
    }
    .padding(DLSpace.lg)
  }

  private func perk(_ icon: String, _ color: Color, _ text: String) -> some View {
    HStack(spacing: DLSpace.md) {
      Image(systemName: icon).foregroundStyle(color).font(.system(size: 22)).frame(width: 28)
      Text(text).font(.dl(.body)).foregroundStyle(DLColor.textPrimary)
    }
  }

  private func nextButton(to target: Int, title: String) -> some View {
    PrimaryButton(title) {
      withAnimation { page = target }
    }
  }

  private func finish() {
    guard let progress = progressList.first else { return }
    progress.accentColorHex = accentHex
    progress.primaryGoal = goal
    progress.onboarded = true
    try? context.save()
    Haptics.success()
  }
}
