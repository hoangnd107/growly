import SwiftUI
import AVKit
import AVFoundation

/// A tappable thumbnail for a `MediaAttachment`. Images load from `MediaStore`;
/// videos show their first frame (with a small play overlay) or a film icon
/// fallback; audio shows a waveform glyph on a glass tile. Tapping opens a
/// full-screen viewer — images are zoomable, videos and audio play via AVKit's
/// `VideoPlayer` (which plays `.m4a` audio with transport controls).
struct MediaViewer: View {
  let attachment: MediaAttachment
  var size: CGFloat = 96

  @State private var image: UIImage?
  @State private var showViewer = false

  var body: some View {
    Button {
      showViewer = true
    } label: {
      thumbnail
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityAddTraits(.isButton)
    .fullScreenCover(isPresented: $showViewer) {
      FullScreenMediaView(attachment: attachment)
    }
    .task(id: attachment.fileName) { await loadThumbnail() }
  }

  // MARK: - Thumbnail

  @ViewBuilder
  private var thumbnail: some View {
    ZStack {
      switch attachment.type {
      case .image, .video:
        if let image {
          Image(uiImage: image)
            .resizable()
            .scaledToFill()
        } else {
          RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
            .fill(DLColor.surfaceElevated)
          Image(systemName: attachment.type == .video ? "film" : "photo")
            .font(.system(size: size * 0.3, weight: .regular))
            .foregroundStyle(DLColor.textTertiary)
        }

        if attachment.type == .video {
          // Subtle scrim + play glyph so videos read as playable.
          LinearGradient(
            colors: [.clear, .black.opacity(0.35)],
            startPoint: .top,
            endPoint: .bottom
          )
          Image(systemName: "play.circle.fill")
            .font(.system(size: size * 0.32, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(radius: 3)
        }

      case .audio:
        // Glass tile with a waveform glyph and a small play badge.
        RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
          .fill(DLColor.surfaceElevated)
        Image(systemName: "waveform")
          .font(.system(size: size * 0.34, weight: .semibold))
          .foregroundStyle(Color.accentColor)
        VStack {
          Spacer()
          HStack {
            Spacer()
            Image(systemName: "play.circle.fill")
              .font(.system(size: size * 0.26, weight: .semibold))
              .foregroundStyle(.white, Color.accentColor)
              .shadow(radius: 2)
              .padding(6)
          }
        }
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous)
        .strokeBorder(DLColor.separator.opacity(0.6), lineWidth: 1)
    )
    .contentShape(RoundedRectangle(cornerRadius: DLRadius.small, style: .continuous))
  }

  private var accessibilityLabel: String {
    switch attachment.type {
    case .image: return L("Photo attachment")
    case .video: return L("Video attachment")
    case .audio: return L("Audio attachment")
    }
  }

  // MARK: - Loading

  private func loadThumbnail() async {
    switch attachment.type {
    case .image:
      let fileName = attachment.fileName
      let loaded = await Task.detached(priority: .userInitiated) {
        MediaStore.loadImage(fileName)
      }.value
      await MainActor.run { image = loaded }
    case .video:
      let url = MediaStore.url(for: attachment.fileName)
      let frame = await Self.firstFrame(of: url)
      await MainActor.run { image = frame }
    case .audio:
      // Audio has no bitmap thumbnail; the static waveform glyph is used.
      break
    }
  }

  /// Generates the first frame of a video for use as a thumbnail.
  private static func firstFrame(of url: URL) async -> UIImage? {
    await Task.detached(priority: .userInitiated) {
      let asset = AVURLAsset(url: url)
      let generator = AVAssetImageGenerator(asset: asset)
      generator.appliesPreferredTrackTransform = true
      generator.maximumSize = CGSize(width: 400, height: 400)
      let time = CMTime(seconds: 0.1, preferredTimescale: 600)
      if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
        return UIImage(cgImage: cg)
      }
      return nil
    }.value
  }
}

// MARK: - Full-screen viewer

/// Full-screen presentation for a single attachment with a dismiss button.
private struct FullScreenMediaView: View {
  let attachment: MediaAttachment
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()

      switch attachment.type {
      case .image:
        ZoomableImageView(fileName: attachment.fileName)
      case .video:
        VideoPlayer(player: AVPlayer(url: MediaStore.url(for: attachment.fileName)))
          .ignoresSafeArea()
      case .audio:
        AudioPlayerView(fileName: attachment.fileName)
      }

      VStack {
        HStack {
          Spacer()
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white)
              .frame(width: 44, height: 44)
              .background(.ultraThinMaterial, in: Circle())
          }
          .accessibilityLabel(L("Done"))
          .padding(DLSpace.md)
        }
        Spacer()
      }
    }
  }
}

/// Full-screen audio playback. Uses AVKit's `VideoPlayer` backed by an
/// `AVPlayer`, which plays `.m4a` audio files and provides standard transport
/// controls (play/pause/scrub). A waveform glyph keeps the screen meaningful
/// since audio has no visual frame.
private struct AudioPlayerView: View {
  let fileName: String

  @State private var player: AVPlayer?

  var body: some View {
    VStack(spacing: DLSpace.xl) {
      Spacer()

      Image(systemName: "waveform")
        .font(.system(size: 88, weight: .semibold))
        .foregroundStyle(.white)
        .accessibilityHidden(true)

      Text(L("Audio attachment"))
        .font(.dl(.headline, weight: .semibold))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)

      if let player {
        VideoPlayer(player: player)
          .frame(height: 120)
          .clipShape(RoundedRectangle(cornerRadius: DLRadius.card, style: .continuous))
          .padding(.horizontal, DLSpace.lg)
      } else {
        ProgressView().tint(.white)
      }

      Spacer()
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding(DLSpace.lg)
    .onAppear {
      let url = MediaStore.url(for: fileName)
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
      try? AVAudioSession.sharedInstance().setActive(true)
      player = AVPlayer(url: url)
    }
    .onDisappear {
      player?.pause()
      player = nil
      try? AVAudioSession.sharedInstance().setActive(false)
    }
  }
}

/// A pinch-to-zoom / drag-to-pan image displayed full screen.
private struct ZoomableImageView: View {
  let fileName: String

  @State private var image: UIImage?
  @State private var scale: CGFloat = 1
  @State private var lastScale: CGFloat = 1
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { _ in
      Group {
        if let image {
          Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
              MagnificationGesture()
                .onChanged { value in
                  scale = min(max(lastScale * value, 1), 5)
                }
                .onEnded { _ in
                  lastScale = scale
                  if scale <= 1 { resetTransform() }
                }
            )
            .simultaneousGesture(
              DragGesture()
                .onChanged { value in
                  guard scale > 1 else { return }
                  offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                  )
                }
                .onEnded { _ in lastOffset = offset }
            )
            .onTapGesture(count: 2) {
              if reduceMotion {
                toggleZoom()
              } else {
                withAnimation(DLAnim.standard) { toggleZoom() }
              }
            }
        } else {
          ProgressView().tint(.white)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .task(id: fileName) {
      let name = fileName
      let loaded = await Task.detached(priority: .userInitiated) {
        MediaStore.loadImage(name)
      }.value
      image = loaded
    }
  }

  private func toggleZoom() {
    if scale > 1 {
      resetTransform()
    } else {
      scale = 2.5
      lastScale = 2.5
    }
  }

  private func resetTransform() {
    scale = 1
    lastScale = 1
    offset = .zero
    lastOffset = .zero
  }
}
