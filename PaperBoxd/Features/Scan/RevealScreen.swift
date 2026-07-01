import SwiftUI

/// 03 — Reveal · THE HINGE. Brutalism resolving into minimalism: a hairline header,
/// a soft rounded score card carrying only a faint green offset (the last trace of
/// the hard shadows), a calm count-up, a serif verdict, whitespace opening up.
struct RevealScreen: View {
    let result: ScanResult
    let onBreakdown: () -> Void
    let onClose: () -> Void

    @State private var ringProgress: CGFloat = 0
    @State private var coverIn = false
    @State private var verdictIn = false

    /// Score-band colour for the progress arc: green (strong), orange (mixed), red (weak).
    private var arcColor: Color {
        switch result.matchScore {
        case 71...100: return Color.green
        case 40...70:  return Color.orange
        default:       return Color.red.opacity(0.8)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer()
            VStack(spacing: 0) {
                ScanCover(result: result, width: 74)
                    .opacity(coverIn ? 1 : 0)
                    .offset(y: coverIn ? 0 : 14)
                    .padding(.bottom, 28)

                card

                Text(result.verdict)
                    .font(PB.serif(27, .semibold))
                    .foregroundStyle(SK.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 28)
                    .padding(.top, 26)
                    .opacity(verdictIn ? 1 : 0)

                Text(result.verdictSub)
                    .font(.system(size: 13))
                    .foregroundStyle(SK.sub)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 36)
                    .padding(.top, 11)
                    .opacity(verdictIn ? 1 : 0)
            }
            Spacer()
            BruButton(title: "See the breakdown", trailing: "chevron.down", action: onBreakdown)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                .opacity(verdictIn ? 1 : 0)
            ScansRemainingFooter()
                .padding(.bottom, 20)
                .opacity(verdictIn ? 1 : 0)
        }
        .background(SK.bgSofter.ignoresSafeArea())
        .onAppear(perform: animateIn)
    }

    private var header: some View {
        HStack {
            MonoLabel(text: "Match score", size: 10.5, tracking: 1.8, color: SK.sub)
            Spacer()
            MonoLabel(text: "for you", size: 10, tracking: 1.2, color: SK.faint)
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(SK.sub)
                    .frame(width: 28, height: 28)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .overlay(alignment: .bottom) { Rectangle().fill(SK.border).frame(height: 1) }
    }

    private var card: some View {
        ZStack {
            Circle().stroke(SK.track, lineWidth: 8)
            Circle()
                .trim(from: 0, to: ringProgress)
                .stroke(arcColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            HStack(alignment: .top, spacing: 2) {
                CountUpText(target: result.matchScore, duration: 1.4,
                            font: PB.mono(60, .medium), color: SK.ink, grouping: false)
                Text("/100").font(PB.mono(14)).foregroundStyle(SK.sub).padding(.top, 10)
            }
        }
        .frame(width: 168, height: 168)
        .padding(20)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(SK.ink, lineWidth: 1.5))
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(SK.accent).offset(x: 3, y: 3)
        )
    }

    private func animateIn() {
        withAnimation(.easeOut(duration: 0.5)) { coverIn = true }
        withAnimation(.easeOut(duration: 1.4).delay(0.3)) { ringProgress = CGFloat(result.matchScore) / 100 }
        withAnimation(.easeOut(duration: 0.6).delay(1.1)) { verdictIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }
}
