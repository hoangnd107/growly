import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import AVKit

/// A labeled media section: a PhotosPicker (images + videos), optional voice
/// recording, optional audio-file import, plus a horizontal grid of the current
/// attachments. Each thumbnail has a delete button and a download button (which
/// shares the underlying file so it can be saved to Photos / Files).
///
/// The parent owns persistence — this view loads the picked `Data` (or the
/// recorded/imported audio file name) and reports it back via the closures.
struct MediaPickerField: View {
  let attachments: [MediaAttachment]
  let onAddImage: (Data) -> Void
  let onAddVideo: (Data, String) -> Void
  let onDelete: (MediaAttachment) -> Void
  /// When provided, an "import audio file" button appears and any
  /// recorded/imported `.m4a`/`.mp3`/… file name is reported back to attach.
  var onAddAudio: ((String) -> Void)? = nil
  /// When true (and `onAddAudio` is set), a mic button records a voice memo.
  var showVoiceRecorder: Bool = false

  @State private var selection: [PhotosPickerItem] = []
  @State private var isImporting = false
  @State private var showAudioImporter = false
  @StateObject private var recorder = AudioRecorder()

  /// Wraps a file URL so it can drive a share `.sheet(item:)`.
  private struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
  }
  @State private var shareItem: ShareItem?

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
    .fileImporter(
      isPresented: $showAudioImporter,
      allowedContentTypes: [.audio],
      allowsMultipleSelection: true
    ) { result in
      importAudioFiles(result)
    }
    .sheet(item: $shareItem) { item in
      ShareSheet(items: [item.url])
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
          showAudioImporter = true
        } label: {
          Image(systemName: "waveform.badge.plus")
            .font(.system(size: 24))
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("Attach audio file"))

        if showVoiceRecorder {
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
            .overlay(alignment: .bottomLeading) {
              Button {
                Haptics.light()
                shareItem = ShareItem(url: MediaStore.url(for: attachment.fileName))
              } label: {
                Image(systemName: "square.and.arrow.down")
                  .font(.system(size: 15, weight: .semibold))
                  .foregroundStyle(.white)
                  .padding(6)
                  .background(.black.opacity(0.45), in: Circle())
                  .padding(4)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(L("Download"))
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

  /// Copies imported audio files (any format, e.g. `.m4a`, `.mp3`, `.wav`) into
  /// the media store and reports each file name back to attach.
  private func importAudioFiles(_ result: Result<[URL], Error>) {
    guard case .success(let urls) = result else { return }
    for url in urls {
      let scoped = url.startAccessingSecurityScopedResource()
      defer { if scoped { url.stopAccessingSecurityScopedResource() } }
      let ext = url.pathExtension.isEmpty ? "m4a" : url.pathExtension
      if let data = try? Data(contentsOf: url), let name = MediaStore.save(data, ext: ext) {
        onAddAudio?(name)
      }
    }
    Haptics.success()
  }
}
