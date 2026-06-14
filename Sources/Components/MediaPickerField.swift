import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

/// A labeled media section: a PhotosPicker (images + videos) plus a horizontal
/// grid of the current attachments, each a `MediaViewer` with a delete button.
///
/// The parent owns persistence — this view only loads the picked `Data` and
/// reports it back via the closures, deciding image vs. video from the picked
/// item's `supportedContentTypes`.
struct MediaPickerField: View {
  let attachments: [MediaAttachment]
  let onAddImage: (Data) -> Void
  let onAddVideo: (Data, String) -> Void
  let onDelete: (MediaAttachment) -> Void

  @State private var selection: [PhotosPickerItem] = []
  @State private var isImporting = false

  private let thumbSize: CGFloat = 96

  var body: some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      header

      if !attachments.isEmpty {
        thumbnailRow
      }
    }
    .onChange(of: selection) { _, items in
      guard !items.isEmpty else { return }
      importItems(items)
    }
  }

  // MARK: - Header / picker

  private var header: some View {
    HStack {
      Label(L("Add media"), systemImage: "photo.on.rectangle.angled")
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)

      Spacer()

      PhotosPicker(
        selection: $selection,
        maxSelectionCount: 10,
        matching: .any(of: [.images, .videos])
      ) {
        if isImporting {
          ProgressView()
            .frame(height: 22)
        } else {
          Label(L("Add"), systemImage: "plus")
            .font(.dl(.subheadline, weight: .semibold))
            .foregroundStyle(Color.accentColor)
        }
      }
      .disabled(isImporting)
      .accessibilityLabel(L("Add media"))
    }
  }

  // MARK: - Thumbnail grid

  private var thumbnailRow: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: DLSpace.sm) {
        ForEach(attachments.sorted { $0.order < $1.order }) { attachment in
          MediaViewer(attachment: attachment, size: thumbSize)
            .overlay(alignment: .topTrailing) {
              Button(role: .destructive) {
                Haptics.selection()
                onDelete(attachment)
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(.white, .black.opacity(0.55))
                  .padding(4)
              }
              .accessibilityLabel(L("Delete"))
            }
        }
      }
      .padding(.horizontal, 2)
      .padding(.vertical, 2)
    }
  }

  // MARK: - Import

  private func importItems(_ items: [PhotosPickerItem]) {
    isImporting = true
    Task {
      for item in items {
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        if let data = try? await item.loadTransferable(type: Data.self) {
          await MainActor.run {
            if isVideo {
              onAddVideo(data, "mov")
            } else {
              onAddImage(data)
            }
          }
        }
      }
      await MainActor.run {
        selection = []
        isImporting = false
      }
    }
  }
}
