import SwiftUI

// 18-cover gradient library matching the design's PB_COVERS array.
private let pbCovers: [LinearGradient] = {
    let pairs: [(String, String)] = [
        ("6b5b95","2f1f50"), ("c44536","6a1f1a"), ("c49a6c","7a5230"),
        ("2a4a3a","10201a"), ("3a5a7a","15253a"), ("8a3a5a","3d1528"),
        ("4a6a2a","1e2e10"), ("b85c38","5c2810"), ("2a3a5a","0e1525"),
        ("8a7a2a","3d3510"), ("5a2a6a","250e30"), ("1a5a4a","081f18"),
        ("6b4a2a","2d1a08"), ("3a2a6a","150e30"), ("5a4a1a","251e06"),
        ("1a3a5a","081525"), ("6a3a2a","2d1510"), ("2a5a3a","0e2518"),
    ]
    return pairs.map { a, b in
        LinearGradient(
            colors: [Color(hex: a), Color(hex: b)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}()

// 5 columns: (covers, upward, duration, startFraction 0–1)
private typealias ColSpec = (covers: [LinearGradient], up: Bool, dur: Double, frac: CGFloat)
private let colSpecs: [ColSpec] = [
    ([pbCovers[0], pbCovers[5],  pbCovers[10], pbCovers[3],  pbCovers[12]], true,  38, 0.00),
    ([pbCovers[1], pbCovers[7],  pbCovers[14], pbCovers[9],  pbCovers[4] ], false, 44, 0.24),
    ([pbCovers[2], pbCovers[8],  pbCovers[11], pbCovers[16], pbCovers[6] ], true,  52, 0.48),
    ([pbCovers[15],pbCovers[13], pbCovers[17], pbCovers[4],  pbCovers[2] ], false, 46, 0.72),
    ([pbCovers[6], pbCovers[1],  pbCovers[9],  pbCovers[12], pbCovers[15]], true,  38, 0.16),
]

/// Animated tiled book-cover wall. Designed to sit behind a dark wash overlay.
/// Set `.ignoresSafeArea()` on the call site so it bleeds under the status bar.
struct BookCoverColumns: View {
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .top, spacing: 10) {
                ForEach(colSpecs.indices, id: \.self) { i in
                    let s = colSpecs[i]
                    CoverColumn(covers: s.covers, upward: s.up,
                                duration: s.dur, startFraction: s.frac)
                }
            }
            .frame(width: geo.size.width + 100, height: geo.size.height + 300,
                   alignment: .topLeading)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .rotationEffect(.degrees(-8))
            .scaleEffect(1.18)
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

private struct CoverColumn: View {
    let covers: [LinearGradient]
    let upward: Bool
    let duration: Double
    let startFraction: CGFloat

    @State private var phase: CGFloat = 0

    private let coverWidth: CGFloat = 70
    private let gap: CGFloat = 10

    var body: some View {
        let coverH = coverWidth * 1.5
        let setH   = CGFloat(covers.count) * (coverH + gap)
        let init0  = startFraction * setH

        // Upward:   dy moves from -init0 toward -(init0 + setH)  [more negative = up]
        // Downward: dy moves from -(2·setH - init0) toward -(setH - init0) [less negative = down]
        let dy: CGFloat = upward
            ? -(init0 + phase)
            : -(2 * setH - init0) + phase

        VStack(spacing: gap) {
            ForEach(0 ..< covers.count * 3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 8)
                    .fill(covers[i % covers.count])
                    .frame(width: coverWidth, height: coverH)
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 4)
            }
        }
        .offset(y: dy)
        .onAppear {
            // Animate exactly one setH so the loop point is visually identical
            // (both endpoints are the same content position modulo setH).
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                phase = setH
            }
        }
    }
}
