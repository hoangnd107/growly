import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

/// A labeled media section: a PhotosPicker (images + videos), an optional voice
/// recorder, plus a horizontal grid of the current attachments, each a
/// `MediaViewer` with a delete button.
///
/// The parent owns persistence — this view only loads the picked `Data` (or the
/// recorded audio file name) and reports it back via the closures, deciding image
/// vs. video from the picked item's `supportedContentTypes`.
struct MediaPickerField: View {
  let attachments: [MediaAttachment]
  let onAddImage: (Data) -> Void
  let onAddVideo: (Data, String) -> Void
  let onDelete: (MediaAttachment) -> Void
  /// When provided, a mic button appears and a recorded `.m4a` file name is
  /// reported back so the parent can attach it as an audio attachment.
  var onAddAudio: ((String) -> Void)? = nil

  @State private var selection: [PhotosPickerItem] = []
  @State private var isImporting = false
  @StateObject private var recorder = AudioRecorder()

  private let thumbSize: CGFloat = 96

  var body: some View {
    VStack(alignment: .leading, spacing: DLSpace.sm) {
      header

      if recorder.isRecording {
        recordingBanner
      }

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
    HStack(spacing: DLSpace.sm) {
      Label(L("Add media"), systemImage: "photo.on.rectangle.angled")
        .font(.dl(.subheadline, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)

      Spacer()

      if onAddAudio != nil {
        Button {
          toggleRecording()
        } label: {
          Image(systemName: recorder.isRecording ? "stop.circle.fill" : "mic.circle.fill")
            .font(.system(size: 26))
            .foregroundStyle(recorder.isRecording ? Color(hex: 0xFF3B30) : Color.accentColor)
            .symbolEffect(.pulse, isActive: recorder.isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(recorder.isRecording ? L("Stop") : L("Voice memo"))
      }

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

  private var recordingBanner: some View {
    HStack(spacing: DLSpace.sm) {
      Circle().fill(Color(hex: 0xFF3B30)).frame(width: 10, height: 10)
      Text(Lf("Recording %@", timeString(recorder.elapsed)))
        .font(.dl(.caption, weight: .semibold))
        .foregroundStyle(DLColor.textPrimary)
        .monospacedDigit()
      Spacer()
    }
    .padding(.horizontal, DLSpace.sm)
    .padding(.vertical, DLSpace.xs)
    .background(Color(hex: 0xFF3B30).opacity(0.12), in: Capsule())
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

  // MARK: - Recording

  private func toggleRecording() {
    if recorder.isRecording {
      if let name = recorder.stop() {
        onAddAudio?(name)
        Haptics.success()
      }
    } else {
      Task {
        if await AudioRecorder.requestPermission() { recorder.start() }
      }
    }
  }

  private func timeString(_ t: TimeInterval) -> String {
    let s = Int(t)
    return String(format: "%d:%02d", s / 60, s % 60)
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
