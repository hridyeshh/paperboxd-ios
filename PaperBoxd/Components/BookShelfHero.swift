import SwiftUI

// MARK: - Shelf data

/// One board on the shelf. Widths, heights, cloth and foil all vary so the row
/// reads as a shelf of books rather than a row of swatches; `lean` tips the
/// occasional leaner so the tops don't march like a picket fence.
struct ShelfSpine {
    let title: String
    let cloth: Color
    let foil: Color
    let width: CGFloat
    let height: CGFloat
    var lean: Double = 0
}

private func makeDeck(_ rows: [(String, String, String, CGFloat, CGFloat)]) -> [ShelfSpine] {
    rows.enumerated().map { i, r in
        ShelfSpine(
            title: r.0,
            cloth: Color(hex: r.1),
            foil: Color(hex: r.2),
            width: r.3,
            height: r.4,
            // Two leaners break the rhythm; the rest stand square.
            lean: i == 5 ? -3.5 : i == 11 ? 2.5 : 0
        )
    }
}

extension ShelfSpine {
    /// Sign-in deck. Cloth / foil pairs at real saturation — oxblood, ochre,
    /// forest, indigo, plum, teal — plus bone and cream boards for rhythm.
    static let signIn: [ShelfSpine] = makeDeck([
        ("Middlemarch",         "8C2B22", "E7C77A", 46, 190),
        ("The Waves",           "1B4B3C", "D8B45C", 30, 176),
        ("Dubliners",           "C9962B", "3A2C1C", 38, 184),
        ("Beloved",             "23304F", "D8B45C", 27, 168),
        ("Wide Sargasso Sea",   "6A2350", "EDD9A8", 42, 192),
        ("The Idiot",           "EDE0C4", "8C2B22", 34, 172),
        ("Cannery Row",         "14595E", "E7C77A", 25, 182),
        ("A Room of One’s Own", "C0271C", "FFF0CC", 48, 178),
        ("Ficciones",           "33306B", "D8B45C", 31, 194),
        ("The Leopard",         "B5642A", "2A1C0E", 36, 166),
        ("Pale Fire",           "1E6B52", "EDD9A8", 28, 186),
        ("Stoner",              "E3D5B8", "23304F", 44, 174),
        ("The Sea, The Sea",    "2A3A5A", "C9962B", 26, 190),
        ("Silas Marner",        "7A2E1B", "E7C77A", 40, 170),
        ("Orlando",             "B5456B", "FFF0CC", 32, 188),
        ("The Rings of Saturn", "23211E", "D8B45C", 29, 180),
    ])

    /// Register deck: same library, reshuffled and shorter for the lower band.
    static let register: [ShelfSpine] = makeDeck([
        ("Wide Sargasso Sea",   "6A2350", "EDD9A8", 42, 152),
        ("The Waves",           "1B4B3C", "D8B45C", 30, 140),
        ("Dubliners",           "C9962B", "3A2C1C", 38, 148),
        ("Beloved",             "23304F", "D8B45C", 27, 134),
        ("Middlemarch",         "8C2B22", "E7C77A", 46, 154),
        ("The Idiot",           "EDE0C4", "8C2B22", 34, 138),
        ("Cannery Row",         "14595E", "E7C77A", 25, 146),
        ("Orlando",             "B5456B", "FFF0CC", 32, 150),
        ("Ficciones",           "33306B", "D8B45C", 31, 156),
        ("The Leopard",         "B5642A", "2A1C0E", 36, 132),
        ("Pale Fire",           "1E6B52", "EDD9A8", 28, 149),
        ("Stoner",              "E3D5B8", "23304F", 44, 140),
        ("The Sea, The Sea",    "2A3A5A", "C9962B", 26, 152),
        ("Silas Marner",        "7A2E1B", "E7C77A", 40, 136),
        ("A Room of One’s Own", "C0271C", "FFF0CC", 48, 144),
        ("The Rings of Saturn", "23211E", "D8B45C", 29, 147),
    ])
}

// MARK: - Vertical foil title

/// A title running down a spine. SwiftUI has no `writing-mode`, so the line is
/// laid out flat, capped to `run` (which truncates a long title), then turned a
/// quarter clockwise. `run` becomes the drawn height, so the caller reserves it.
struct SpineTitle: View {
    let text: String
    var size: CGFloat
    var weight: Font.Weight = .semibold
    var kerning: CGFloat = 0.4
    let color: Color
    let run: CGFloat

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: weight, design: .serif))
            .kerning(kerning)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(color)
            .frame(width: run)
            .rotationEffect(.degrees(90))
            .frame(width: size * 1.5, height: run)
    }
}

// MARK: - Hero

