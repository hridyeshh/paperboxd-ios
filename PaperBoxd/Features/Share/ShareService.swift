import SwiftUI
import UIKit

/// Image rendering + share destinations for the book share card.
enum ShareService {

    /// Rasterises a SwiftUI view drawn at `baseSize` points, scaled up so the
    /// exported image is full-resolution (e.g. base 450×800 @ 2.4 → 1080×1920).
    @MainActor
    static func render<V: View>(_ view: V, baseSize: CGSize, scale: CGFloat) -> UIImage? {
        let renderer = ImageRenderer(content:
            view.frame(width: baseSize.width, height: baseSize.height)
        )
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Whether Instagram Stories sharing is available on this device.
    static var canShareToInstagramStories: Bool {
        guard let url = URL(string: "instagram-stories://share") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Hands the rendered card to Instagram Stories as the background image —
    /// the same mechanism Spotify/Apple Music use. Requires `instagram-stories`
    /// in LSApplicationQueriesSchemes.
    static func shareToInstagramStories(image: UIImage, sourceAppID: String) {
        guard let data = image.pngData(),
              let url = URL(string: "instagram-stories://share?source_application=\(sourceAppID)")
        else { return }

        let items: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": data,
        ]
        UIPasteboard.general.setItems(
            [items],
            options: [.expirationDate: Date().addingTimeInterval(60 * 5)]
        )
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    /// Saves the rendered card to the photo library (add-only authorisation).
    static func saveToPhotos(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        PhotoSaver.shared.save(image, completion: completion)
    }
}

/// Tiny NSObject bridge for UIImageWriteToSavedPhotosAlbum's selector callback.
private final class PhotoSaver: NSObject {
    static let shared = PhotoSaver()
    private var completion: ((Bool) -> Void)?

    func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinish(_:error:contextInfo:)), nil)
    }

    @objc private func didFinish(_ image: UIImage, error: Error?, contextInfo: UnsafeRawPointer) {
        let success = error == nil
        DispatchQueue.main.async { [weak self] in
            self?.completion?(success)
            self?.completion = nil
        }
    }
}

/// UIActivityViewController bridge for the "More" system share option.
struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

extension UIImage {
    /// Dominant-ish color via 1x1 area average — used to tint the card backdrop.
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extent = inputImage.extent
        let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: inputImage,
            kCIInputExtentKey: CIVector(cgRect: extent),
        ])
        guard let outputImage = filter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }
}
