import SwiftUI
import SwiftData

/// A draggable floating "+" that composes a new note. It floats above every main
/// tab; a quick tap opens a new note, and a long-press picks it up so it can be
/// dragged to a new spot (the position is remembered across launches).
struct FloatingNoteButton: View {
  @Environment(\.modelContext) private var context
  @Query private var progressList: [UserProgress]

  @State private var showEditor = false
  @State private var dragOffset: CGSize = .zero
  @State private var dragging = false

  @AppStorage("noteFabX") private var savedX: Double = -1
  @AppStorage("noteFabY") private var savedY: Double = -1

  private let size: CGFloat = 56
  private let coordSpace = "noteFabSpace"

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  var body: some View {
    GeometryReader { geo in
      let center = resolved(in: geo.size)
      Image(systemName: "plus")
        .font(.system(size: 24, weight: .bold))
        .foregroundStyle(.white)
        .frame(width: size, height: size)
        .background(theme.accentGradient, in: Circle())
        .overlay(Circle().strokeBorder(.white.opacity(dragging ? 0.35 : 0), lineWidth: 2))
        .shadow(color: theme.accent.opacity(0.45), radius: dragging ? 18 : 12, x: 0, y: 6)
        .scaleEffect(dragging ? 1.12 : 1)
        .contentShape(Circle())
        .position(x: center.x + dragOffset.width, y: center.y + dragOffset.height)
        .animation(dragging ? nil : DLAnim.standard, value: dragOffset)
        .onTapGesture {
          Haptics.light()
          showEditor = true
        }
        .gesture(
          LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(coordinateSpace: .named(coordSpace)))
            .onChanged { value in
              if case .second(true, let drag?) = value {
                if !dragging { dragging = true; Haptics.medium() }
                dragOffset = drag.translation
              }
            }
            .onEnded { value in
              if case .second(true, let drag?) = value {
                savedX = center.x + drag.translation.width
                savedY = center.y + drag.translation.height
              }
              dragOffset = .zero
              dragging = false
            }
        )
        .accessibilityLabel(L("New note"))
        .accessibilityHint(L("Long-press to move"))
    }
    .coordinateSpace(name: coordSpace)
    .ignoresSafeArea(.keyboard)
    .sheet(isPresented: $showEditor) {
      NavigationStack { NoteEditorView(note: nil) }
    }
  }

  /// The button's center for the current layout. Defaults to the lower-right,
  /// clear of the tab bar; a saved position is clamped to stay on screen.
  private func resolved(in area: CGSize) -> CGPoint {
    let margin: CGFloat = 30
    let defaultX = area.width - size / 2 - margin
    let defaultY = area.height - size / 2 - margin - 72  // clear the tab bar
    let x = savedX < 0 ? defaultX : savedX
    let y = savedY < 0 ? defaultY : savedY
    return CGPoint(
      x: min(max(x, size / 2 + 8), area.width - size / 2 - 8),
      y: min(max(y, size / 2 + 8), area.height - size / 2 - 8)
    )
  }
}
