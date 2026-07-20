import SwiftUI
import UIKit

/// Wraps UIKit's UIImagePickerController with `allowsEditing` so the user gets
/// the built-in square pan-and-zoom crop UI — ideal for avatars and free of any
/// third-party dependency. Returns the cropped image via `onPick`.
struct ImagePicker: UIViewControllerRepresentable {
    enum Source { case photoLibrary, camera }

    let source: Source
    /// When true (default) UIKit shows its built-in square crop UI — right for
    /// avatars. Banners pass false to receive the raw image and crop wide via Mantis.
    var allowsEditing: Bool = true
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.allowsEditing = allowsEditing
        picker.delegate = context.coordinator
        switch source {
        case .photoLibrary:
            picker.sourceType = .photoLibrary
        case .camera:
            picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Prefer the cropped/edited image; fall back to the original.
            let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
            if let image {
                parent.onPick(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

extension UIImage {
    /// Re-encodes the image as JPEG, downscaling so the longest edge is at most
    /// `maxDimension`. Keeps avatar uploads comfortably under the 5MB backend cap.
    func avatarJPEGData(maxDimension: CGFloat = 1000, quality: CGFloat = 0.85) -> Data? {
        let longest = max(size.width, size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
