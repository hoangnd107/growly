import SwiftUI
import SwiftData

/// Create or edit a `DayNote`. Supports title, multi-line body, an editable
/// creation date, an optional clearable mood, tag chips, a color label, a
/// pinned toggle, and media attachments via `MediaPickerField`.
///
/// For a NEW note the model is created and inserted on appear so attachment
/// relationships can be wired immediately; if the user cancels with no content,
/// the empty note is deleted again.
struct NoteEditorView: View {
  @Environment(\.modelContext) private var context
  @Environment(\.dismiss) private var dismiss

  /// The note being edited; nil means "create new".
  private let existingNote: DayNote?

  /// Resolved working note (created on appear for the new-note case).
  @State private var note: DayNote?
  @State private var didCreateNote = false

  // Editable fields, mirrored to the model on save / immediately for media.
  @State private var title = ""
  @State private var bodyText = ""
  @State private var createdAt = Date()
  @State private var moodRaw: Int?
  @State private var tags: [String] = []
  @State private var colorHex: String?
  @State private var pinned = false
  @State private var newTag = ""

  init(note: DayNote?) {
    self.existingNote = note
  }

  private var isNew: Bool { existingNote == nil }

  /// Preset label colors (hex). `nil` = no label.
  private let presetColors: [String] = [
    "FF3D5A", // red
    "FF9F0A", // orange
    "FFC83D", // gold
    "34C759", // green
    "5AC8FA", // blue
    "AF8CFF", // purple
  ]

  // MARK: - Body

