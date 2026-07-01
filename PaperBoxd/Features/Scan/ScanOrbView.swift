import SwiftUI

/// The analyze hero — a rotating "knowledge graph". Nodes (reddit comments, web
/// reviews, your shelf) sit on a spherical shell; connection lines draw in as the
/// analysis cross-references sources, and the live % counts up in the clear core.
/// Monochrome; the cover-green accent marks "books on your shelf".
struct ScanOrbView: View {
    let done: Bool
    var size: CGFloat = 192

    private let model = OrbModel(count: 132)
    @State private var start = Date()

    // 3D constants (mirror the reference design)
    private var R: CGFloat { size * 0.40 }
    private var focal: CGFloat { R * 3.4 }
    private let tilt: CGFloat = 0.46
    private let revealSecs: Double = 6.8
    private let countSecs: Double = 8.4

    var body: some View {
        ZStack {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSince(start)
                Canvas { ctx, sz in draw(ctx, sz, elapsed: t) }
            }
            .frame(width: size, height: size)

            ring
            core
        }
        .frame(width: size, height: size)
    }

    // MARK: - Canvas

    private func draw(_ ctx: GraphicsContext, _ sz: CGSize, elapsed t: Double) {
        let cx = size / 2, cy = size / 2
        let angY = CGFloat(t) * 0.252
        let cyaw = cos(angY), syaw = sin(angY)
        let ct = cos(tilt), st = sin(tilt)
        let reveal = done ? 1.0 : min(1.0, t / revealSecs)
        let shown = Int(reveal * Double(model.edges.count))

        // Project every node.
        var P = [Projected](repeating: .zero, count: model.nodes.count)
        for (i, n) in model.nodes.enumerated() {
            let x1 = n.x * cyaw - n.z * syaw
            let z1 = n.x * syaw + n.z * cyaw
            let y2 = n.y * ct - z1 * st
            let z2 = n.y * st + z1 * ct
            let sc = focal / (focal + z2 * R)
            P[i] = Projected(
                sx: cx + x1 * R * sc,
                sy: cy + y2 * R * sc,
                depth: z2, sc: sc,
                a: 0.30 + (z2 + 1) / 2 * 0.70
            )
        }

        // Edges — one settled pass + accent flare on the freshest few.
        var settled = Path()
        var fresh = Path()
        for e in 0..<shown {
            let (i, j) = model.edges[e]
            let isFresh = !done && (shown - e) < 6
            var seg = Path()
            seg.move(to: CGPoint(x: P[i].sx, y: P[i].sy))
            seg.addLine(to: CGPoint(x: P[j].sx, y: P[j].sy))
            if isFresh { fresh.addPath(seg) } else { settled.addPath(seg) }
        }
        ctx.stroke(settled, with: .color(SK.ink.opacity(0.20)), lineWidth: 1)
        ctx.stroke(fresh, with: .color(SK.accent.opacity(0.65)), lineWidth: 1.2)

        // Nodes back-to-front.
        let order = P.enumerated().sorted { $0.element.depth < $1.element.depth }
        for (i, p) in order {
            let n = model.nodes[i]
            let pulse = 0.6 + 0.4 * sin(CGFloat(t) / 0.6 + n.phase)
            let r = max(0.6, n.size * p.sc * (n.special ? 1.7 * pulse : 1))
            let rect = CGRect(x: p.sx - r, y: p.sy - r, width: r * 2, height: r * 2)
            let color = n.special ? SK.accent.opacity(p.a) : SK.ink.opacity(p.a)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
        }
    }

    // MARK: - Ring + core

    private var pct: Int {
        let t = max(0, Date().timeIntervalSince(start))
        if done { return 100 }
        let p = min(1, t / countSecs)
        return Int((1 - pow(1 - p, 3)) * 96)
    }

    private var ring: some View {
        TimelineView(.animation) { _ in
            let p = Double(pct) / 100
            ZStack {
                Circle().stroke(SK.track, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: p)
                    .stroke(SK.ink, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size * 0.95, height: size * 0.95)
        }
    }

    private var core: some View {
        TimelineView(.animation) { _ in
            VStack(spacing: 4) {
                HStack(alignment: .top, spacing: 1) {
                    Text("\(pct)")
                        .font(PB.mono(38, .medium))
                        .foregroundStyle(SK.ink)
                        .monospacedDigit()
                    Text("%")
                        .font(PB.mono(16))
                        .foregroundStyle(SK.sub)
                        .padding(.top, 4)
                }
                MonoLabel(text: done ? "read" : "reading", size: 10, tracking: 1.8, color: SK.sub)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Orb geometry (built once)

private struct Projected {
    var sx: CGFloat = 0, sy: CGFloat = 0, depth: CGFloat = 0, sc: CGFloat = 0, a: CGFloat = 0
    static let zero = Projected()
}

private final class OrbModel {
    struct Node { let x, y, z, size, phase: CGFloat; let special: Bool }
    let nodes: [Node]
    let edges: [(Int, Int)]

    init(count N: Int) {
        var ns: [Node] = []
        let gold = CGFloat.pi * (1 + sqrt(5))
        for i in 0..<N {
            let phi = acos(1 - 2 * (CGFloat(i) + 0.5) / CGFloat(N))
            let theta = gold * CGFloat(i)
            let rr = 0.80 + CGFloat.random(in: 0...0.20)
            ns.append(Node(
                x: sin(phi) * cos(theta) * rr,
                y: sin(phi) * sin(theta) * rr,
                z: cos(phi) * rr,
                size: 0.8 + CGFloat.random(in: 0...1.5),
                phase: CGFloat.random(in: 0...(2 * .pi)),
                special: CGFloat.random(in: 0...1) < 0.13
            ))
        }
        self.nodes = ns

        // Each node → its 2 nearest neighbours, de-duped, then shuffled so the
        // reveal looks scattered rather than ordered.
        var seen = Set<Int>()
        var es: [(Int, Int)] = []
        for i in 0..<N {
            var d: [(CGFloat, Int)] = []
            for j in 0..<N where j != i {
                let dx = ns[i].x - ns[j].x, dy = ns[i].y - ns[j].y, dz = ns[i].z - ns[j].z
                d.append((dx*dx + dy*dy + dz*dz, j))
            }
            d.sort { $0.0 < $1.0 }
            for k in 0..<2 {
                let j = d[k].1
                let key = i < j ? i * N + j : j * N + i
                if seen.contains(key) { continue }
                seen.insert(key)
                es.append((i, j))
            }
        }
        es.shuffle()
        self.edges = es
    }
}
