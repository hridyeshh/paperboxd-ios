import Combine
import SwiftUI

// MARK: - Aha loading

struct AhaLoadingView: View {
    let genres: [String]
    @State private var stage = 0
    @State private var progress: CGFloat = 0.06

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    private var steps: [(title: String, detail: String?)] {
        [
            ("Reading your taste", genres.isEmpty ? nil : genres.joined(separator: " · ")),
            ("Checking the shelves", nil),
            ("Picking the one", nil),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("ALMOST THERE")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .kerning(2)
                .foregroundStyle(BK.muted)
                .padding(.top, 28)

            CatAnimationView(asset: "CatPlayFrames")
                .aspectRatio(1.5, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)

            Text("Finding your\nfirst book…")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(BK.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            Text("Matching your picks against the shelves.")
                .font(.system(size: 14))
                .foregroundStyle(BK.muted)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(steps.indices, id: \.self) { i in
                    stepRow(i)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BK.card)
            .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
            .background(Rectangle().fill(BK.ink).offset(x: 4, y: 4))
            .padding(.top, 22)

            Spacer(minLength: 16)

            GeometryReader { geo in
                Rectangle().fill(BK.ink).frame(width: geo.size.width * progress)
            }
            .frame(height: 10)
            .padding(2)
            .background(BK.card)
            .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))

            Text("HANG TIGHT")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .kerning(1.6)
                .foregroundStyle(BK.muted)
                .padding(.top, 8)
        }
        .padding(.horizontal, 26)
        .padding(.bottom, 28)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.3)) { stage = min(stage + 1, steps.count - 1) }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 3.0)) { progress = 0.92 }
        }
    }

    @ViewBuilder
    private func stepRow(_ i: Int) -> some View {
        let step = steps[i]
        HStack(alignment: .top, spacing: 12) {
            Group {
                if i < stage {
                    Circle().fill(BK.ink)
                        .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.white))
                } else if i == stage {
                    Circle().strokeBorder(BK.ink, lineWidth: 2)
                        .overlay(Circle().fill(BK.crimson).frame(width: 8, height: 8))
                } else {
                    Circle().strokeBorder(BK.ink.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                }
            }
            .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: i == stage ? .bold : (i < stage ? .semibold : .medium)))
                    .foregroundStyle(i > stage ? BK.muted : BK.ink)
                if let detail = step.detail {
                    Text(detail).font(.system(size: 13)).foregroundStyle(BK.muted)
                }
            }
        }
    }
}

// MARK: - Aha reveal

struct AhaRevealView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    private var reason: String? {
        let labels = Genre.all.filter { viewModel.selectedGenres.contains($0.id) }.prefix(2).map(\.label)
        return labels.isEmpty ? nil : "Picked from " + labels.joined(separator: " + ")
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text("YOUR FIRST MATCH")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .kerning(2)
                        .foregroundStyle(BK.muted)
                        .padding(.bottom, 18)

                    if let book = viewModel.currentAhaBook {
                        bookCard(book)
                            .id(book.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 26)
                .padding(.top, 20)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.ahaIndex)
            }
            .scrollBounceBehavior(.basedOnSize)

            ctaStack.padding(.horizontal, 26).padding(.bottom, 14)
        }
    }

    private func bookCard(_ book: RecBook) -> some View {
        VStack(spacing: 0) {
            cover(book)
            Text(book.title)
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(BK.ink)
                .multilineTextAlignment(.center)
                .padding(.top, 22)
            Text("by \(book.authorLine)")
                .font(.system(size: 14))
                .foregroundStyle(BK.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
            loveBubble.padding(.top, 14)
        }
        .frame(maxWidth: .infinity)
    }

    private var loveBubble: some View {
        HStack(alignment: .top, spacing: 6) {
            CatAnimationView(asset: "CatMatchFrames")
                .frame(width: 147, height: 147)
            VStack(alignment: .leading, spacing: 6) {
                Text("You'll love\nthis!")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(BK.ink)
                    .lineSpacing(-2)
                if let reason {
                    Text(reason).font(.system(size: 13)).foregroundStyle(BK.muted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(BK.card)
            .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
            .overlay(alignment: .topLeading) {
                ZStack {
                    BubbleTail().fill(BK.card)
                    BubbleTail().stroke(BK.ink, lineWidth: 2)
                }
                .frame(width: 12, height: 18)
                .offset(x: -11, y: 22)
            }
            .background(Rectangle().fill(BK.ink).offset(x: 4, y: 4))
            .padding(.top, 16)
        }
    }

    private func cover(_ book: RecBook) -> some View {
        ZStack {
            if let urlStr = book.coverURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 160, height: 240)
        .clipped()
        .overlay(Rectangle().stroke(BK.ink, lineWidth: 2))
        .background(Rectangle().fill(BK.ink).offset(x: 6, y: 6))
        .rotationEffect(.degrees(-2))
    }

    private var coverPlaceholder: some View {
        ZStack {
            BK.paper2
            Image(systemName: "book.closed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(BK.muted)
        }
    }

    private var ctaStack: some View {
        VStack(spacing: 10) {
            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.82, green: 0.22, blue: 0.22))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            OnboardingPrimaryButton(
                title: "Save to my shelves",
                isLoading: viewModel.isAddingBook
            ) {
                Task { await viewModel.saveToShelf() }
            }

            Button {
                withAnimation { viewModel.showAnother() }
            } label: {
                Text("Show me another")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(viewModel.isAddingBook)

            Button {
                viewModel.skipAha()
            } label: {
                Text("Skip to home")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(viewModel.isAddingBook)
        }
    }
}

private struct BubbleTail: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        return p
    }
}

// MARK: - Cat animation

/// Plays a pre-drawn cat loop (CatPlayFrames / CatMatchFrames data sets) at its own 30fps.
/// Frames are vector shapes exported from the design rig, so they stay sharp at any size.
struct CatAnimationView: View {
    let asset: String
    @State private var clip: CatClip?
    @State private var start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 30)) { timeline in
            Canvas { ctx, size in
                guard let clip, !clip.frames.isEmpty else { return }
                let elapsed = max(0, timeline.date.timeIntervalSince(start))
                let index = reduceMotion ? 0 : Int(elapsed * clip.fps) % clip.frames.count
                let vb = clip.viewBox
                let s = min(size.width / vb.width, size.height / vb.height)
                ctx.translateBy(x: (size.width - vb.width * s) / 2, y: (size.height - vb.height * s) / 2)
                ctx.scaleBy(x: s, y: s)
                ctx.translateBy(x: -vb.minX, y: -vb.minY)
                for shape in clip.frames[index] {
                    ctx.fill(shape.path, with: .color(shape.color))
                }
            }
        }
        .task {
            clip = await CatClipStore.shared.clip(asset)
            start = Date()
        }
        .accessibilityHidden(true)
    }
}