  var body: some View {
    ZStack {
      DLColor.background.ignoresSafeArea()

      ScrollView {
        VStack(spacing: DLSpace.lg) {
          titleCard
          bodyCard
          detailsCard
          tagsCard
          colorCard
          mediaCard
        }
        .padding(DLSpace.md)
      }
      .scrollDismissesKeyboard(.interactively)
    }
    .navigationTitle(isNew ? L("New note") : L("Edit note"))
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button(L("Cancel")) { cancel() }
      }
      ToolbarItem(placement: .topBarTrailing) {
        Button(L("Save")) { save() }
          .fontWeight(.semibold)
          .disabled(!hasContent)
      }
    }
    .keyboardDismissButton()
    .onAppear(perform: setup)
  }

  // MARK: - Cards

  private var titleCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Title"))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
        TextField(L("Title"), text: $title)
          .font(.dl(.title3, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)
          .textInputAutocapitalization(.sentences)
      }
    }
  }

  private var bodyCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Note"))
          .font(.dl(.caption, weight: .semibold))
          .foregroundStyle(DLColor.textTertiary)
        TextField(L("Write your note..."), text: $bodyText, axis: .vertical)
          .lineLimit(4...20)
          .font(.dl(.body))
          .foregroundStyle(DLColor.textPrimary)
      }
    }
  }

  private var detailsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.md) {
        DatePicker(
          L("Created"),
          selection: $createdAt,
          displayedComponents: [.date, .hourAndMinute]
        )
        .font(.dl(.subheadline, weight: .medium))
        .foregroundStyle(DLColor.textPrimary)

        Divider().overlay(DLColor.separator)

        Toggle(isOn: $pinned) {
          Label(L("Pinned"), systemImage: "pin.fill")
            .font(.dl(.subheadline, weight: .medium))
            .foregroundStyle(DLColor.textPrimary)
        }
        .tint(DLColor.xpGold)

        Divider().overlay(DLColor.separator)

        VStack(alignment: .leading, spacing: DLSpace.sm) {
          Text(L("Mood & Energy"))
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(DLColor.textPrimary)
          HStack(spacing: DLSpace.sm) {
            ForEach(Mood.allCases) { mood in
              moodButton(mood)
            }
            Spacer()
            if moodRaw != nil {
              Button {
                withAnimation(DLAnim.quick) { moodRaw = nil }
                Haptics.selection()
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(DLColor.textTertiary)
              }
              .accessibilityLabel(L("Clear mood"))
            }
          }
        }
      }
    }
  }

  private func moodButton(_ mood: Mood) -> some View {
    let isSelected = moodRaw == mood.rawValue
    return Button {
      withAnimation(DLAnim.quick) {
        moodRaw = isSelected ? nil : mood.rawValue
      }
      Haptics.selection()
    } label: {
      Text(mood.emoji)
        .font(.system(size: 26))
        .frame(width: 44, height: 44)
        .background(
          isSelected ? mood.color.opacity(0.25) : Color.clear,
          in: Circle()
        )
        .overlay(
          Circle().strokeBorder(isSelected ? mood.color : Color.clear, lineWidth: 2)
        )
        .opacity(isSelected || moodRaw == nil ? 1 : 0.5)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(mood.label)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var tagsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Tags"))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)

        if !tags.isEmpty {
          NoteFlowLayout(spacing: DLSpace.sm) {
            ForEach(tags, id: \.self) { tag in
              tagChip(tag)
            }
          }
        }

        HStack(spacing: DLSpace.sm) {
          TextField(L("Add tag"), text: $newTag)
            .font(.dl(.subheadline))
            .foregroundStyle(DLColor.textPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .onSubmit(addTag)
          Button {
            addTag()
          } label: {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 22))
              .foregroundStyle(Color.accentColor)
          }
          .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          .accessibilityLabel(L("Add"))
        }
      }
    }
  }

  private func tagChip(_ tag: String) -> some View {
    HStack(spacing: 4) {
      Text("#\(tag)")
        .font(.dl(.caption, weight: .medium))
      Button {
        withAnimation(DLAnim.quick) {
          tags.removeAll { $0 == tag }
        }
        Haptics.selection()
      } label: {
        Image(systemName: "xmark.circle.fill")
          .font(.system(size: 14))
          .foregroundStyle(DLColor.textTertiary)
      }
      .accessibilityLabel(Lf("Remove tag %@", tag))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(DLColor.surfaceElevated, in: Capsule())
    .foregroundStyle(DLColor.textSecondary)
  }

  private var colorCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: DLSpace.sm) {
        Text(L("Accent color"))
          .font(.dl(.subheadline, weight: .semibold))
          .foregroundStyle(DLColor.textPrimary)

        HStack(spacing: DLSpace.md) {
          // "None" swatch.
          colorSwatch(hex: nil)
          ForEach(presetColors, id: \.self) { hex in
            colorSwatch(hex: hex)
          }
          Spacer()
        }
      }
    }
  }

  private func colorSwatch(hex: String?) -> some View {
    let isSelected = colorHex == hex
    return Button {
      withAnimation(DLAnim.quick) { colorHex = hex }
      Haptics.selection()
    } label: {
      ZStack {
        if let hex {
          Circle().fill(Color(hexString: hex))
        } else {
          Circle()
            .fill(DLColor.surfaceElevated)
            .overlay(
              Image(systemName: "slash.circle")
                .font(.system(size: 16))
                .foregroundStyle(DLColor.textTertiary)
            )
        }
      }
      .frame(width: 34, height: 34)
      .overlay(
        Circle().strokeBorder(
          isSelected ? DLColor.textPrimary : DLColor.separator,
          lineWidth: isSelected ? 2.5 : 1
        )
      )
    }
    .buttonStyle(.plain)
    .frame(width: 44, height: 44)
    .accessibilityLabel(hex == nil ? L("No color") : Lf("Color %@", hex!))
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }

  private var mediaCard: some View {
    GlassCard {
      MediaPickerField(
        attachments: note?.sortedAttachments ?? [],
        onAddImage: addImage,
        onAddVideo: addVideo,
        onDelete: deleteAttachment
      )
    }
  }

  // MARK: - Content gating

  private var hasContent: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      || !tags.isEmpty
      || !(note?.attachments.isEmpty ?? true)
  }

  // MARK: - Lifecycle

  private func setup() {
    if let existingNote {
      note = existingNote
      title = existingNote.title
      bodyText = existingNote.text
      createdAt = existingNote.createdAt
      moodRaw = existingNote.moodRaw
      tags = existingNote.tags
      colorHex = existingNote.colorHex
      pinned = existingNote.pinned
    } else if note == nil {
      // Create-and-insert up front so media attachments can be related.
      let fresh = DayNote()
      context.insert(fresh)
      note = fresh
      didCreateNote = true
      createdAt = fresh.createdAt
    }
  }

  // MARK: - Tags

  private func addTag() {
    let trimmed = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let normalized = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
    guard !normalized.isEmpty, !tags.contains(normalized) else {
      newTag = ""
      return
    }
    withAnimation(DLAnim.quick) {
      tags.append(normalized)
    }
    newTag = ""
    Haptics.selection()
  }

  // MARK: - Media

  private func addImage(_ data: Data) {
    guard let note, let fileName = MediaStore.save(data, ext: "jpg") else { return }
    let attachment = MediaAttachment(fileName: fileName, type: .image, order: note.attachments.count)
    attachment.note = note
    context.insert(attachment)
    try? context.save()
  }

  private func addVideo(_ data: Data, _ ext: String) {
    guard let note, let fileName = MediaStore.save(data, ext: ext) else { return }
    let attachment = MediaAttachment(fileName: fileName, type: .video, order: note.attachments.count)
    attachment.note = note
    context.insert(attachment)
    try? context.save()
  }

  private func deleteAttachment(_ attachment: MediaAttachment) {
    MediaStore.delete(attachment.fileName)
    context.delete(attachment)
    try? context.save()
  }

  // MARK: - Save / Cancel

  private func save() {
    guard let note else { dismiss(); return }
    note.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    note.text = bodyText
    note.createdAt = createdAt
    note.moodRaw = moodRaw
    note.tags = tags
    note.colorHex = colorHex
    note.pinned = pinned
    note.updatedAt = Date()
    // New notes were already inserted on appear, so a plain save persists both.
    try? context.save()
    Haptics.light()
    dismiss()
  }

  private func cancel() {
    // For a freshly-created note with nothing in it, discard so we don't leave
    // an empty ghost note behind.
    if didCreateNote, let note, !hasContent {
      for attachment in note.attachments {
        MediaStore.delete(attachment.fileName)
      }
      context.delete(note)
      try? context.save()
    }
    dismiss()
  }
}

// MARK: - Wrapping layout for tag chips

/// Minimal wrapping layout (iOS 16+ `Layout`) so tag chips flow to new rows.
private struct NoteFlowLayout: Layout {
  var spacing: CGFloat = DLSpace.sm

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    var totalWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > maxWidth, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
      totalWidth = max(totalWidth, x - spacing)
    }
    return CGSize(width: min(totalWidth, maxWidth), height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
    let maxWidth = bounds.width
    var x: CGFloat = bounds.minX
    var y: CGFloat = bounds.minY
    var rowHeight: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
