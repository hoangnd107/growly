import SwiftUI
import SwiftData
import UIKit

/// Apple-Journal-style note editor: title + divider + body on one page, an
/// editable creation date, mood/color/tags, location, media, and a floating
/// bottom toolbar (format, bookmark, location, voice memo, dictate, photo,
/// camera, undo).
///
/// For a NEW note the model is inserted on appear so media/audio can attach
/// immediately; an empty new note is deleted again on cancel.
struct NoteEditorView: View {
  @Environment(\.modelContext) private var context

  private let existingNote: DayNote?
  @State private var note: DayNote?

  init(note: DayNote?) { self.existingNote = note }

  var body: some View {
    Group {
      if let note {
        NoteEditorForm(note: note, isNew: existingNote == nil)
      } else {
        ProgressView()
      }
    }
    .onAppear {
      if note == nil {
        if let existingNote {
          note = existingNote
        } else {
          let fresh = DayNote()
          context.insert(fresh)
          note = fresh
        }
      }
    }
  }
}

private struct NoteEditorForm: View {
  @Bindable var note: DayNote
  let isNew: Bool

  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss
  @Query private var progressList: [UserProgress]

  @StateObject private var recorder = AudioRecorder()
  @StateObject private var dictator = SpeechDictator()

  @State private var newTag = ""
  @State private var undoSnapshot: String?
  @State private var showCamera = false
  @State private var previewing = false
  @State private var showLocationPicker = false

  /// Local edit buffers (item 10). The title/body fields bind here so each
  /// keystroke updates only this view; the write-back to the SwiftData model —
  /// which dirties it and triggers an autosave — is debounced off the typing
  /// path, matching `ReflectionCard`, so typing stays smooth in long notes.
  @State private var titleDraft = ""
  @State private var bodyDraft = ""
  @State private var commitTask: Task<Void, Never>?
  /// Set once Save/Cancel has run, so the `onDisappear` flush is skipped (and we
  /// never touch a note that Cancel just deleted).
  @State private var didFinalize = false

  private let presetColors = ["FF3D5A", "FF9F0A", "FFC83D", "34C759", "00B4A6", "5AC8FA", "7E5BEF", "FF5C8A"]