actor CatClipStore {
    static let shared = CatClipStore()
    private var clips: [String: CatClip] = [:]

    func clip(_ name: String) -> CatClip? {
        if let cached = clips[name] { return cached }
        guard let data = NSDataAsset(name: name)?.data, let clip = CatClip(data: data) else { return nil }
        clips[name] = clip
        return clip
    }

    func preload(_ names: [String]) {
        for name in names { _ = clip(name) }
    }
}

/// `.frames` format: header `fps=30 vb=x,y,w,h colors=151513,FFFFFF,ECE7DD frames=N`, then one
/// line per frame of `|`-joined shapes, each a colour index followed by an SVG path using M/L/l/z.
struct CatClip {
    struct Piece {
        let color: Color
        let path: Path
    }

    let fps: Double
    let viewBox: CGRect
    let frames: [[Piece]]

    init?(data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var lines = text.split(separator: "\n")
        guard !lines.isEmpty else { return nil }
        var fps = 30.0, viewBox = CGRect(x: 0, y: 0, width: 1, height: 1), colors: [Color] = []
        for field in lines.removeFirst().split(separator: " ") {
            let kv = field.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            switch kv[0] {
            case "fps": fps = Double(kv[1]) ?? 30
            case "vb":
                let n = kv[1].split(separator: ",").compactMap { Double($0) }
                if n.count == 4 { viewBox = CGRect(x: n[0], y: n[1], width: n[2], height: n[3]) }
            case "colors": colors = kv[1].split(separator: ",").map { Color(hex: String($0)) }
            default: break
            }
        }
        self.fps = fps
        self.viewBox = viewBox
        self.frames = lines.map { line in
            line.split(separator: "|").compactMap { piece in
                guard let index = piece.first?.wholeNumberValue, index < colors.count else { return nil }
                return Piece(color: colors[index], path: Self.path(piece.dropFirst()))
            }
        }
    }

    private static func path(_ d: Substring) -> Path {
        var path = Path()
        var command: UInt8 = 77  // M
        var current = CGPoint.zero
        var pendingX: Double?
        let bytes = d.utf8
        var i = bytes.startIndex
        while i < bytes.endIndex {
            let c = bytes[i]
            switch c {
            case 77, 76, 108:  // M L l
                command = c
                i = bytes.index(after: i)
            case 90, 122:      // Z z
                path.closeSubpath()
                i = bytes.index(after: i)
            case 32, 44:       // space ,
                i = bytes.index(after: i)
            default:
                let tokenStart = i
                var negative = false
                if c == 45 { negative = true; i = bytes.index(after: i) }
                var whole = 0.0, fraction = 0.0, scale = 1.0, dot = false
                while i < bytes.endIndex {
                    let digit = bytes[i]
                    if digit >= 48 && digit <= 57 {
                        if dot { scale /= 10; fraction += Double(digit - 48) * scale }
                        else { whole = whole * 10 + Double(digit - 48) }
                    } else if digit == 46 && !dot {
                        dot = true
                    } else {
                        break
                    }
                    i = bytes.index(after: i)
                }
                if i == tokenStart { i = bytes.index(after: i); continue }
                let value = negative ? -(whole + fraction) : whole + fraction
                guard let x = pendingX else { pendingX = value; continue }
                pendingX = nil
                switch command {
                case 77:
                    current = CGPoint(x: x, y: value)
                    path.move(to: current)
                    command = 76
                case 76:
                    current = CGPoint(x: x, y: value)
                    path.addLine(to: current)
                default:
                    current = CGPoint(x: current.x + x, y: current.y + value)
                    path.addLine(to: current)
                }
            }
        }
        return path
    }
}
