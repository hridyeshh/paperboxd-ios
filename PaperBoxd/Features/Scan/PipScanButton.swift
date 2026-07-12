import SwiftUI

/// Pip — the little book on the scan button.
/// A closed book with a face, drawn in a wobbly single-weight ink line on a
/// white circle. It blinks and glances while it waits; tap it and it startles
/// awake for a beat, then the scanner opens.
struct PipScanButton: View {
    var action: () -> Void

    @State private var blink = false
    @State private var gaze: CGFloat = 0     // -1…1 eye drift
    @State private var excited = false
    @State private var thinking = false

    /// Stop-motion clock — the whole character only updates on these ticks,
    /// so the ink line boils and poses snap instead of gliding.
    private static let fps: Double = 10

    // Tweaks (mirrors the design-system panel)
    private static let blinkEvery: Double = 2.4
    private static let animationSpeed: Double = 1
    private static let inkWobble: Double = 1.1

    var body: some View {
        Button {
            // scanner opens immediately; the startle pose plays under the
            // incoming cover transition
            excited = true
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                excited = false
            }
        } label: {
            TimelineView(.periodic(from: .now, by: 1.0 / Self.fps)) { timeline in
                // boil "on twos" — wobble frame advances at half the tick rate,
                // otherwise it reads as vibration
                let frame = Int(timeline.date.timeIntervalSinceReferenceDate * Self.fps) / 2
                ZStack {
                    Circle()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)

                    PipGlyph(blink: blink, gaze: gaze, excited: excited, thinking: thinking)
                        .rotationEffect(.degrees(-3 + Self.jitter(frame, salt: 1) * 0.9 * Self.inkWobble))
                        .scaleEffect(excited ? 1.12 : 1)
                }
                .animation(nil, value: frame)
            }
            .frame(width: 64, height: 64)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Scan a book")
        .task { await live() }
    }

    /// Deterministic per-frame noise in -1…1 — cheap hash, no state.
    private static func jitter(_ frame: Int, salt: Int) -> Double {
        var h = UInt64(bitPattern: Int64(frame &* 2654435761 &+ salt &* 40503))
        h ^= h >> 13; h &*= 0x9E3779B97F4A7C15; h ^= h >> 32
        return Double(h % 1000) / 500 - 1
    }

    /// Idle life: blink every few seconds, sometimes glance to a side.
    /// No withAnimation anywhere — instant snaps are the stop-motion look.
    private func live() async {
        let speed = Self.animationSpeed
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.blinkEvery / speed))
            blink = true
            try? await Task.sleep(for: .seconds(0.12 / speed))
            blink = false

            if Bool.random() {
                try? await Task.sleep(for: .seconds(0.5 / speed))
                gaze = Bool.random() ? 1 : -1
                try? await Task.sleep(for: .seconds(1.1 / speed))
                gaze = 0
            }
        }
    }
}

// MARK: - Ink drawing (40×44 canvas)

private struct PipGlyph: View {
    var blink: Bool
    var gaze: CGFloat
    var excited: Bool
    var thinking: Bool

    // line weight 1.1 × base 2.8
    private let ink = StrokeStyle(lineWidth: 3.1, lineCap: .round, lineJoin: .round)

