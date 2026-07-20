import SwiftUI

/// 01 — Scan. Live camera viewfinder with barcode framing. When an ISBN barcode is
/// read, a confirmation card slides up. Camera permission is requested on appear;
/// denied / unavailable (e.g. Simulator) states show a fallback card.
struct ScanScreen: View {
    /// (isbn, resolved title if known) → start analysis.
    let onScanIt: (String, String?) -> Void
    let onClose: () -> Void

    private enum FallbackKind { case denied, unavailable, offline }

    @ObservedObject private var net = NetworkMonitor.shared
    @State private var scannedISBN: String?
    @State private var status: BarcodeScannerView.Status = .scanning
    @State private var sweep = false
    @State private var torchOn = false
    @State private var bookTitle: String?
    @State private var titleLoading = false
    @State private var showManual = false

    private var showBrackets: Bool { status == .scanning && scannedISBN == nil }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Offline: never start the camera — the analyze call would fail anyway.
            // Show the offline fallback card instead (see below).
            if net.isOnline {
                BarcodeScannerView(onCode: handleCode, onStatus: { status = $0 }, torchOn: torchOn)
                    .ignoresSafeArea()
            }

            // Top + bottom washes for legibility over the live feed.
            VStack {
                LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 160)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 280)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                Spacer()
            }

            if showBrackets { bracketsLayer }

            VStack(spacing: 14) {
                Spacer()
                if !net.isOnline {
                    fallbackCard(.offline)
                } else if let isbn = scannedISBN {
                    isbnCard(isbn).transition(.move(edge: .bottom).combined(with: .opacity))
                } else if status == .denied {
                    fallbackCard(.denied)
                } else if status == .unavailable {
                    fallbackCard(.unavailable)
                }
                manualSearch
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .onAppear { sweep = true }
        .sheet(isPresented: $showManual) {
            ManualSearchSheet { isbn, title in
                showManual = false
                onScanIt(isbn, title)
            }
        }
    }

    private func handleCode(_ code: String) {
        guard scannedISBN == nil else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { scannedISBN = code }
        titleLoading = true
        Task {
            let title = await ScanService.lookupTitle(isbn: code)
            await MainActor.run { withAnimation { bookTitle = title; titleLoading = false } }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            Text("Scan & Know")
                .font(PB.serif(17))
                .foregroundStyle(.white)
            HStack {
                circleIcon("xmark", action: onClose)
                Spacer()
                circleIcon(torchOn ? "bolt.fill" : "bolt.slash.fill") {
                    torchOn.toggle()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private func circleIcon(_ name: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    // MARK: - Framing brackets + sweep

    private var bracketsLayer: some View {
        ZStack {
            FramingBrackets()
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 260, height: 180)
            Rectangle()
                .fill(LinearGradient(colors: [.clear, PB.terracotta.opacity(0.85), .clear],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 258, height: 2)
                .offset(y: sweep ? 84 : -84)
                .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: sweep)
        }
        .overlay(alignment: .bottom) {
            Text("Line up the barcode on the back cover")
                .font(PB.mono(11))
                .foregroundStyle(.white.opacity(0.8))
                .offset(y: 44)
        }
    }

    // MARK: - ISBN found card

    private func isbnCard(_ isbn: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color("Border"))
                    .frame(width: 38, height: 54)
                Image(systemName: "barcode")
                    .font(.system(size: 16))
                    .foregroundStyle(Color("TextSecondary"))
            }
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: bookTitle == nil ? "ISBN found" : "Book found")
                if let bookTitle {
                    Text(bookTitle)
                        .font(PB.serif(16))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(2)
                    Text(isbn)
                        .font(PB.mono(11))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                } else if titleLoading {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.7).tint(Color("TextSecondary"))
                        Text("Finding the book…")
                            .font(.system(size: 13))
                            .foregroundStyle(Color("TextSecondary"))
                    }
                    Text(isbn)
                        .font(PB.mono(11))
                        .foregroundStyle(Color("TextSecondary").opacity(0.7))
                        .lineLimit(1)
                } else {
                    Text(isbn)
                        .font(PB.mono(15, .medium))
                        .foregroundStyle(Color("TextPrimary"))
                        .lineLimit(1)
                    Text("Couldn't find the title — scan anyway")
                        .font(.system(size: 11))
                        .foregroundStyle(Color("TextSecondary"))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Button { onScanIt(isbn, bookTitle) } label: {
                HStack(spacing: 5) {
                    Text("Scan it").font(.system(size: 13, weight: .semibold))
                    Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color("Background"))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color("TextPrimary"))
                .clipShape(Capsule())
            }
        }
        .padding(12)
        .background(Color("Surface"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color("Border"), lineWidth: 1)
        )
    }

    // MARK: - Permission / unavailable fallback

    private func fallbackCard(_ kind: FallbackKind) -> some View {
        VStack(spacing: 10) {
            Image(systemName: fallbackIcon(kind))
                .font(.system(size: 20))
                .foregroundStyle(Color("Accent"))
            Text(fallbackTitle(kind))
                .font(PB.serif(16))
                .foregroundStyle(Color("TextPrimary"))
            Text(fallbackBody(kind))
                .font(.system(size: 12))
                .foregroundStyle(Color("TextSecondary"))
                .multilineTextAlignment(.center)
            if kind == .denied {
                Button(action: openSettings) {
                    Text("Open Settings")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color("Background"))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color("Accent"))
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color("Surface"))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color("Border"), lineWidth: 1)
        )
    }

    private func fallbackIcon(_ kind: FallbackKind) -> String {
        switch kind {
        case .denied:      return "lock.fill"
        case .unavailable: return "camera.fill"
        case .offline:     return "wifi.slash"
        }
    }

    private func fallbackTitle(_ kind: FallbackKind) -> String {
        switch kind {
        case .denied:      return "Camera access needed"
        case .unavailable: return "Camera unavailable"
        case .offline:     return "No internet connection"
        }
    }

    private func fallbackBody(_ kind: FallbackKind) -> String {
        switch kind {
        case .denied:      return "Enable camera access to scan a book's barcode."
        case .unavailable: return "This device has no camera — try on your phone."
        case .offline:     return "Scanning needs a connection to score your book. Reconnect and try again."
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private var manualSearch: some View {
        Button { showManual = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 12))
                Text("Type the title instead").font(.system(size: 13))
            }
            .foregroundStyle(.white.opacity(0.7))
        }
    }
}

// MARK: - Framing brackets shape

/// Four corner "L" brackets framing the scan area.
struct FramingBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c: CGFloat = 28
        // top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + c))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + c, y: rect.minY))
        // top-right
        p.move(to: CGPoint(x: rect.maxX - c, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + c))
        // bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - c))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - c, y: rect.maxY))
        // bottom-left
        p.move(to: CGPoint(x: rect.minX + c, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - c))
        return p
    }
}
