import SwiftUI

/// Profile tab dock. At rest each tab is an icon; the selected one is its NAME.
///
/// The switch is an ink handoff, not a cross-fade: the icon's stroke retracts
/// toward the tab's leading edge (`.trim`) while the word grows out of that same
/// point behind a leading-anchored mask. Leaving a tab runs it the other way —
/// and in both directions the outgoing mark erases *before* the incoming one
/// draws, so the two never overlap. Hence no icon beside the active label: the
/// icon became the word.
struct ProfileDockView: View {
    @Binding var selected: ProfileTab
    var count: (ProfileTab) -> Int?
    var onSelect: (ProfileTab) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let iconSize: CGFloat = 19
    private let tabHeight: CGFloat = 42
    private let leadingInset: CGFloat = 12

    var body: some View {
        // The four tabs span the full width: the open one takes what its word
        // needs and the rest share what's left, so the row never trails off
        // into empty paper after the last icon.
        HStack(spacing: 10) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 20)
        .overlay(alignment: .bottom) { Rectangle().fill(Color("Border")).frame(height: 1) }
    }

    private func tabButton(_ tab: ProfileTab) -> some View {
        let on = selected == tab

        return Button { onSelect(tab) } label: {
            VStack(spacing: 0) {
                ZStack {
                    icon(tab, on: on)
                    label(tab, on: on)
                }
                .frame(maxWidth: .infinity)
                .frame(height: tabHeight)

                Rectangle()
                    .fill(on ? Color("TextPrimary") : Color.clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: selected)
            }
            // The open tab caps at the width its word needs; the closed ones stay
            // flexible and divide the remainder between them. 44 is the floor so
            // an icon-only tab never drops under the minimum hit target.
            .frame(minWidth: 44, maxWidth: on ? width(of: tab) : .infinity)
            .clipped()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(widthMotion, value: selected)
        // The name is spoken whether the tab is showing an icon, a word, or
        // half of each mid-transition.
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - The two halves of the handoff

    @ViewBuilder
    private func icon(_ tab: ProfileTab, on: Bool) -> some View {
        let ink = on ? Color("TextPrimary") : Color("TextSecondary")

        ZStack {
            ProfileTabMark(kind: tab.mark)
                .trim(from: 0, to: on ? 0 : 1)
                .stroke(ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: iconSize, height: iconSize)
                .animation(iconMotion(on: on), value: selected)

            if tab == .lists {
                ProfileTabListDots(size: iconSize, color: ink)
                    .opacity(on ? 0 : 1)
                    .animation(.linear(duration: 0.09), value: selected)
            }
        }
        // Reduce Motion collapses the whole thing to a plain swap.
        .opacity(reduceMotion ? (on ? 0 : 1) : 1)
    }

    private func label(_ tab: ProfileTab, on: Bool) -> some View {
        HStack(spacing: 5) {
            Text(tab.rawValue)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Color("TextPrimary"))
            if let n = count(tab) {
                Text("\(n)")
                    .font(PB.mono(10))
                    .foregroundStyle(Color("TextSecondary").opacity(0.8))
            }
        }
        .fixedSize()
        // Anchored at the centre, which is where the icon sits: the word opens
        // out of the point the stroke retracted into.
        .mask {
            Rectangle().scaleEffect(x: on ? 1 : 0, anchor: .center)
        }
        .scaleEffect(on ? 1 : 0.94, anchor: .center)
        .opacity(on ? 1 : 0)
        .animation(labelMotion(on: on), value: selected)
    }

    // MARK: - Motion
    //
    // Entering: icon erases (0ms, 180) → word draws (120ms, 220). 340 total.
    // Leaving:  word erases (0ms, 160) → icon redraws (120ms, 200). 320 total.
    // The width runs across the whole gesture so nothing snaps into place.

    private var widthMotion: Animation {
        reduceMotion ? .easeInOut(duration: 0.14)
                     : .timingCurve(0.32, 0.72, 0, 1, duration: 0.30)
    }

    private func iconMotion(on: Bool) -> Animation {
        if reduceMotion { return .linear(duration: 0.1) }
        return on
            ? .timingCurve(0.4, 0, 1, 1, duration: 0.18)                  // erase
            : .timingCurve(0, 0, 0.2, 1, duration: 0.20).delay(0.12)      // redraw
    }

    private func labelMotion(on: Bool) -> Animation {
        if reduceMotion { return .linear(duration: 0.1) }
        return on
            ? .timingCurve(0, 0, 0.2, 1, duration: 0.22).delay(0.12)      // draw
            : .timingCurve(0.4, 0, 1, 1, duration: 0.16)                  // erase
    }

    // MARK: - Expanded width
    //
    // The tab is clipped, so the open width is measured rather than left to the
    // label: an intrinsic width would fight the collapse animation. The inset is
    // counted twice — it's breathing room either side of the centred word.

    private func width(of tab: ProfileTab) -> CGFloat {
        let title = (tab.rawValue as NSString).size(
            withAttributes: [.font: UIFont.systemFont(ofSize: 13.5, weight: .semibold)]
        ).width
        var w = leadingInset + title + leadingInset
        if let n = count(tab) {
            let num = ("\(n)" as NSString).size(
                withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)]
            ).width
            w += 5 + num
        }
        return ceil(w)
    }
}
