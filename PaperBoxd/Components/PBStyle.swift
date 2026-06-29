import SwiftUI

/// PaperBoxd shared design system. Mirrors the editorial language in
/// "Paperboxd design elements" (colors_and_type.css + profile/search/home mocks).
/// Display faces are Typekit-only, so we approximate with SwiftUI system designs:
///   • serif      → Playfair Display / cofo-glassier headings
///   • monospaced → Geist Mono / JetBrains Mono eyebrows + numbers
///   • Snell Roundhand → brooklyn-heritage-script / Pinyon Script wordmark
enum PB {
    // MARK: - Palette (inline accents the asset catalog doesn't carry)

    /// Warm terracotta used for avatar rings/gradients in the mocks (#d97757 → #6b3520).
    static let terracotta = Color(red: 0.851, green: 0.467, blue: 0.341)
    static let terracottaDeep = Color(red: 0.420, green: 0.208, blue: 0.125)
    /// Warm crimson for the active "liked" heart (slightly desaturated, tinted off pure red).
    static let likeRed = Color(red: 0.843, green: 0.157, blue: 0.180)
    static var avatarGradient: LinearGradient {
        LinearGradient(colors: [terracotta, terracottaDeep],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: - Fonts

    static func wordmark(_ size: CGFloat) -> Font {
        .custom("SnellRoundhand-Bold", size: size)
    }
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    static func serifItalic(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif).italic()
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Eyebrow (mono, uppercase, wide tracking)

struct Eyebrow: View {
    let text: String
    var color: Color = Color("TextSecondary")
    var body: some View {
        Text(text.uppercased())
            .font(PB.mono(10, .medium))
            .tracking(2.0)
            .foregroundStyle(color)
    }
}

// MARK: - Section header (eyebrow + serif title + optional trailing action)

struct SectionHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(PB.serif(19))
                    .foregroundStyle(Color("TextPrimary"))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = EmptyView()
    }
}

// MARK: - "See all →" style link button

struct SeeAllButton: View {
    var label: String = "See all"
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("\(label) →")
                .font(.system(size: 11.5))
                .foregroundStyle(Color("TextSecondary"))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pill button (Follow / Edit / Message)

struct PillButton: View {
    enum Style { case primary, ghost }
    let title: String
    var systemImage: String? = nil
    var style: Style = .primary
    var loading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if loading {
                    ProgressView()
                        .tint(style == .primary ? Color("Background") : Color("TextPrimary"))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    if let icon = systemImage {
                        Image(systemName: icon).font(.system(size: 11, weight: .bold))
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(style == .primary ? Color("Background") : Color("TextPrimary"))
            .background(style == .primary ? Color("TextPrimary") : Color.clear)
            .clipShape(Capsule())
            .overlay {
                if style == .ghost {
                    Capsule().strokeBorder(Color("Border"), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }
}

// MARK: - Shimmer

extension View {
    func pbShimmer() -> some View { overlay(PBShimmer()) }
}

private struct PBShimmer: View {
    @State private var phase: CGFloat = -1
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white.opacity(0.08), location: 0.45),
                    .init(color: .white.opacity(0.13), location: 0.5),
                    .init(color: .white.opacity(0.08), location: 0.55),
                    .init(color: .clear, location: 1),
                ]),
                startPoint: .leading, endPoint: .trailing
            )
            .frame(width: geo.size.width * 2)
            .offset(x: geo.size.width * phase)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
        }
        .clipped()
    }
}