/// The auth hero: a shelf of cloth-bound spines drifting slowly left, standing
/// on a plank that casts a shadow onto the floor in front of it. Replaces the
/// old gradient cover wall (`BookCoverColumns`).
struct BookShelfHero: View {
    var spines: [ShelfSpine] = ShelfSpine.signIn
    var height: CGFloat = 244
    var rowHeight: CGFloat = 200
    var leadingPad: CGFloat = 14
    var duration: Double = 90
    var titleSize: CGFloat = 10.5
    var maxTitleRun: CGFloat = 118
    var spinePadding: CGFloat = 9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    private let gap: CGFloat = 3
    private let plankHeight: CGFloat = 5
    private let floorHeight: CGFloat = 30
    private let castHeight: CGFloat = 16

    /// Distance from the start of one copy of the deck to the start of the next
    /// at full size: n boards plus n gaps. Drifting exactly this far hides the
    /// loop point.
    private var setWidth: CGFloat {
        spines.reduce(0) { $0 + $1.width + gap }
    }

    var body: some View {
        // Greedy but capped: the band takes the slack the card leaves it, up to
        // `height`, and the shelf scales to whatever that turns out to be rather
        // than clipping the tallest boards flat.
        GeometryReader { geo in
            let room = max(0, geo.size.height - floorHeight - plankHeight + 1)
            // The boards are built at this scale rather than drawn at full
            // size and shrunk — a scaleEffect leaves the layout width at full
            // size, and then the copy count below can't be trusted.
            let shelfScale = min(1, room / rowHeight)
            let stride = setWidth * shelfScale
            ZStack(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "EFE7D6"), location: 0),
                        .init(color: Color(hex: "E8DCC4"), location: 0.62),
                        .init(color: Color(hex: "DCCFB2"), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                row(scale: shelfScale, stride: stride,
                    copies: max(2, 1 + Int((geo.size.width / max(stride, 1)).rounded(.up))))
                    .frame(height: room, alignment: .bottom)
                    .offset(y: -(floorHeight + plankHeight - 1))

                floor
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
            .clipped()
        }
        .frame(maxHeight: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    /// Floor, then the shadow the boards throw across it, then the plank they
    /// stand on. Painted in that order so the shadow reads.
    private var floor: some View {
        ZStack(alignment: .bottom) {
            Rectangle().fill(Color(hex: "DCCFB2"))
                .frame(height: floorHeight)

            LinearGradient(colors: [BK.plank.opacity(0.30), BK.plank.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: castHeight)
                .padding(.bottom, floorHeight - castHeight)

            Rectangle().fill(BK.plank)
                .frame(height: plankHeight)
                .padding(.bottom, floorHeight)

            // The floor dissolves into the paper the rest of the screen sits on.
            LinearGradient(colors: [Color(hex: "DCCFB2").opacity(0), BK.paper],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: floorHeight)
        }
        .frame(height: floorHeight + plankHeight, alignment: .bottom)
    }

    /// One copy walks off the left edge each pass, so the copies behind it have
    /// to cover the band on their own. Two is only ever enough at full size.
    private func row(scale: CGFloat, stride: CGFloat, copies: Int) -> some View {
        HStack(alignment: .bottom, spacing: gap * scale) {
            ForEach(0 ..< spines.count * copies, id: \.self) { i in
                spine(spines[i % spines.count], scale: scale)
            }
        }
        .fixedSize()
        .padding(.leading, leadingPad * scale)
        .offset(x: -phase * stride)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func spine(_ s: ShelfSpine, scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            foilRule(s, scale: scale)
            Spacer(minLength: 0)
            SpineTitle(
                text: s.title,
                size: titleSize * scale,
                color: s.foil,
                run: min(maxTitleRun, s.height - spinePadding * 2 - 16) * scale
            )
            Spacer(minLength: 0)
            foilRule(s, scale: scale)
        }
        .padding(.vertical, spinePadding * scale)
        .frame(width: s.width * scale, height: s.height * scale)
        .background(s.cloth)
        // Board curvature: lit at the hinge, falling into shadow at the fore-edge.
        .overlay(alignment: .leading) {
            LinearGradient(colors: [.white.opacity(0.10), .clear],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 5)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(colors: [.clear, .black.opacity(0.28)],
                           startPoint: .leading, endPoint: .trailing)
                .frame(width: 7)
        }
        // The bottom edge of this border is hidden by the plank drawn over it.
        .overlay(Rectangle().strokeBorder(Color(hex: "15100A").opacity(0.55), lineWidth: 1.5))
        .rotationEffect(.degrees(s.lean), anchor: .bottom)
    }

    private func foilRule(_ s: ShelfSpine, scale: CGFloat) -> some View {
        Rectangle().fill(s.foil).frame(width: s.width * 0.76 * scale, height: max(1, 2 * scale))
    }
}
