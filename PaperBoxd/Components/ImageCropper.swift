import SwiftUI
import UIKit

/// Identifiable wrapper so a picked UIImage can drive a `.fullScreenCover(item:)`.
struct CropTarget: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Self-contained wide-ratio cropper for the profile banner. The image fills a
/// fixed-ratio window (width × width/ratio); the user drags to reposition, and
/// "Use photo" renders exactly the visible region. No third-party dependency.
struct ImageCropper: View {
    let image: UIImage
    /// Crop window aspect ratio (width / height).
    var ratio: CGFloat = 2.3
    let onCrop: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var offset: CGSize = .zero
    @State private var accumulated: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let cropW = geo.size.width
            let cropH = cropW / ratio
            // Fill the window, then allow panning within the overflow.
            let s = max(cropW / image.size.width, cropH / image.size.height)
            let dispW = image.size.width * s
            let dispH = image.size.height * s
            let maxX = max(0, (dispW - cropW) / 2)
            let maxY = max(0, (dispH - cropH) / 2)

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 16) {
                    Spacer()

                    Image(uiImage: image)
                        .resizable()
                        .frame(width: dispW, height: dispH)
                        .offset(x: clamp(offset.width, -maxX, maxX),
                                y: clamp(offset.height, -maxY, maxY))
                        .frame(width: cropW, height: cropH)
                        .clipped()
                        .overlay(Rectangle().stroke(Color.white.opacity(0.85), lineWidth: 1))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { v in
                                    offset = CGSize(width: accumulated.width + v.translation.width,
                                                    height: accumulated.height + v.translation.height)
                                }
                                .onEnded { _ in
                                    offset = CGSize(width: clamp(offset.width, -maxX, maxX),
                                                    height: clamp(offset.height, -maxY, maxY))
                                    accumulated = offset
                                }
                        )

                    Text("Drag to reposition")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))

                    Spacer()

                    HStack {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.white)
                        Spacer()
                        Button("Use photo") {
                            let ox = clamp(offset.width, -maxX, maxX)
                            let oy = clamp(offset.height, -maxY, maxY)
                            if let out = renderCrop(scale: s, dispW: dispW, dispH: dispH,
                                                    cropW: cropW, cropH: cropH, offsetX: ox, offsetY: oy) {
                                onCrop(out)
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(v, lo), hi)
    }

    /// Maps the on-screen crop window back into image-pixel space and renders it.
    private func renderCrop(scale s: CGFloat, dispW: CGFloat, dispH: CGFloat,
                            cropW: CGFloat, cropH: CGFloat, offsetX: CGFloat, offsetY: CGFloat) -> UIImage? {
        let leftPt = (dispW / 2 - offsetX - cropW / 2) / s
        let topPt  = (dispH / 2 - offsetY - cropH / 2) / s
        let wPt = cropW / s
        let hPt = cropH / s

        let normalized = image.normalizedOrientation()
        let px = normalized.scale
        let cropRect = CGRect(x: leftPt * px, y: topPt * px, width: wPt * px, height: hPt * px)
        guard let cg = normalized.cgImage?.cropping(to: cropRect) else { return nil }
        return UIImage(cgImage: cg, scale: px, orientation: .up)
    }
}

private extension UIImage {
    /// Redraws the image with `.up` orientation so CGImage pixel cropping matches
    /// what the user sees on screen.
    func normalizedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
