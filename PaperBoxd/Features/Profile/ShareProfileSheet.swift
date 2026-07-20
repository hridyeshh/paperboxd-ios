import SwiftUI
import CoreImage.CIFilterBuiltins

/// Brutalist "Share Profile" sheet — a hard-edged offset-shadow QR card with
/// the PaperBoxd mark punched into the centre, plus Share / Copy / Download tiles.
/// Mirrors "Share Profile - Brutalist Mobile.html" from the design elements.
struct ShareProfileSheet: View {
    let username: String
    let displayName: String

    @Environment(\.dismiss) private var dismiss
    @State private var shareItem: ShareItem?
    @State private var toast: String?

    // Fixed warm-light palette so the QR card always scans, in light or dark mode
    // (matches the design keeping the code card light in both themes).
    private let ink   = Color(red: 0.11, green: 0.10, blue: 0.08)
    private let qrBg  = Color(red: 0.992, green: 0.984, blue: 0.965)

    private var profileURL: URL? {
        URL(string: "https://paperboxd.in/u/\(username)")
    }
    private var prettyLink: String { "paperboxd.in/u/\(username)" }

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            VStack(spacing: 0) {
                topRail
                Spacer(minLength: 8)
                qrCard
                Spacer(minLength: 8)
                actionTiles
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                customiseButton
                    .padding(.top, 16)
                    .padding(.bottom, 8)
            }
            .padding(.top, 14)

            if let toast {
                toastChip(toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Backdrop (warm smoky gradient standing in for the blurred profile)

    private var backdrop: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.81, green: 0.78, blue: 0.71),
                         Color(red: 0.66, green: 0.62, blue: 0.54)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 0.94, green: 0.91, blue: 0.86), .clear],
                center: .init(x: 0.78, y: 0.08), startRadius: 0, endRadius: 420
            )
            RadialGradient(
                colors: [.black.opacity(0.16), .clear],
                center: .center, startRadius: 40, endRadius: 360
            )
        }
    }

    // MARK: - Top rail

    private var topRail: some View {
        HStack {
            railButton(systemName: "xmark") { dismiss() }
            Spacer()
            Text("YOUR CODE")
                .font(PB.mono(11, .semibold))
                .tracking(3)
                .foregroundStyle(ink)
                .padding(.horizontal, 18).padding(.vertical, 7)
                .overlay(Capsule().strokeBorder(ink.opacity(0.34), lineWidth: 1.5))
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 18)
    }

    private func railButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(ink)
                .frame(width: 44, height: 44)
                .background(ink.opacity(0.10), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - QR card (the brutalist signature)

    private var qrCard: some View {
        ZStack(alignment: .topLeading) {
            // hard offset shadow
            RoundedRectangle(cornerRadius: 4)
                .fill(ink)
                .offset(x: 7, y: 7)

            VStack(spacing: 0) {
                HStack {
                    Text("PaperBoxd")
                        .font(PB.wordmark(24))
                        .foregroundStyle(ink)
                    Spacer()
                    Text("SCAN TO FOLLOW")
                        .font(PB.mono(8))
                        .tracking(2)
                        .foregroundStyle(ink.opacity(0.55))
                }
                .padding(.bottom, 16)

                qrMatrix

                HStack(spacing: 7) {
                    Image(systemName: "envelope")
                        .font(.system(size: 15, weight: .semibold))
                    Text("@\(username)")
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(-0.4)
                }
                .foregroundStyle(ink)
                .padding(.top, 18)

                Text(prettyLink.uppercased())
                    .font(PB.mono(8.5))
                    .tracking(1.6)
                    .foregroundStyle(ink.opacity(0.5))
                    .padding(.top, 5)
            }
            .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))
            .background(RoundedRectangle(cornerRadius: 4).fill(qrBg))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(ink, lineWidth: 1.5))
        }
        .frame(maxWidth: 290)
        .padding(.horizontal, 26)
        .padding(.trailing, 7).padding(.bottom, 7) // room for offset shadow
    }

    private var qrMatrix: some View {
        ZStack {
            if let qr = Self.makeQRTemplate(from: profileURL?.absoluteString ?? "") {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(ink)
                    .aspectRatio(1, contentMode: .fit)
            } else {
                Rectangle().fill(ink.opacity(0.06)).aspectRatio(1, contentMode: .fit)
            }
            centreMark
        }
    }

    // PaperBoxd book mark punched into the code's centre clear zone
    private var centreMark: some View {
        GeometryReader { geo in
            let s = geo.size.width * 0.28
            RoundedRectangle(cornerRadius: 6)
                .fill(qrBg)
                .frame(width: s, height: s)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(ink, lineWidth: 2.4)
                        .frame(width: s * 0.76, height: s * 0.76)
                        .overlay(
                            ZStack {
                                Rectangle().fill(ink)
                                    .frame(width: 2.2, height: s * 0.76 * 0.68)
                                Circle().fill(ink)
                                    .frame(width: 3.4, height: 3.4)
                                    .offset(x: s * 0.20, y: -s * 0.20)
                            }
                        )
                )
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    // MARK: - Action tiles

    private var actionTiles: some View {
        HStack(spacing: 11) {
            tile(system: "square.and.arrow.up", label: "Share profile") {
                if let url = profileURL { shareItem = ShareItem(url: url) }
            }
            tile(system: "link", label: "Copy link") {
                UIPasteboard.general.string = profileURL?.absoluteString
                flashToast("Link copied")
            }
            tile(system: "arrow.down.to.line", label: "Download") {
                saveCardToPhotos()
            }
        }
    }

    private func tile(system: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: system)
                    .font(.system(size: 20, weight: .regular))
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(qrBg, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(ink.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var customiseButton: some View {
        Button {
            flashToast("Card customisation coming soon")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera")
                Text("Customise card")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(qrBg)
            .padding(.horizontal, 26).padding(.vertical, 13)
            .background(ink, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Toast

    private func flashToast(_ msg: String) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toast = nil }
        }
    }

    private func toastChip(_ msg: String) -> some View {
        VStack {
            Spacer()
            Text(msg)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(white: 0.12).opacity(0.95), in: Capsule())
                .padding(.bottom, 40)
        }
    }

    // MARK: - Download (render card → Photos)

    private func saveCardToPhotos() {
        let card = qrCard
            .frame(width: 320)
            .padding(24)
            .background(qrBg)
        let renderer = ImageRenderer(content: card)
        renderer.scale = UIScreen.main.scale
        guard let image = renderer.uiImage else {
            flashToast("Couldn't render card")
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        flashToast("Saved to Photos")
    }

    // MARK: - QR generation

    /// Black QR on transparent background as a template image (foreground colour applied by SwiftUI).
    private static func makeQRTemplate(from string: String) -> UIImage? {
        guard !string.isEmpty else { return nil }
        let ctx = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        // Invert (black↔white) then mask-to-alpha so modules become opaque, paper transparent.
        guard let inverted = CIFilter(name: "CIColorInvert", parameters: [kCIInputImageKey: output])?.outputImage,
              let masked = CIFilter(name: "CIMaskToAlpha", parameters: [kCIInputImageKey: inverted])?.outputImage
        else { return nil }
        let scaled = masked.transformed(by: CGAffineTransform(scaleX: 14, y: 14))
        guard let cg = ctx.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg).withRenderingMode(.alwaysTemplate)
    }
}
