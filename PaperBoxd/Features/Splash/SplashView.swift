import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var appState: AppState

    @State private var videoIn  = false
    @State private var chromeIn = false
    /// Set when the clip reaches its end — everything on the white ground fades
    /// out first, so the hand-off to the next screen reads as one movement
    /// instead of a cut.
    @State private var outro    = false
    @State private var dotsOn   = false
    @State private var captionIdx = 0

    /// How long the clip takes to fade off the paper ground once it ends.
    /// `AppState.holdSplash` is floored above clip + this, so routing never
    /// interrupts the fade.
    static let outroDuration: TimeInterval = 0.5

    private let captions = [
        "Opening your library…",
        "Pulling your shelves…",
        "Brewing your taste…",
    ]

    var body: some View {
        ZStack {
            // The clip's ground is tinted to the same paper beige the home
            // screen uses, so the screen behind it is that colour too: no video
            // frame edge, and the outro fades into the colour the app is about
            // to show rather than through white.
            BK.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                SplashVideoView(
                    resource: "splash",
                    ext: "mp4",
                    // No fade in: the clip's first frame is the same paper as
                    // the screen behind it, so it cuts in invisibly. Fading it
                    // would read as a video loading. The outro still fades.
                    onReady: { videoIn = true },
                    onFinished: { withAnimation(.easeInOut(duration: SplashView.outroDuration)) { outro = true } }
                )
                .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .opacity(outro ? 0 : (videoIn ? 1 : 0))
                .allowsHitTesting(false)

                Spacer()

                // Loading dots
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(.black)
                            .frame(width: 5, height: 5)
                            .opacity(dotsOn ? 0.55 : 0.14)
                            .scaleEffect(dotsOn ? 1.1 : 0.9)
                            .animation(
                                .easeInOut(duration: 0.48)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(i) * 0.16),
                                value: dotsOn
                            )
                    }
                }
                .padding(.bottom, 10)
                .opacity(outro ? 0 : 1)

                // Cycling caption
                ZStack {
                    ForEach(captions.indices, id: \.self) { i in
                        Text(captions[i])
                            .font(.system(size: 10.5, design: .monospaced))
                            .textCase(.uppercase)
                            .kerning(1.4)
                            .foregroundStyle(.black.opacity(0.38))
                            .opacity(captionIdx == i ? 1 : 0)
                            .offset(y: captionIdx == i ? 0 : 4)
                            .animation(.easeInOut(duration: 0.35), value: captionIdx)
                    }
                }
                .frame(height: 16)
                .padding(.bottom, 52)
                .opacity(outro ? 0 : (chromeIn ? 1 : 0))
                .animation(.easeOut(duration: 0.5).delay(0.3), value: chromeIn)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            chromeIn = true
            dotsOn   = true
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                captionIdx = (captionIdx + 1) % captions.count
            }
        }
        .task {
            guard !PreviewRuntime.isRunning else { return }
            await appState.bootstrap()
        }
    }
}
