import SwiftUI
import Mantis

struct ImageCropper: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    class Coordinator: CropViewControllerDelegate {
        var parent: ImageCropper
        
        init(_ parent: ImageCropper) {
            self.parent = parent
        }
        
        func cropViewControllerDidCrop(_ cropViewController: CropViewController, cropped: UIImage, transformation: Transformation, cropInfo: CropInfo) {
            parent.image = cropped
            parent.dismiss()
        }
        
        func cropViewControllerDidCancel(_ cropViewController: CropViewController, original: UIImage) {
            parent.dismiss()
        }
        
        func cropViewControllerDidFailToCrop(_ cropViewController: CropViewController, original: UIImage) {
            parent.dismiss()
        }
        
        func cropViewControllerDidBeginResize(_ cropViewController: CropViewController) {}
        func cropViewControllerDidEndResize(_ cropViewController: CropViewController, original: UIImage, cropInfo: CropInfo) {}
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> CropViewController {
        guard let image = image else {
            // Return a default crop view controller if image is nil
            let defaultImage = UIImage(systemName: "person.circle.fill") ?? UIImage()
            var config = Mantis.Config()
            config.presetFixedRatioType = .alwaysUsingOnePresetFixedRatio(ratio: 1.0)
            config.cropShapeType = .circle(maskOnly: false)
            let cropViewController = Mantis.cropViewController(image: defaultImage, config: config)
            cropViewController.delegate = context.coordinator
            cropViewController.view.translatesAutoresizingMaskIntoConstraints = false
            return cropViewController
        }
        
        var config = Mantis.Config()
        // Force circular crop for profile photos
        config.presetFixedRatioType = .alwaysUsingOnePresetFixedRatio(ratio: 1.0)
        config.cropShapeType = .circle(maskOnly: false)
        
        let cropViewController = Mantis.cropViewController(image: image, config: config)
        cropViewController.delegate = context.coordinator
        
        // Suppress Auto Layout warnings by ensuring proper view hierarchy
        cropViewController.view.translatesAutoresizingMaskIntoConstraints = false
        
        return cropViewController
    }
    
    func updateUIViewController(_ uiViewController: CropViewController, context: Context) {}
}