    var body: some View {
        ZStack {
            PipBookOutline().stroke(.black, style: ink)
            PipSpineLine().stroke(.black, style: ink)

            // pages block — solid gray bar detached to the right
            RoundedRectangle(cornerRadius: 1.8)
                .fill(Color(white: 0.35))
                .frame(width: 3.6, height: 15)
                .position(x: 37.2, y: 22)

            PipBrow(raised: excited).stroke(.black, style: ink)

            // eyes
            HStack(spacing: 2.6) {
                Circle().frame(width: 5.2, height: 5.2)
                Circle().frame(width: 5.2, height: 5.2)
            }
            .foregroundStyle(.black)
            .scaleEffect(x: 1, y: blink ? 0.12 : 1)
            // glance drifts up toward the brow, thinking looks aside
            .offset(x: gaze * 1.5 + (thinking ? 1.5 : 0),
                    y: abs(gaze) * -1.4 + (thinking ? -1 : 0))
            .position(x: 19.5, y: excited ? 22 : 23.5)

            if excited {
                PipSparks().stroke(.black, style: ink)
            }
            if thinking {
                PipThoughtSquiggle()
                    .stroke(.black, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: 40, height: 44)
    }
}

/// Wobbly closed-book cover — cubics deliberately off-true for the hand-drawn feel.
private struct PipBookOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 8.2, y: 13))
        p.addCurve(to: CGPoint(x: 13.5, y: 6.4),
                   control1: CGPoint(x: 8.6, y: 9.2), control2: CGPoint(x: 10.5, y: 6.9))
        p.addCurve(to: CGPoint(x: 26, y: 6.2),
                   control1: CGPoint(x: 17.5, y: 5.8), control2: CGPoint(x: 22.5, y: 6.6))
        p.addCurve(to: CGPoint(x: 30.6, y: 11.5),
                   control1: CGPoint(x: 28.8, y: 6.0), control2: CGPoint(x: 30.4, y: 8.2))
        p.addCurve(to: CGPoint(x: 30.9, y: 33),
                   control1: CGPoint(x: 30.9, y: 18), control2: CGPoint(x: 31.3, y: 27))
        p.addCurve(to: CGPoint(x: 26.2, y: 38.6),
                   control1: CGPoint(x: 30.7, y: 36.4), control2: CGPoint(x: 28.8, y: 38.4))
        p.addCurve(to: CGPoint(x: 13.2, y: 38.9),
                   control1: CGPoint(x: 21.5, y: 38.9), control2: CGPoint(x: 16.8, y: 39.3))
        p.addCurve(to: CGPoint(x: 8.4, y: 33.5),
                   control1: CGPoint(x: 10.4, y: 38.6), control2: CGPoint(x: 8.7, y: 36.2))
        p.addCurve(to: CGPoint(x: 8.2, y: 13),
                   control1: CGPoint(x: 7.9, y: 26.5), control2: CGPoint(x: 8.1, y: 19))
        p.closeSubpath()
        return p
    }
}

/// Detached spine line just right of the cover.
private struct PipSpineLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 33.6, y: 10.5))
        p.addCurve(to: CGPoint(x: 33.9, y: 34),
                   control1: CGPoint(x: 34.3, y: 18), control2: CGPoint(x: 33.6, y: 27))
        return p
    }
}

/// One wavy unibrow; jumps up when startled.
private struct PipBrow: Shape {
    var raised: Bool
    func path(in rect: CGRect) -> Path {
        let lift: CGFloat = raised ? -2.5 : 0
        var p = Path()
        p.move(to: CGPoint(x: 12.2, y: 17.2 + lift))
        p.addQuadCurve(to: CGPoint(x: 18, y: 15.2 + lift),
                       control: CGPoint(x: 14.6, y: 13.2 + lift))
        p.addQuadCurve(to: CGPoint(x: 23, y: 14.4 + lift),
                       control: CGPoint(x: 20.5, y: 16.6 + lift))
        p.addQuadCurve(to: CGPoint(x: 26.8, y: 15.6 + lift),
                       control: CGPoint(x: 25.2, y: 13.2 + lift))
        return p
    }
}

/// Little thought scribble above the top-right corner while thinking.
private struct PipThoughtSquiggle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 29, y: 1.5))
        p.addCurve(to: CGPoint(x: 34.5, y: -1.5),
                   control1: CGPoint(x: 29.5, y: -1.5), control2: CGPoint(x: 32.5, y: -3.5))
        p.addCurve(to: CGPoint(x: 32, y: 1.5),
                   control1: CGPoint(x: 36.5, y: 0.5), control2: CGPoint(x: 34.5, y: 2.5))
        p.addCurve(to: CGPoint(x: 36, y: 3),
                   control1: CGPoint(x: 30.5, y: 0.8), control2: CGPoint(x: 33.5, y: 4.2))
        return p
    }
}

/// Startle rays over the book on tap.
private struct PipSparks: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 10, y: 1.5));  p.addLine(to: CGPoint(x: 8, y: -2))
        p.move(to: CGPoint(x: 17, y: 0.5));  p.addLine(to: CGPoint(x: 17, y: -3.5))
        p.move(to: CGPoint(x: 31, y: 1.0));  p.addLine(to: CGPoint(x: 33.5, y: -2.2))
        return p
    }
}

#Preview {
    ZStack {
        Color(white: 0.1).ignoresSafeArea()
        PipScanButton {}
    }
}
