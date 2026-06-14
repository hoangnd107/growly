import Foundation
import AVFoundation

/// Records a voice memo to Documents/media (.m4a) for attaching to notes/entries.
/// Needs NSMicrophoneUsageDescription (set). No special entitlement.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
  @Published private(set) var isRecording = false
  @Published private(set) var elapsed: TimeInterval = 0

  private var recorder: AVAudioRecorder?
  private var timer: Timer?
  private(set) var fileName: String?

  static func requestPermission() async -> Bool {
    await withCheckedContinuation { cont in
      AVAudioApplication.requestRecordPermission { granted in cont.resume(returning: granted) }
    }
  }

  func start() {
    let name = "\(UUID().uuidString).m4a"
    let url = MediaStore.url(for: name)
    let settings: [String: Any] = [
      AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
      AVSampleRateKey: 44_100.0,
      AVNumberOfChannelsKey: 1,
      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
    ]
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playAndRecord, mode: .default)
      try session.setActive(true)
      let recorder = try AVAudioRecorder(url: url, settings: settings)
      recorder.record()
      self.recorder = recorder
      fileName = name
      isRecording = true
      elapsed = 0
      timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
        Task { @MainActor in
          guard let self else { return }
          self.elapsed = self.recorder?.currentTime ?? 0
        }
      }
    } catch {
      isRecording = false
    }
  }

  /// Stops recording and returns the saved file name (nil if nothing recorded).
  @discardableResult
  func stop() -> String? {
    recorder?.stop()
    recorder = nil
    timer?.invalidate()
    timer = nil
    isRecording = false
    try? AVAudioSession.sharedInstance().setActive(false)
    return fileName
  }
}
