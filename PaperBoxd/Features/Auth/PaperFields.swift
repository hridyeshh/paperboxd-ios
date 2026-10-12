import SwiftUI

/// Warm-paper "front door" kit — shared by Login/Register/OTP. PaperBoxd's own
/// brand (same BK tokens as home, book pages) softened into rounded cards and
/// a floating illustrated hero, inspired by Headspace's icon-in-a-card
/// onboarding. Matches the rest of the app instead of diverging into a dark
/// canvas.
enum WarmKit {
    static let field = Color.white.opacity(0.6)
    static let fieldBorder = BK.ink.opacity(0.12)
    static let fieldBorderFocus = BK.ink.opacity(0.4)
    static let error = BK.accent
    static let success = Color(red: 0.15, green: 0.55, blue: 0.32)
}

func warmSerif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
    .system(size: size, weight: weight, design: .serif)
}

// MARK: - Floating hero: icon card + drifting particles

private struct Drift: ViewModifier {
    var delay: Double
    var duration: Double
    func body(content: Content) -> some View {
        content.modifier(DriftAnimator(delay: delay, duration: duration))
    }
}

private struct DriftAnimator: ViewModifier {
    var delay: Double
    var duration: Double
    @State private var animate = false

    func body(content: Content) -> some View {
        content
            .offset(y: animate ? -10 : 0)
            .rotationEffect(.degrees(animate ? 6 : 0))
            .opacity(animate ? 0.9 : 0.5)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                }
            }
    }
}

struct BookHero: View {
    var compact: Bool = false
    @State private var cardIn = false

    var body: some View {
        ZStack {
            Text("✦").font(.system(size: 16)).foregroundStyle(BK.ochre)
                .modifier(Drift(delay: 0, duration: 3.2))
                .offset(x: -34, y: -30)
            Text("❋").font(.system(size: 12)).foregroundStyle(BK.crimson.opacity(0.7))
                .modifier(Drift(delay: 0.6, duration: 2.6))
                .offset(x: 32, y: -22)
            Text("✧").font(.system(size: 14)).foregroundStyle(BK.forest.opacity(0.6))
                .modifier(Drift(delay: 1.1, duration: 3.6))
                .offset(x: -30, y: 28)
            Text("•").font(.system(size: 18)).foregroundStyle(BK.ochre.opacity(0.7))
                .modifier(Drift(delay: 0.3, duration: 2.9))
                .offset(x: 34, y: 26)

            Circle()
                .fill(BK.ochre.opacity(0.28))
                .frame(width: 74, height: 74)
                .blur(radius: 18)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(BK.card)
                .frame(width: 64, height: 64)
                .shadow(color: BK.ink.opacity(0.12), radius: 14, x: 0, y: 8)
                .overlay(
                    Circle()
                        .fill(BK.crimson)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "book.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(BK.cream)
                        )
                )
                .scaleEffect(cardIn ? 1 : 0.7)
                .opacity(cardIn ? 1 : 0)
                .rotationEffect(.degrees(cardIn ? 0 : -6))
        }
        .frame(width: compact ? 96 : 112, height: compact ? 96 : 112)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.68).delay(0.05)) {
                cardIn = true
            }
        }
    }
}

// MARK: - Fields

struct PaperTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var autocapitalisation: TextInputAutocapitalization = .never
    @FocusState private var isFocused: Bool

    var body: some View {
        TextField("", text: $text, prompt: Text(title).foregroundColor(BK.muted.opacity(0.6)))
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(autocapitalisation)
            .autocorrectionDisabled(true)
            .foregroundStyle(BK.ink)
            .focused($isFocused)
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(WarmKit.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isFocused ? WarmKit.fieldBorderFocus : WarmKit.fieldBorder, lineWidth: 1.3)
            )
            .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

struct PaperSecureField: View {
    let title: String
    @Binding var text: String
    var showText: Bool = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if showText {
                TextField("", text: $text, prompt: Text(title).foregroundColor(BK.muted.opacity(0.6)))
                    .textContentType(.password)
            } else {
                SecureField("", text: $text, prompt: Text(title).foregroundColor(BK.muted.opacity(0.6)))
                    .textContentType(.password)
            }
        }
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .foregroundStyle(BK.ink)
        .focused($isFocused)
        .padding(.horizontal, 14)
        .padding(.trailing, 40)
        .frame(height: 50)
        .background(WarmKit.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFocused ? WarmKit.fieldBorderFocus : WarmKit.fieldBorder, lineWidth: 1.3)
        )
        .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

// MARK: - Buttons

struct WarmPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(BK.ink, in: Capsule())
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.35)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.11), value: configuration.isPressed)
    }
}

// MARK: - Entrance / error motion (shared across Login, Register, OTP)

/// Fade + rise-in, gated by a shared `appear` flag with a per-element delay —
/// turns a card from one flat slide-in into fields arriving in sequence.
struct RevealEffect: ViewModifier {
    var appear: Bool
    var delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 14)
            .animation(.spring(response: 0.5, dampingFraction: 0.86).delay(delay), value: appear)
    }
}

struct ShakeValues { var x: CGFloat = 0 }

/// Horizontal shake, keyframe-driven — fires once per `trigger` bump (e.g. a
/// new auth error).
struct ShakeEffect: ViewModifier {
    var trigger: Int

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: ShakeValues(), trigger: trigger) { view, val in
            view.offset(x: val.x)
        } keyframes: { _ in
            KeyframeTrack(\.x) {
                LinearKeyframe(-8, duration: 0.05)
                LinearKeyframe(8, duration: 0.05)
                LinearKeyframe(-6, duration: 0.05)
                LinearKeyframe(6, duration: 0.05)
                LinearKeyframe(-3, duration: 0.05)
                LinearKeyframe(0, duration: 0.05)
            }
        }
    }
}

extension View {
    func reveal(_ appear: Bool, delay: Double) -> some View {
        modifier(RevealEffect(appear: appear, delay: delay))
    }

    func shake(trigger: Int) -> some View {
        modifier(ShakeEffect(trigger: trigger))
    }
}

// MARK: - OTP segmented input

struct PaperOTPBox: View {
    let digit: String
    let isActive: Bool

    var body: some View {
        Text(digit)
            .contentTransition(.numericText())
            .font(.system(size: 24, weight: .semibold, design: .monospaced))
            .foregroundStyle(BK.ink)
            .frame(width: 46, height: 56)
            .background(BK.field)
            .overlay(Rectangle().stroke(isActive ? BK.ink : BK.ink.opacity(0.30), lineWidth: 2))
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: digit)
            .animation(.easeInOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Back row

/// Back chevron + mono label: `PBStepHeader`'s top row for pages that aren't
/// a numbered signup step (sign-in, code entry).
struct PaperBackHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        Button(action: onBack) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BK.ink)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .kerning(1.4)
                    .foregroundStyle(BK.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}

/// Good-enough shape check for auth email fields — not full RFC validation,
/// the backend is the source of truth on submit.
func looksLikeEmail(_ s: String) -> Bool {
    s.contains("@") && s.split(separator: "@").last?.contains(".") == true
}

