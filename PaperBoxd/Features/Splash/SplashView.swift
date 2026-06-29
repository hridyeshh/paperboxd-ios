import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var appState: AppState

    @State private var wordmarkIn = false
    @State private var taglineIn  = false
    @State private var dotsOn     = false
    @State private var captionIdx = 0

    private let captions = [
        "Opening your library…",
        "Pulling your shelves…",
        "Brewing your taste…",
    ]

    var body: some View {
        ZStack {
            Color(red: 0.09, green: 0.09, blue: 0.09).ignoresSafeArea()
            BookCoverColumns().ignoresSafeArea()
            darkWash

            VStack(spacing: 0) {
                Spacer()

                // Wordmark
                Text("PaperBoxd")
                    .font(.custom("SnellRoundhand-Black", size: 46))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.55), radius: 14, y: 4)
                    .opacity(wordmarkIn ? 1 : 0)
                    .scaleEffect(wordmarkIn ? 1 : 0.96)
                    .animation(.easeOut(duration: 0.7), value: wordmarkIn)

                // Tagline
                Text("Your reading universe, organised.")
                    .font(.system(size: 15, design: .serif).italic())
                    .foregroundStyle(.white.opacity(0.58))
                    .padding(.top, 14)
                    .opacity(taglineIn ? 1 : 0)
                    .offset(y: taglineIn ? 0 : 5)
                    .animation(.easeOut(duration: 0.6).delay(0.5), value: taglineIn)

                Spacer()

                // Loading dots
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(.white)
                            .frame(width: 5, height: 5)
                            .opacity(dotsOn ? 0.9 : 0.2)
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

                // Cycling caption
                ZStack {
                    ForEach(captions.indices, id: \.self) { i in
                        Text(captions[i])
                            .font(.system(size: 10.5, design: .monospaced))
                            .textCase(.uppercase)
                            .kerning(1.4)
                            .foregroundStyle(.white.opacity(0.42))
                            .opacity(captionIdx == i ? 1 : 0)
                            .offset(y: captionIdx == i ? 0 : 4)
                            .animation(.easeInOut(duration: 0.35), value: captionIdx)
                    }
                }
                .frame(height: 16)
                .padding(.bottom, 52)
            }
        }
        .onAppear {
            wordmarkIn = true
            taglineIn  = true
            dotsOn     = true
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

    private var darkWash: some View {
        ZStack {
            RadialGradient(
                colors: [.black.opacity(0.5), .black.opacity(0.76), .black.opacity(0.93)],
                center: .center, startRadius: 0, endRadius: 440
            )
            LinearGradient(
                colors: [.black.opacity(0.42), .black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
