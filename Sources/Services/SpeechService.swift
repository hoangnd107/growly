import Foundation
import Speech
import AVFoundation

/// On-device dictation for filling reflection/note fields by voice.
/// Requires NSMicrophoneUsageDescription + NSSpeechRecognitionUsageDescription
/// (both set in project.yml). No special entitlement → works on a free sideload.
@MainActor
final class SpeechDictator: ObservableObject {
  @Published private(set) var transcript: String = ""
  @Published private(set) var isRecording = false
  @Published private(set) var unavailable = false

  private let recognizer = SFSpeechRecognizer()
  private let audioEngine = AVAudioEngine()
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?

  static func requestAuthorization() async -> Bool {
    let speechOK: Bool = await withCheckedContinuation { cont in
      SFSpeechRecognizer.requestAuthorization { status in
        cont.resume(returning: status == .authorized)
      }
    }
    guard speechOK else { return false }
    return await withCheckedContinuation { cont in
      AVAudioApplication.requestRecordPermission { granted in
        cont.resume(returning: granted)
      }
    }
  }

  func toggle() {
    isRecording ? stop() : start()
  }

  func start() {
    guard let recognizer, recognizer.isAvailable else {
      unavailable = true
      return
    }
    transcript = ""
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.record, mode: .measurement, options: .duckOthers)
      try session.setActive(true, options: .notifyOthersOnDeactivation)

      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true
      self.request = request

      let input = audioEngine.inputNode
      let format = input.outputFormat(forBus: 0)
      input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
        self?.request?.append(buffer)
      }
      audioEngine.prepare()
      try audioEngine.start()
      isRecording = true

      task = recognizer.recognitionTask(with: request) { [weak self] result, error in
        guard let self else { return }
        if let result {
          let text = result.bestTranscription.formattedString
          Task { @MainActor in self.transcript = text }
        }
        if error != nil || (result?.isFinal ?? false) {
          Task { @MainActor in self.stop() }
        }
      }
    } catch {
      stop()
    }
  }

  func stop() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    request?.endAudio()
    task?.cancel()
    request = nil
    task = nil
    isRecording = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }
}
