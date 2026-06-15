import SwiftUI
import SwiftData

/// The five main tabs. Pages live in a paging `TabView` so the whole screen can
/// be swiped left/right between tabs, and a custom floating bar replaces the
/// system tab bar: inactive tabs show an icon only, the active tab expands into a
/// labeled pill, and the icon bounces on selection.
struct MainTabView: View {
  @Query private var progressList: [UserProgress]
  @State private var selection = 0

  private let tabs: [(icon: String, key: String)] = [
    ("sun.max.fill", "Today"),
    ("note.text", "Notes"),
    ("calendar", "History"),
    ("chart.line.uptrend.xyaxis", "Insights"),
    ("person.fill", "Me"),
  ]

  var body: some View {
    // Touch `languageCode` so the bar's labels re-localize in place when the
    // in-app language changes (no full rebuild / tab reset needed).
    let _ = progressList.first?.languageCode

    TabView(selection: $selection) {
      TodayView().tag(0)
      NotesView().tag(1)
      HistoryView().tag(2)
      InsightsView().tag(3)
      ProfileView().tag(4)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .safeAreaInset(edge: .bottom) {
      FloatingTabBar(selection: $selection, tabs: tabs)
    }
  }
}

// MARK: - Floating tab bar

private struct FloatingTabBar: View {
  @Binding var selection: Int
  let tabs: [(icon: String, key: String)]

  @Namespace private var ns

  var body: some View {
    HStack(spacing: DLSpace.xs) {
      ForEach(tabs.indices, id: \.self) { index in
        item(index)
      }
    }
    .padding(.horizontal, DLSpace.sm)
    .padding(.vertical, DLSpace.xs)
    .background(.ultraThinMaterial, in: Capsule())
    .overlay(Capsule().strokeBorder(DLColor.separator.opacity(0.5), lineWidth: 1))
    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    .padding(.horizontal, DLSpace.md)
    .padding(.bottom, DLSpace.xs)
  }

  private func item(_ index: Int) -> some View {
    let active = selection == index
    return Button {
      guard selection != index else { return }
      withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { selection = index }
      Haptics.selection()
    } label: {
      HStack(spacing: 6) {
        Image(systemName: tabs[index].icon)
          .font(.system(size: 18, weight: .semibold))
          .symbolEffect(.bounce, value: active)
        if active {
          Text(L(tabs[index].key))
            .font(.dl(.subheadline, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .transition(.opacity.combined(with: .scale(scale: 0.7)))
        }
      }
      .foregroundStyle(active ? .white : DLColor.textSecondary)
      .padding(.vertical, 10)
      .padding(.horizontal, active ? 16 : 12)
      .background {
        if active {
          Capsule()
            .fill(Color.accentColor)
            .matchedGeometryEffect(id: "activeTab", in: ns)
        }
      }
      .contentShape(Capsule())
      .frame(maxWidth: active ? nil : CGFloat.infinity)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L(tabs[index].key))
    .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
  }
}
