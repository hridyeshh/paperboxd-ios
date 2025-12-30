import SwiftUI
import MessageUI
import Kingfisher
import CoreImage.CIFilterBuiltins
import LinkPresentation
import Photos

// MARK: - Profile Card View for Image Rendering
struct ProfileCardView: View {
    let avatarURL: String?
    let username: String
    let profileURL: String
    let qrCodeImage: UIImage?
    let displayName: String
    
    var body: some View {
        ZStack {
            // Background fills entire frame - cream color
            Color(red: 0.96, green: 0.93, blue: 0.88)
                .frame(width: 1080, height: 1080)
            
            VStack(spacing: 40) {
                Spacer()
                
                // Profile Image (larger for 1080x1080 canvas)
                if let avatarURL = avatarURL, let url = URL(string: avatarURL) {
                    KFImage(url)
                        .placeholder {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 200, height: 200)
                                .overlay(
                                    Text((username.isEmpty ? "U" : username).prefix(1).uppercased())
                                        .font(.system(size: 80, weight: .black))
                                        .foregroundColor(.black)
                                )
                        }
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 200, height: 200)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.black, lineWidth: 8))
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 200)
                        .overlay(
                            Text((username.isEmpty ? "U" : username).prefix(1).uppercased())
                                .font(.system(size: 80, weight: .black))
                                .foregroundColor(.black)
                        )
                        .overlay(Circle().stroke(Color.black, lineWidth: 8))
                }
                
                // Username (larger)
                if !username.isEmpty {
                    Text("@\(username)")
                        .font(.system(size: 50, weight: .black))
                        .foregroundColor(.black)
                }
                
                // QR Code (larger)
                if let qrImage = qrCodeImage {
                    Image(uiImage: qrImage)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(20)
                }
                
                // Profile URL (larger)
                Text("paperboxd.in/u/\(username.isEmpty ? "user" : username)")
                    .font(.system(size: 30, weight: .black))
                    .padding(.vertical, 16)
                    .padding(.horizontal, 32)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(30)
                
                Spacer()
            }
            .frame(width: 1080, height: 1080)
        }
        .frame(width: 1080, height: 1080)
        .cornerRadius(20)
    }
}

