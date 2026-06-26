import SwiftUI
import UIKit

/// A full-screen camera that can both take a photo AND record video — the
/// Photo/Video mode toggle is the system camera UI's built-in switch. Falls back
/// to the photo library when no camera is available (e.g. Simulator).
///
/// Shared by the note editor and the finance transaction editor.
struct CameraCaptureView: UIViewControllerRepresentable {
  var onImage: (UIImage) -> Void
  var onVideo: (URL) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
    let source: UIImagePickerController.SourceType = cameraAvailable ? .camera : .photoLibrary
    picker.sourceType = source
    // Offer both still photo and video capture; the user picks the mode in the UI.
    picker.mediaTypes = UIImagePickerController.availableMediaTypes(for: source) ?? ["public.image"]
    picker.videoQuality = .typeHigh
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator { Coordinator(self) }

  final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: CameraCaptureView
    init(_ parent: CameraCaptureView) { self.parent = parent }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let videoURL = info[.mediaURL] as? URL {
        parent.onVideo(videoURL)
      } else if let image = info[.originalImage] as? UIImage {
        parent.onImage(image)
      }
      picker.presentingViewController?.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      picker.presentingViewController?.dismiss(animated: true)
    }
  }
}
