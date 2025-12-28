import SwiftUI
import UIKit

struct AvatarEditorView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    let onSave: (UIImage) -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var screenWidth: CGFloat = 375 // Default fallback
    
    private let cropSize: CGFloat = 300 // Size of the circular crop area
    
    var body: some View {
        NavigationView {
            GeometryReader { mainGeometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        Spacer()
                        
                    // Image with zoom and pan
                    GeometryReader { geometry in
                        let imageAspect = image.size.width / image.size.height
                        let containerWidth = geometry.size.width
                        let containerHeight = cropSize
                        
                        // Calculate how the image fits in the container
                        // Ensure image fills at least the crop circle
                        let (displayedWidth, displayedHeight) = calculateDisplaySize(
                            imageAspect: imageAspect,
                            containerWidth: containerWidth,
                            containerHeight: containerHeight
                        )
                        
                        ZStack(alignment: .center) {
                            // Image view with gestures - centered and constrained (behind overlay)
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: displayedWidth, height: displayedHeight)
                                .scaleEffect(scale)
                                .offset(x: offset.width, y: offset.height)
                                .clipped()
                                .gesture(
                                    SimultaneousGesture(
                                        // Pinch to zoom
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                let newScale = scale * delta
                                                scale = min(max(newScale, 1.0), 4.0) // Limit zoom between 1x and 4x
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                                // Constrain offset after zoom
                                                constrainOffset(displayedWidth: displayedWidth * scale, displayedHeight: displayedHeight * scale)
                                            },
                                        // Drag to pan
                                        DragGesture()
                                            .onChanged { value in
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                // Constrain in real-time during drag
                                                let constrained = constrainOffsetForDrag(
                                                    offset: newOffset,
                                                    displayedWidth: displayedWidth * scale,
                                                    displayedHeight: displayedHeight * scale
                                                )
                                                offset = constrained
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                                constrainOffset(displayedWidth: displayedWidth * scale, displayedHeight: displayedHeight * scale)
                                            }
                                    )
                                )
                            
                            // Dark overlay with circular cutout
                            Color.black.opacity(0.5)
                                .mask(
                                    ZStack {
                                        Rectangle()
                                        Circle()
                                            .frame(width: cropSize, height: cropSize)
                                            .blendMode(.destinationOut)
                                    }
                                )
                            
                            // Circular crop border
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                                .frame(width: cropSize, height: cropSize)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                    }
                    .frame(height: cropSize)
                    .padding(.horizontal, 20)
                    
                        Spacer()
                        
                        // Instructions
                        Text("Pinch to zoom, drag to position")
                            .foregroundColor(.white.opacity(0.7))
                            .font(.caption)
                            .padding(.bottom, 20)
                    }
                }
                .navigationTitle("Edit Photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            let croppedImage = cropImage(screenWidth: mainGeometry.size.width)
                            onSave(croppedImage)
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                    }
                }
                .onAppear {
                    // Store screen width for cropping calculations
                    screenWidth = mainGeometry.size.width
                    // Initialize scale and position to fit image in crop area
                    setupInitialPosition()
                }
            }
        }
    }
    
    private func setupInitialPosition() {
        // Start with scale 1.0 - image will be centered by default
        // User can zoom in if needed
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    private func calculateDisplaySize(imageAspect: CGFloat, containerWidth: CGFloat, containerHeight: CGFloat) -> (width: CGFloat, height: CGFloat) {
        var displayedWidth: CGFloat
        var displayedHeight: CGFloat
        
        if imageAspect > 1.0 {
            // Landscape - fit to width, but ensure height covers crop circle
            displayedWidth = containerWidth
            displayedHeight = containerWidth / imageAspect
            // If height is less than crop size, scale up
            if displayedHeight < cropSize {
                let scaleFactor = cropSize / displayedHeight
                displayedWidth = containerWidth * scaleFactor
                displayedHeight = cropSize
            }
        } else {
            // Portrait or square - fit to height (crop size)
            displayedHeight = cropSize
            displayedWidth = cropSize * imageAspect
            // If width is less than container, that's fine - image will be centered
        }
        
        return (displayedWidth, displayedHeight)
    }
    
    private func constrainOffset(displayedWidth: CGFloat, displayedHeight: CGFloat) {
        // Calculate the maximum allowed offset to keep crop area within image bounds
        // The crop circle is centered, so we need to ensure the circle stays within the image
        let maxOffsetX = max(0, (displayedWidth - cropSize) / 2)
        let maxOffsetY = max(0, (displayedHeight - cropSize) / 2)
        
        // Constrain offset
        offset.width = min(max(offset.width, -maxOffsetX), maxOffsetX)
        offset.height = min(max(offset.height, -maxOffsetY), maxOffsetY)
        
        lastOffset = offset
    }
    
    private func constrainOffsetForDrag(offset: CGSize, displayedWidth: CGFloat, displayedHeight: CGFloat) -> CGSize {
        // Calculate the maximum allowed offset to keep crop area within image bounds
        let maxOffsetX = max(0, (displayedWidth - cropSize) / 2)
        let maxOffsetY = max(0, (displayedHeight - cropSize) / 2)
        
        // Constrain offset
        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }
    
    private func cropImage(screenWidth: CGFloat) -> UIImage {
        let adjustedWidth = screenWidth - 40 // Account for padding
        let imageAspect = image.size.width / image.size.height
        
        // Calculate displayed image dimensions (how the image appears on screen)
        let displayedWidth: CGFloat
        let displayedHeight: CGFloat
        
        if imageAspect > 1.0 {
            // Landscape - image fits to screen width
            displayedWidth = adjustedWidth
            displayedHeight = adjustedWidth / imageAspect
        } else {
            // Portrait or square - image fits to crop height
            displayedHeight = cropSize
            displayedWidth = cropSize * imageAspect
        }
        
        // Calculate the crop center in displayed coordinates (center of the circle)
        let cropCenterX = adjustedWidth / 2
        let cropCenterY = cropSize / 2
        
        // Calculate where the crop center is in the displayed image coordinates
        // Account for the image's position (centered by default, then offset by user pan)
        let imageCenterX = adjustedWidth / 2
        let imageCenterY = cropSize / 2
        
        // Calculate the crop center relative to the image center, accounting for scale and offset
        let relativeX = (cropCenterX - imageCenterX - offset.width) / scale
        let relativeY = (cropCenterY - imageCenterY - offset.height) / scale
        
        // Convert to actual image coordinates
        let cropCenterInImageX = (imageCenterX + relativeX) / displayedWidth * image.size.width
        let cropCenterInImageY = (imageCenterY + relativeY) / displayedHeight * image.size.height
        
        // Calculate crop size in image coordinates
        let cropSizeInImage = (cropSize / scale) / displayedWidth * image.size.width
        
        // Create crop rect centered on the calculated point
        let cropRect = CGRect(
            x: max(0, min(cropCenterInImageX - cropSizeInImage / 2, image.size.width - cropSizeInImage)),
            y: max(0, min(cropCenterInImageY - cropSizeInImage / 2, image.size.height - cropSizeInImage)),
            width: min(cropSizeInImage, image.size.width),
            height: min(cropSizeInImage, image.size.height)
        )
        
        // Crop the image
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image // Fallback to original if cropping fails
        }
        
        // Create circular mask
        let outputSize = CGSize(width: cropSizeInImage, height: cropSizeInImage)
        UIGraphicsBeginImageContextWithOptions(outputSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        let rect = CGRect(origin: .zero, size: outputSize)
        
        context.addEllipse(in: rect)
        context.clip()
        
        UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            .draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
}