struct ShareView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var viewModel = ProfileViewModel.shared
    @State private var showNativeShare = false
    @State private var showMailComposer = false
    @State private var copiedToClipboard = false
    @State private var qrCodeImage: UIImage?
    @State private var showSaveSuccess = false
    @State private var isSaving = false
    @State private var shareCardImage: UIImage?
    
    var username: String {
        return viewModel.profile?.username ?? ""
    }
    
    var displayName: String {
        return viewModel.profile?.name ?? viewModel.profile?.username ?? "User"
    }
    
    var profileURL: String {
        guard let username = viewModel.profile?.username else {
            return "https://www.paperboxd.in"
        }
        return "https://www.paperboxd.in/u/\(username)"
    }
    
    var shareText: String {
        return "Checkout \(username)'s PaperBoxd account! \(profileURL)"
    }
    
    var body: some View {
        ZStack {
            // 1. BOLD SOLID BACKGROUND - Pinterest Red
            Color.red.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Top Close Button
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                    // 2. THE SOCIAL POSTER CARD (Smaller)
                    VStack(spacing: 12) {
                        // Profile Image with Bold Border
                        if let avatarURL = viewModel.profile?.avatar, let url = URL(string: avatarURL) {
                            KFImage(url)
                                .placeholder {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 70, height: 70)
                                        .overlay(
                                            Text((username.isEmpty ? "U" : username).prefix(1).uppercased())
                                                .font(.system(size: 28, weight: .black))
                                                .foregroundColor(.black)
                                        )
                                }
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 70, height: 70)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.black, lineWidth: 3))
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 70, height: 70)
                                .overlay(
                                    Text((username.isEmpty ? "U" : username).prefix(1).uppercased())
                                        .font(.system(size: 28, weight: .black))
                                        .foregroundColor(.black)
                                )
                                .overlay(Circle().stroke(Color.black, lineWidth: 3))
                        }
                        
                        // Username only (in black)
                        if !username.isEmpty {
                            Text("@\(username)")
                                .font(.system(size: 18, weight: .black))
                                .foregroundColor(.black)
                        }

                        // QR Code (smaller)
                        if let qrImage = qrCodeImage {
                            ZStack {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.1), radius: 0, x: 3, y: 3)
                                
                                Image(uiImage: qrImage)
                                    .resizable()
                                    .interpolation(.none)
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                            }
                        } else {
                            ZStack {
                                Rectangle()
                                    .fill(Color.white)
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(10)
                                    .shadow(color: .black.opacity(0.1), radius: 0, x: 3, y: 3)
                                
                                ProgressView()
                            }
                        }
                        
                        // Profile URL
                        Text("paperboxd.in/u/\(username.isEmpty ? "user" : username)")
                            .font(.system(size: 12, weight: .black))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .padding(20)
                    .background(Color(red: 0.96, green: 0.93, blue: 0.88)) // "Paper" Cream
                    .cornerRadius(20)
                    .padding(.horizontal, 30)
                    .shadow(color: .black.opacity(0.2), radius: 0, x: 8, y: 8)
                    .padding(.top, 10)

                    // 3. BOLD ACTION BUTTONS - Horizontal Scroll
                    VStack(spacing: 15) {
                        Text("SHARE YOUR LIBRARY")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.white)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                BoldShareIcon(
                                    icon: "link",
                                    label: "COPY",
                                    color: .black
                                ) {
                                    copyLink()
                                }
                                
                                BoldShareIcon(
                                    icon: "message.fill",
                                    label: "SMS",
                                    color: .black
                                ) {
                                    shareViaMessages()
                                }
                                
                                BoldShareIcon(
                                    icon: "phone.fill",
                                    label: "WHATSAPP",
                                    color: .black
                                ) {
                                    shareViaWhatsApp()
                                }
                                
                                BoldShareIcon(
                                    icon: "arrow.down.circle.fill",
                                    label: "SAVE",
                                    color: .black
                                ) {
                                    saveCardToPhotos()
                                }
                                
                                BoldShareIcon(
                                    icon: "xmark",
                                    label: "X",
                                    color: .black
                                ) {
                                    shareViaX()
                                }
                                
                                BoldShareIcon(
                                    icon: "envelope.fill",
                                    label: "EMAIL",
                                    color: .black
                                ) {
                                    shareViaEmail()
                                }
                                
                                BoldShareIcon(
                                    icon: "square.and.arrow.up",
                                    label: "MORE",
                                    color: .black
                                ) {
                                    showNativeShare = true
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .onAppear {
            generateQRCode()
            // Pre-generate share card image on main thread
            Task { @MainActor in
                shareCardImage = createProfileCardImage()
            }
        }
        .onChange(of: showNativeShare) { oldValue, newValue in
            if newValue && shareCardImage == nil {
                // Generate card image when share sheet opens if not already generated
                Task { @MainActor in
                    shareCardImage = createProfileCardImage()
                }
            }
        }
        .sheet(isPresented: $showNativeShare) {
            // For Instagram DM: Include both text and URL
            // The text pre-fills the message box, the URL generates the preview
            // Also include the profile card image for rich preview if available
            if let url = URL(string: profileURL) {
                if let cardImage = shareCardImage {
                    let shareItems: [Any] = [
                        shareText,  // Pre-fills the message box in Instagram DM
                        url,        // Generates the link preview
                        cardImage,  // Shows as preview image
                        RichLinkItem(url: url, title: "\(displayName)'s PaperBoxd Profile", description: shareText, image: cardImage)
                    ]
                    ShareSheet(activityItems: shareItems)
                } else {
                    // Fallback: Just text and URL if image not ready
                    ShareSheet(activityItems: [shareText, url])
                }
            } else {
                ShareSheet(activityItems: [shareText])
            }
        }
        .onChange(of: showNativeShare) { oldValue, newValue in
            if newValue {
                // Generate card image when share sheet is about to open
                Task { @MainActor in
                    shareCardImage = createProfileCardImage()
                }
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                subject: "Checkout \(username)'s PaperBoxd account!",
                messageBody: shareText,
                isPresented: $showMailComposer
            )
        }
        .alert("Link copied!", isPresented: $copiedToClipboard) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The profile link has been copied to your clipboard.")
        }
        .alert("Card saved!", isPresented: $showSaveSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The share card has been saved to your photo library.")
        }
    }
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        let data = profileURL.data(using: .utf8)!
        filter.setValue(data, forKey: "inputMessage")
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
    
    private func shareViaNative() {
        showNativeShare = true
    }
    
    private func copyLink() {
        UIPasteboard.general.string = profileURL
        copiedToClipboard = true
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    private func shareViaEmail() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showNativeShare = true
        }
    }
    
    private func saveCardToPhotos() {
        guard !isSaving else { return }
        
        isSaving = true
        
        // Request photo library access
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized || status == .limited {
                // Create the card image on main thread (ImageRenderer needs UI context)
                DispatchQueue.main.async {
                    let cardImage = self.createProfileCardImage()
                    
                    // Save to photo library
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: cardImage)
                    }) { success, error in
                        DispatchQueue.main.async {
                            self.isSaving = false
                            if success {
                                self.showSaveSuccess = true
                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            } else {
                                print("❌ ShareView: Failed to save card to photos: \(error?.localizedDescription ?? "Unknown error")")
                            }
                        }
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.isSaving = false
                    print("❌ ShareView: Photo library access denied")
                }
            }
        }
    }
    
    // Instagram Stories sharing (available for future use or separate button)
    private func shareToInstagramStories() {
        // Create the profile card image
        let cardImage = createProfileCardImage()
        
        // Convert image to PNG data
        guard let imageData = cardImage.pngData() else {
            print("❌ ShareView: Failed to convert image to PNG data")
            showNativeShare = true
            return
        }
        
        // Facebook App ID from Meta Developer Portal
        let facebookAppID = "661485040288063"
        
        // Instagram Stories requires specific pasteboard format
        let pasteboard = UIPasteboard.general
        let pasteboardItems: [String: Any] = [
            "com.instagram.sharedSticker.backgroundImage": imageData,
            "com.instagram.sharedSticker.appID": facebookAppID
        ]
        
        // Set the pasteboard items
        pasteboard.items = [pasteboardItems]
        
        // Instagram Stories URL scheme
        // Use bundle identifier as source_application
        let bundleID = Bundle.main.bundleIdentifier ?? "com.paperboxd.ios"
        let instagramStoriesURL = "instagram-stories://share?source_application=\(bundleID)"
        
        if let url = URL(string: instagramStoriesURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url) { success in
                if !success {
                    print("❌ ShareView: Failed to open Instagram Stories")
                    // Fallback to native share if Stories fails
                    showNativeShare = true
                } else {
                    print("✅ ShareView: Successfully opened Instagram Stories")
                }
            }
        } else {
            print("⚠️ ShareView: Instagram Stories not available, using native share")
            // Instagram not installed or Stories not available, use native share
            showNativeShare = true
        }
    }
    
    @MainActor
    private func createProfileCardImage() -> UIImage {
        // Create a view representing the profile card
        let cardView = ProfileCardView(
            avatarURL: viewModel.profile?.avatar,
            username: username,
            profileURL: profileURL,
            qrCodeImage: qrCodeImage,
            displayName: displayName
        )
        
        // Render the view to an image
        let renderer = ImageRenderer(content: cardView)
        
        // Use a fixed scale of 3.0 for high-quality rendering (avoids UI API calls on background thread)
        renderer.scale = 3.0
        
        // Set a fixed size for the card (square 1080x1080)
        let size = CGSize(width: 1080, height: 1080)
        renderer.proposedSize = .init(size)
        
        if let image = renderer.uiImage {
            return image
        }
        
        // Fallback: Create a simple image with text
        return createFallbackCardImage()
    }
    
    private func createFallbackCardImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1080)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            // Background
            UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1.0).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // Username
            let usernameText = "@\(username.isEmpty ? "user" : username)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 60, weight: .black),
                .foregroundColor: UIColor.black
            ]
            let textSize = usernameText.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: size.height / 2 - textSize.height / 2,
                width: textSize.width,
                height: textSize.height
            )
            usernameText.draw(in: textRect, withAttributes: attributes)
            
            // Profile URL
            let urlText = "paperboxd.in/u/\(username.isEmpty ? "user" : username)"
            let urlAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 40, weight: .bold),
                .foregroundColor: UIColor.red
            ]
            let urlSize = urlText.size(withAttributes: urlAttributes)
            let urlRect = CGRect(
                x: (size.width - urlSize.width) / 2,
                y: textRect.maxY + 40,
                width: urlSize.width,
                height: urlSize.height
            )
            urlText.draw(in: urlRect, withAttributes: urlAttributes)
        }
    }
    
    private func shareViaWhatsApp() {
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareText
        let whatsappURL = "whatsapp://send?text=\(encodedText)"
        
        if let url = URL(string: whatsappURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            showNativeShare = true
        }
    }
    
    private func shareViaMessages() {
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareText
        let messagesURL = "sms:&body=\(encodedText)"
        
        if let url = URL(string: messagesURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            showNativeShare = true
        }
    }
    
    private func shareViaX() {
        // Try X/Twitter app first
        let encodedText = shareText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareText
        let twitterURL = "twitter://post?message=\(encodedText)"
        
        if let url = URL(string: twitterURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        } else {
            // Fallback: Try web Twitter intent
            let webTwitterURL = "https://twitter.com/intent/tweet?text=\(encodedText)"
            if let url = URL(string: webTwitterURL) {
                UIApplication.shared.open(url)
            } else {
                showNativeShare = true
            }
        }
    }
}

// MARK: - COMPONENT: BOLD SHARE ICON
struct BoldShareIcon: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            action()
        }) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15)
                        .fill(color)
                        .frame(width: 65, height: 65)
                    
                    if icon == "xmark" {
                        Text("X")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(label)
                    .font(.system(size: 12, weight: .black))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Rich Link Item Source for Instagram DM Preview
class RichLinkItem: NSObject, UIActivityItemSource {
    let url: URL
    let title: String
    let linkDescription: String
    let image: UIImage
    
    init(url: URL, title: String, description: String, image: UIImage) {
        self.url = url
        self.title = title
        self.linkDescription = description
        self.image = image
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return url
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return url
    }
    
    @MainActor
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}

// MARK: - Mail Compose View
struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let messageBody: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        @Binding var isPresented: Bool
        
        init(isPresented: Binding<Bool>) {
            _isPresented = isPresented
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            isPresented = false
        }
    }
}