  private var theme: GradientTheme {
    progressList.first?.gradientTheme ?? GradientThemeCatalog.theme(id: "teal")
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: DLSpace.lg) {
          // The note "page": date, title, body, recording/location cues.
          GlassCard(padding: DLSpace.lg) {
            VStack(alignment: .leading, spacing: DLSpace.md) {
              metaRow
              TextField(L("Title"), text: $titleDraft, axis: .vertical)
                .font(.dl(.title, weight: .bold))
                .foregroundStyle(DLColor.textPrimary)
                .textInputAutocapitalization(.sentences)

              Divider().overlay(DLColor.separator)

              if previewing {
                Group {
                  if bodyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(L("Nothing to preview yet."))
                      .font(.dl(.body))
                      .foregroundStyle(DLColor.textTertiary)
                  } else {
                    MarkdownText(raw: bodyDraft)
                  }
                }
                .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(DLAnim.quick) { previewing = false } }
              } else {
                TextField(L("Write your note…"), text: $bodyDraft, axis: .vertical)
                  .font(.dl(.body))
                  .foregroundStyle(DLColor.textPrimary)
                  .lineLimit(6...40)
                  .textInputAutocapitalization(.sentences)
              }

              if dictator.isRecording {
                recordingBanner(L("Listening…"), color: DLColor.warning)
              }
              if recorder.isRecording {
                recordingBanner(Lf("Recording %@", timeString(recorder.elapsed)), color: Color(hex: 0xFF3B30))
              }
            }
          }

          // Mood + color.
          GlassCard {
            VStack(alignment: .leading, spacing: DLSpace.md) {
              fieldLabel(L("Mood"))
              moodRow
              Divider().overlay(DLColor.separator)
              fieldLabel(L("Color"))
              colorRow
            }
          }

          // Tags.
          GlassCard {
            VStack(alignment: .leading, spacing: DLSpace.sm) {
              fieldLabel(L("Tags"))
              tagsRow
            }
          }

          // Locations.
          GlassCard {
            VStack(alignment: .leading, spacing: DLSpace.sm) {
              fieldLabel(L("Locations"))
              locationsSection
            }
          }

          // Media.
          GlassCard { mediaSection }
        }
        .padding(.horizontal, DLSpace.lg)
        .padding(.top, DLSpace.md)
        .padding(.bottom, DLSpace.lg)
      }
      .scrollDismissesKeyboard(.interactively)
      .themedBackground(theme)
      .navigationTitle(isNew ? L("New note") : L("Edit note"))
      .navigationBarTitleDisplayMode(.inline)
      .tint(theme.accent)
      .safeAreaInset(edge: .bottom) { toolbar }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button(L("Cancel")) { cancel() }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button(L("Save")) { save() }.fontWeight(.semibold)
        }
      }
      .keyboardDismissButton()
      .fullScreenCover(isPresented: $showCamera) {
        CameraPicker { image in addCamera(image) }
          .ignoresSafeArea()
      }
      .sheet(isPresented: $showLocationPicker) {
        MapLocationPicker { name, latitude, longitude in
          addLocation(name: name, latitude: latitude, longitude: longitude)
        }
      }
      .onChange(of: dictator.isRecording) { was, now in
        if was && !now { appendToBody(dictator.transcript) }
      }
      .onChange(of: titleDraft) { _, _ in scheduleCommit() }
      .onChange(of: bodyDraft) { _, _ in scheduleCommit() }
      .onAppear {
        migrateLegacyLocation()
        // Seed the edit buffers once from the model.
        titleDraft = note.title
        bodyDraft = note.text
      }
      .onDisappear {
        // Flush any pending debounced edit so nothing is lost on interactive
        // (swipe-down) dismiss. Skipped after Save/Cancel already finalized.
        guard !didFinalize else { return }
        commitTask?.cancel()
        commitDrafts()
      }
    }
  }

  // MARK: Meta (date)

  private var metaRow: some View {
    HStack {
      Image(systemName: "calendar")
        .foregroundStyle(theme.accent)
      DatePicker("", selection: $note.createdAt, displayedComponents: [.date, .hourAndMinute])
        .labelsHidden()
      Spacer()
      Button {
        note.bookmarked.toggle()
        Haptics.selection()
      } label: {
        Image(systemName: note.bookmarked ? "bookmark.fill" : "bookmark")
          .foregroundStyle(note.bookmarked ? theme.accent : DLColor.textSecondary)
      }
      .accessibilityLabel(note.bookmarked ? L("Remove bookmark") : L("Bookmark"))
    }
  }

  // MARK: Locations (multiple, map-picked)

  @ViewBuilder
  private var locationsSection: some View {
    ForEach(note.sortedLocations) { place in
      HStack(spacing: DLSpace.sm) {
        Image(systemName: "mappin.circle.fill")
          .font(.system(size: 18))
          .foregroundStyle(theme.accent)
        Text(place.name)
          .font(.dl(.subheadline, weight: .medium))
          .foregroundStyle(DLColor.textPrimary)
          .lineLimit(1)
        Spacer(minLength: DLSpace.sm)
        Button {
          removeLocation(place)
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(DLColor.textTertiary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Remove location"))
      }
    }

    Button {
      Haptics.light()
      showLocationPicker = true
    } label: {
      Label(L("Add location"), systemImage: "mappin.and.ellipse")
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(theme.accent)
    }
    .buttonStyle(.plain)
  }

  // MARK: Mood / color / tags

  private func fieldLabel(_ text: String) -> some View {
    Text(text)
      .font(.dl(.caption, weight: .semibold))
      .foregroundStyle(DLColor.textSecondary)
      .textCase(.uppercase)
  }

  private var moodRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        ForEach(MoodCatalog.shared.options) { mood in
          Button {
            note.moodRaw = (note.moodRaw == mood.value) ? nil : mood.value
            Haptics.selection()
          } label: {
            Text(mood.emoji)
              .font(.system(size: note.moodRaw == mood.value ? 28 : 22))
              .padding(6)
              .background(
                note.moodRaw == mood.value ? mood.color.opacity(0.18) : Color.clear,
                in: Circle()
              )
          }
          .buttonStyle(.plain)
          .accessibilityLabel(mood.displayName)
        }
      }
    }
  }

  private var colorRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        colorDot(nil)
        ForEach(presetColors, id: \.self) { hex in colorDot(hex) }
      }
    }
  }

  private func colorDot(_ hex: String?) -> some View {
    let isSelected = note.colorHex == hex
    return Button {
      note.colorHex = hex
      Haptics.selection()
    } label: {
      ZStack {
        Circle()
          .fill(hex.map { Color(hexString: $0) } ?? DLColor.surfaceElevated)
          .frame(width: 28, height: 28)
        if hex == nil {
          Image(systemName: "slash.circle").font(.system(size: 14)).foregroundStyle(DLColor.textSecondary)
        }
        if isSelected {
          Circle().strokeBorder(DLColor.textPrimary, lineWidth: 2).frame(width: 34, height: 34)
        }
      }
      .frame(width: 36, height: 36)
    }
    .buttonStyle(.plain)
  }

  private var tagsRow: some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      if !note.tags.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: DLSpace.sm) {
            ForEach(note.tags, id: \.self) { tag in
              HStack(spacing: 4) {
                Text("#\(tag)").font(.dl(.caption, weight: .medium))
                Button { note.tags.removeAll { $0 == tag } } label: {
                  Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                }
              }
              .padding(.horizontal, 10).padding(.vertical, 6)
              .background(theme.accent.opacity(0.14), in: Capsule())
              .foregroundStyle(theme.accent)
            }
          }
        }
      }
      HStack {
        Image(systemName: "tag").foregroundStyle(DLColor.textTertiary)
        TextField(L("Add tag"), text: $newTag)
          .onSubmit(addTag)
        if !newTag.isEmpty {
          Button(L("Add"), action: addTag).font(.dl(.caption, weight: .semibold))
        }
      }
    }
  }

  // MARK: Media

  private var mediaSection: some View {
    MediaPickerField(
      attachments: note.sortedAttachments,
      onAddImage: { data in addAttachment(data: data, type: .image, ext: "jpg") },
      onAddVideo: { data, ext in addAttachment(data: data, type: .video, ext: ext) },
      onDelete: deleteAttachment,
      onAddAudio: addAudioAttachment
    )
  }

  // MARK: Floating toolbar

  private var toolbar: some View {
    HStack(spacing: DLSpace.sm) {
      Menu {
        Button(L("Bold")) { insertMarker("**bold**") }
        Button(L("Italic")) { insertMarker("_italic_") }
        Button(L("Highlight")) { insertMarker("==highlight==") }
        Button(L("Bullet")) { insertMarker("\n- ") }
      } label: { toolIcon("textformat") }

      toolButton(previewing ? "eye.fill" : "eye", L("Preview")) {
        withAnimation(DLAnim.quick) { previewing.toggle() }
        if previewing { KeyboardHelper.dismiss() }
      }

      toolButton("camera.fill", L("Camera")) {
        if UIImagePickerController.isSourceTypeAvailable(.camera) { showCamera = true }
      }

      toolButton(recorder.isRecording ? "stop.circle.fill" : "waveform", L("Voice memo")) { toggleVoiceMemo() }

      toolButton(dictator.isRecording ? "mic.fill" : "mic", L("Dictate")) {
        Task { if await SpeechDictator.requestAuthorization() { dictator.toggle() } }
      }

      toolButton("location", L("Location")) {
        Haptics.light()
        showLocationPicker = true
      }

      toolButton("arrow.uturn.backward", L("Undo")) {
        if let snap = undoSnapshot { bodyDraft = snap; Haptics.light() }
      }
    }
    .padding(.horizontal, DLSpace.sm)
    .padding(.vertical, DLSpace.sm)
    .glass(cornerRadius: DLRadius.pill)
    .padding(.bottom, DLSpace.sm)
    .frame(maxWidth: .infinity)   // keep the pill compact and centered, with side margins
  }

  private func toolIcon(_ system: String) -> some View {
    Image(systemName: system)
      .font(.system(size: 18, weight: .semibold))
      .foregroundStyle(theme.accent)
      .frame(width: 32, height: 32)
  }

  private func toolButton(_ system: String, _ label: String, action: @escaping () -> Void) -> some View {
    Button(action: { action() }) { toolIcon(system) }
      .buttonStyle(.plain)
      .bounceTap()
      .accessibilityLabel(label)
  }

  private func recordingBanner(_ text: String, color: Color) -> some View {
    HStack(spacing: DLSpace.sm) {
      Circle().fill(color).frame(width: 10, height: 10)
      Text(text).font(.dl(.caption, weight: .semibold)).foregroundStyle(DLColor.textPrimary)
    }
    .padding(.horizontal, DLSpace.sm).padding(.vertical, DLSpace.xs)
    .glass(cornerRadius: DLRadius.pill)
  }

  // MARK: Actions

  private func addTag() {
    let raw = newTag.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().replacingOccurrences(of: "#", with: "")
    guard !raw.isEmpty, !note.tags.contains(raw) else { newTag = ""; return }
    note.tags.append(raw)
    newTag = ""
    Haptics.light()
  }

  private func insertMarker(_ marker: String) {
    undoSnapshot = bodyDraft
    bodyDraft += (bodyDraft.isEmpty || bodyDraft.hasSuffix(" ") || bodyDraft.hasSuffix("\n") ? "" : " ") + marker + " "
    Haptics.light()
  }

  private func appendToBody(_ transcript: String) {
    let captured = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !captured.isEmpty else { return }
    undoSnapshot = bodyDraft
    bodyDraft += (bodyDraft.isEmpty ? "" : (bodyDraft.hasSuffix(" ") ? "" : " ")) + captured
    Haptics.success()
  }

  /// Debounced write-back of the edit buffers to the model (coalesces keystrokes,
  /// so the SwiftData mutation + autosave happens a few times a second at most).
  private func scheduleCommit() {
    commitTask?.cancel()
    commitTask = Task { @MainActor in
      try? await Task.sleep(nanoseconds: 300_000_000)
      guard !Task.isCancelled else { return }
      commitDrafts()
    }
  }

  /// Flush the edit buffers into the model (no save; the context autosaves).
  private func commitDrafts() {
    if note.title != titleDraft { note.title = titleDraft }
    if note.text != bodyDraft { note.text = bodyDraft }
  }

  private func toggleVoiceMemo() {
    if recorder.isRecording {
      if let name = recorder.stop() {
        let media = MediaAttachment(fileName: name, type: .audio, order: note.attachments.count)
        media.note = note
        context.insert(media)
        try? context.save()
        Haptics.success()
      }
    } else {
      Task {
        if await AudioRecorder.requestPermission() { recorder.start() }
      }
    }
  }

  private func addAttachment(data: Data, type: MediaType, ext: String) {
    guard let name = MediaStore.save(data, ext: ext) else { return }
    let media = MediaAttachment(fileName: name, type: type, order: note.attachments.count)
    media.note = note
    context.insert(media)
    try? context.save()
  }

  /// Attaches an already-saved audio file (recorded or imported) to the note.
  private func addAudioAttachment(_ fileName: String) {
    let media = MediaAttachment(fileName: fileName, type: .audio, order: note.attachments.count)
    media.note = note
    context.insert(media)
    try? context.save()
  }

  private func addCamera(_ image: UIImage) {
    guard let data = image.jpegData(compressionQuality: 0.9) else { return }
    addAttachment(data: data, type: .image, ext: "jpg")
  }

  // MARK: Location actions

  private func addLocation(name: String, latitude: Double, longitude: Double) {
    let place = NoteLocation(name: name, latitude: latitude, longitude: longitude, order: note.locations.count)
    place.note = note
    context.insert(place)
    try? context.save()
  }

  private func removeLocation(_ place: NoteLocation) {
    context.delete(place)
    try? context.save()
    Haptics.selection()
  }

  /// One-time migration: fold a legacy single location (from older notes) into
  /// the new multi-location list so it stays visible and manageable.
  private func migrateLegacyLocation() {
    guard note.locations.isEmpty, let lat = note.latitude, let lon = note.longitude else { return }
    let place = NoteLocation(name: note.locationName ?? L("Location"), latitude: lat, longitude: lon, order: 0)
    place.note = note
    context.insert(place)
    note.locationName = nil
    note.latitude = nil
    note.longitude = nil
    try? context.save()
  }

  private func deleteAttachment(_ media: MediaAttachment) {
    MediaStore.delete(media.fileName)
    context.delete(media)
    try? context.save()
  }

  private func save() {
    didFinalize = true
    commitTask?.cancel()
    if recorder.isRecording { _ = recorder.stop() }
    if dictator.isRecording { dictator.toggle() }
    note.title = titleDraft.trimmingCharacters(in: .whitespaces)
    note.text = bodyDraft
    note.updatedAt = Date()
    try? context.save()
    Haptics.success()
    dismiss()
  }

  private func cancel() {
    didFinalize = true
    commitTask?.cancel()
    if recorder.isRecording { _ = recorder.stop() }
    if dictator.isRecording { dictator.toggle() }
    let empty = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && bodyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && note.attachments.isEmpty
    if isNew && empty {
      for media in note.attachments { MediaStore.delete(media.fileName) }
      context.delete(note)
      try? context.save()
    } else {
      // Cancel keeps edits for an existing/non-empty note (the prior live-binding
      // behaviour); flush the buffers so nothing typed is lost.
      commitDrafts()
      note.updatedAt = Date()
      try? context.save()
    }
    dismiss()
  }

  private func timeString(_ t: TimeInterval) -> String {
    let s = Int(t)
    return String(format: "%d:%02d", s / 60, s % 60)
  }
}

// MARK: - Camera

private struct CameraPicker: UIViewControllerRepresentable {
  var onImage: (UIImage) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: CameraPicker
    init(_ parent: CameraPicker) { self.parent = parent }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
      if let image = info[.originalImage] as? UIImage { parent.onImage(image) }
      picker.presentingViewController?.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.presentingViewController?.dismiss(animated: true)
    }
  }
}
