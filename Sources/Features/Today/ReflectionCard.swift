import SwiftUI

/// One of the four core fields (Win / Mistake / Lesson / Adjustment).
/// Premium glass card with an accent orb, colored hairline, suggestion chips,
/// and on-device voice dictation.
struct ReflectionCard: View {
  let kind: ReflectionKind
  @Binding var text: String

  @StateObject private var dictator = SpeechDictator()
  @State private var pulse = false
  /// Local edit buffer (item 7). The TextField binds here so every keystroke
  /// updates only this card; the write back to the SwiftData entry — which
  /// recomputes the whole Today screen — is debounced off the typing path, so
  /// typing no longer feels like the text appears a beat late.
  @State private var draft = ""
  @State private var commitTask: Task<Void, Never>?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var isFilled: Bool {
    !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  var body: some View {
    VStack(alignment: .leading, spacing: DLSpace.md) {
      header
      accentHairline
      editor
      suggestionChips
    }
    .padding(DLSpace.lg)
    .frame(maxWidth: .infinity, alignment: .leading)
    .glass(cornerRadius: DLRadius.card)
    .overlay(alignment: .leading) {
      // Soft accent edge that brightens once the field is filled.
      RoundedRectangle(cornerRadius: DLRadius.card, style: .continuous)
        .fill(kind.accent.opacity(isFilled ? 0.10 : 0.04))
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
    .animation(DLAnim.standard, value: isFilled)
    .onChange(of: dictator.isRecording) { wasRecording, recording in
      // Append the captured transcript when recording stops.
      if wasRecording && !recording {
        appendTranscript(dictator.transcript)
      }
    }
    .onChange(of: draft) { _, _ in scheduleCommit() }
    .onAppear { draft = text }
    .onDisappear {
      // Flush any pending edit so nothing is lost when the card goes away.
      commitTask?.cancel()
      if text != draft { text = draft }
    }
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: DLSpace.md) {
      orb
      VStack(alignment: .leading, spacing: 2) {
        Text(L(kind.title))
          .font(.dl(.title3, weight: .bold))
          .foregroundStyle(DLColor.textPrimary)
        Text(L(kind.prompt))
          .font(.dl(.caption, weight: .medium))
          .foregroundStyle(DLColor.textSecondary)
          .lineLimit(1)
      }
      Spacer(minLength: DLSpace.sm)
      micButton
      if isFilled {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 24, weight: .semibold))
          .foregroundStyle(kind.accent)
          .transition(.scale.combined(with: .opacity))
      }
    }
  }

  private var orb: some View {
    ZStack {
      Circle()
        .fill(kind.accent.opacity(0.18))
        .frame(width: 48, height: 48)
      Circle()
        .strokeBorder(kind.accent.opacity(0.35), lineWidth: 1)
        .frame(width: 48, height: 48)
      Image(systemName: kind.systemIcon)
        .font(.system(size: 20, weight: .semibold))
        .foregroundStyle(kind.accent)
    }
    .shadow(color: kind.accent.opacity(0.35), radius: 8, x: 0, y: 4)
  }

  private var accentHairline: some View {
    LinearGradient(
      colors: [kind.accent.opacity(0.7), kind.accent.opacity(0.05)],
      startPoint: .leading, endPoint: .trailing
    )
    .frame(height: 2)
    .clipShape(Capsule())
  }

  // MARK: Voice

  private var micButton: some View {
    Button {
      Task {
        if await SpeechDictator.requestAuthorization() {
          dictator.toggle()
        }
      }
    } label: {
      ZStack {
        Circle()
          .fill(dictator.isRecording ? kind.accent.opacity(0.22) : DLColor.surfaceElevated.opacity(0.7))
          .frame(width: 44, height: 44)
        Image(systemName: dictator.isRecording ? "mic.slash.fill" : "mic.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(dictator.isRecording ? kind.accent : DLColor.textSecondary)
        if dictator.isRecording {
          recordingDot
            .offset(x: 16, y: -16)
        }
      }
    }
    .buttonStyle(.plain)
    .bounceTap()
    .disabled(dictator.unavailable)
    .opacity(dictator.unavailable ? 0.4 : 1)
    .accessibilityLabel(dictator.isRecording ? L("Stop dictation") : L("Start dictation"))
  }

  private var recordingDot: some View {
    Circle()
      .fill(Color(hex: 0xFF3B30))
      .frame(width: 10, height: 10)
      .scaleEffect(pulse && !reduceMotion ? 1.35 : 0.85)
      .opacity(pulse && !reduceMotion ? 0.55 : 1)
      .animation(
        reduceMotion ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
        value: pulse
      )
      .onAppear { pulse = true }
      .onDisappear { pulse = false }
  }

  // MARK: Editor

  private var editor: some View {
    TextField(L(kind.prompt), text: $draft, axis: .vertical)
      .lineLimit(3...8)
      .font(.dl(.body))
      .foregroundStyle(DLColor.textPrimary)
      .textInputAutocapitalization(.sentences)
      .padding(DLSpace.md)
      .background(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .fill(DLColor.surface.opacity(0.5))
      )
      .overlay(
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .strokeBorder(kind.accent.opacity(isFilled ? 0.35 : 0.12), lineWidth: 1)
      )
  }

  // MARK: Suggestions

  private var suggestionChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        ForEach(AICoach.suggestions(for: kind), id: \.self) { suggestion in
          Button { append(suggestion) } label: {
            Text(suggestion)
              .font(.dl(.caption, weight: .semibold))
              .fixedSize(horizontal: true, vertical: false)
              .padding(.horizontal, DLSpace.md)
              .padding(.vertical, DLSpace.sm)
              .background(kind.accent.opacity(0.16), in: Capsule())
              .overlay(Capsule().strokeBorder(kind.accent.opacity(0.28), lineWidth: 1))
              .foregroundStyle(kind.accent)
          }
          // ScaleButtonStyle scales from the button's own press state instead of a
          // DragGesture, so the horizontal swipe reaches the ScrollView and the
          // chip strip actually slides (the old `.bounceTap()` swallowed the pan).
          .buttonStyle(ScaleButtonStyle(scale: 0.93, haptic: false))
        }
      }
      .padding(.vertical, 2)
      .padding(.horizontal, 2)
      .scrollTargetLayout()
    }
    .scrollTargetBehavior(.viewAligned)
    .scrollBounceBehavior(.basedOnSize)
    // No `scrollClipDisabled`: the chip strip must stay inside the card and clip
    // at its edges so it never spills past the screen, while still scrolling
    // horizontally with a smooth slide.
  }

  // MARK: Text helpers

  /// Debounced write-back to the bound entry text. Coalesces rapid keystrokes so
  /// the SwiftData mutation (and the Today screen recompute it triggers) happens
  /// at most a few times per second instead of on every character.
  private func scheduleCommit() {
    commitTask?.cancel()
    let pending = draft
    commitTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      if text != pending { text = pending }
    }
  }

  private func append(_ suggestion: String) {
    commitTask?.cancel()
    if draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      draft = suggestion + " "
    } else {
      draft += (draft.hasSuffix(" ") ? "" : " ") + suggestion + " "
    }
    text = draft
    Haptics.light()
  }

  private func appendTranscript(_ transcript: String) {
    let captured = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !captured.isEmpty else { return }
    commitTask?.cancel()
    if draft.isEmpty {
      draft = captured
    } else {
      draft += (draft.hasSuffix(" ") ? "" : " ") + captured
    }
    text = draft
    Haptics.success()
  }
}
