import SwiftUI
import Mantis
import UIKit

// Extension to fix image orientation
extension UIImage {
    func fixedOrientation() -> UIImage {
        // If orientation is already up, return as is
        if imageOrientation == .up {
            return self
        }
        
        // We need to calculate the proper transformation to make the image upright.
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        guard let cgImage = cgImage else {
            return self
        }
        
        guard let colorSpace = cgImage.colorSpace else {
            return self
        }
        
        let ctx = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: cgImage.bitmapInfo.rawValue
        )
        
        guard let context = ctx else {
            return self
        }
        
        context.concatenate(transform)
        
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
        
        guard let cgimg = context.makeImage() else {
            return self
        }
        
        return UIImage(cgImage: cgimg)
    }
}

struct ImageCropper: UIViewControllerRepresentable {
    // This is the image we want to crop (required, non-nil)
    let image: UIImage
    // This is where we will save the result
    @Binding var croppedImage: UIImage?
    @Environment(\.dismiss) var dismiss
    
    class Coordinator: CropViewControllerDelegate {
        var parent: ImageCropper
        
        init(_ parent: ImageCropper) {
            self.parent = parent
        }
        
        func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            print("✅ ImageCropper Coordinator: Crop completed, image size: \(cropped.size.width)x\(cropped.size.height)")
            parent.croppedImage = cropped
            parent.dismiss()
        }
        
        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            print("⚠️ ImageCropper Coordinator: Crop cancelled")
            parent.dismiss()
        }
        
        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
            print("❌ ImageCropper Coordinator: Crop failed")
            parent.dismiss()
        }
        
        func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) {}
        func cropViewControllerDidEndResize(_ cropViewController: CropViewController, original: UIImage, cropInfo: CropInfo) {}
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> CropViewController {
        print("🖼️ ImageCropper: Creating CropViewController with image size: \(image.size.width)x\(image.size.height)")
        print("🖼️ ImageCropper: Image orientation: \(image.imageOrientation.rawValue)")
        
        // Fix image orientation if needed - ensure it's in the correct orientation
        let fixedImage = image.fixedOrientation()
        
        var config = Mantis.Config()
        // Force circular crop for profile photos
        config.presetFixedRatioType = .alwaysUsingOnePresetFixedRatio(ratio: 1.0)
        config.cropShapeType = .circle(maskOnly: false)
        
        // Pass the fixed image to Mantis
        let cropViewController = Mantis.cropViewController(image: fixedImage, config: config)
        cropViewController.delegate = context.coordinator
        
        // Ensure the view loads properly
        cropViewController.view.backgroundColor = .black
        
        // Force the view to load immediately
        cropViewController.loadViewIfNeeded()
        
        // Don't force layout here - let it happen naturally when view appears
        // Forcing layout too early can cause Mantis to not render properly
        
        print("✅ ImageCropper: CropViewController created, view loaded: \(cropViewController.isViewLoaded)")
        print("✅ ImageCropper: View frame: \(cropViewController.view.frame)")
        
        return cropViewController
    }
    
    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {
        // Ensure the view is properly displayed
        if !uiViewController.isViewLoaded {
            print("⚠️ ImageCropper: View not loaded, forcing load")
            uiViewController.loadViewIfNeeded()
        }
        
        // Force layout update after view appears - this ensures Mantis can render the image
        DispatchQueue.main.async {
            // Wait for the view to be in the hierarchy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard uiViewController.view.superview != nil else {
                    print("⚠️ ImageCropper: View not in hierarchy yet")
                    return
                }
                
                // Ensure proper frame
                let superviewBounds = uiViewController.view.superview?.bounds ?? .zero
                if uiViewController.view.frame != superviewBounds {
                    uiViewController.view.frame = superviewBounds
                }
                
                // Force a complete layout pass
                uiViewController.view.setNeedsLayout()
                uiViewController.view.layoutIfNeeded()
                
                // Force all subviews to layout as well
                uiViewController.view.subviews.forEach { subview in
                    subview.setNeedsLayout()
                    subview.layoutIfNeeded()
                }
                
                // Trigger a view update by accessing the view's window
                if uiViewController.view.window != nil {
                    print("✅ ImageCropper: View is in window, frame: \(uiViewController.view.frame)")
                } else {
                    print("⚠️ ImageCropper: View not in window yet")
                }
            }
        }
    }
}

