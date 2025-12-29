import SwiftUI

struct ImageCropperView: View {
    @Binding var rawAvatarImage: UIImage?
    let onImageCropped: (UIImage) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        Group {
            // CRITICAL FIX: Only initialize if rawAvatarImage is NOT nil
            // We check rawAvatarImage directly since it's the source of truth
            if let img = rawAvatarImage {
                ImageCropper(
                    image: img,
                    croppedImage: Binding(
                        get: { rawAvatarImage },
                        set: { newValue in
                            rawAvatarImage = newValue
                            // When the cropped image is set, immediately call the callback
                            if let cropped = newValue {
                                print("✅ ImageCropperView: Cropped image set: \(cropped.size.width) x \(cropped.size.height)")
                                onImageCropped(cropped)
                            }
                        }
                    )
                )
                .ignoresSafeArea(.all)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .onAppear {
                    print("✅ ImageCropperView: ImageCropper appeared with image size: \(img.size.width)x\(img.size.height)")
                    print("✅ ImageCropperView: Image orientation: \(img.imageOrientation.rawValue)")
                }
                .task {
                    // Force a layout update after view appears to ensure Mantis renders
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                    print("✅ ImageCropperView: Triggering delayed layout update")
                }
                .onDisappear {
                    // Only dismiss, don't try to get the image here as it might not be set yet
                    onDismiss()
                }
            } else {
                // Fallback for safety - show loading while image is being prepared
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .onAppear {
                    print("⚠️ ImageCropperView: Image not ready! rawAvatarImage is nil")
                    // Wait a moment and check again - image might be loading
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                        if rawAvatarImage == nil {
                            print("❌ ImageCropperView: Image still not ready after delay, closing cropper")
                            onDismiss()
                        }
                    }
                }
            }
        }
    }
}

