import Combine
import SwiftUI

// MARK: - Aha loading (dark)

struct AhaLoadingView: View {
    private let messages = [
        "Mapping your taste…",
        "Scanning 5M+ books…",
        "Weighing your picks…",
        "Almost there…",
    ]
    @State private var msgIndex = 0
    @State private var pulse = false

    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
                    .frame(width: 96, height: 96)
                    .scaleEffect(pulse ? 1.15 : 0.95)
                    .opacity(pulse ? 0 : 0.6)
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1)
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "book.closed")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(.bottom, 28)

            Text("Finding your book")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .padding(.bottom, 10)

            Text(messages[msgIndex])
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .id(msgIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                msgIndex = (msgIndex + 1) % messages.count
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}

// MARK: - Aha reveal (light)

struct AhaRevealView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your first match")
                        .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                        .textCase(.uppercase)
                        .kerning(2)
                        .foregroundStyle(Color(white: 0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 16)

                    Text("We think you’ll\nlove this.")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(Color(white: 0.07))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineSpacing(2)
                        .padding(.bottom, 28)

                    if let book = viewModel.currentAhaBook {
                        bookCard(book)
                            .id(book.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 24)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.ahaIndex)
            }
            .scrollBounceBehavior(.basedOnSize)

            ctaStack.padding(.horizontal, 26).padding(.bottom, 14)
        }
    }

    private func bookCard(_ book: RecBook) -> some View {
        VStack(spacing: 18) {
            cover(book)
            VStack(spacing: 6) {
                Text(book.title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(white: 0.07))
                    .multilineTextAlignment(.center)
                Text("by \(book.authorLine)")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
            }
            if let reason = book.reason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 13.5))
                    .foregroundStyle(Color(white: 0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cover(_ book: RecBook) -> some View {
        ZStack {
            if let urlStr = book.coverURL, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        coverPlaceholder
                    }
                }
            } else {
                coverPlaceholder
            }
        }
        .frame(width: 150, height: 225)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 16)
    }

    private var coverPlaceholder: some View {
        ZStack {
            Color(white: 0.92)
            Image(systemName: "book.closed")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color(white: 0.6))
        }
    }

    private var ctaStack: some View {
        VStack(spacing: 10) {
            if let err = viewModel.errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(red: 0.82, green: 0.22, blue: 0.22))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            OnboardingPrimaryButton(
                title: "Save to my shelves",
                isLoading: viewModel.isAddingBook
            ) {
                Task { await viewModel.saveToShelf() }
            }

            Button {
                withAnimation { viewModel.showAnother() }
            } label: {
                Text("Show me another")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(white: 0.3))
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(viewModel.isAddingBook)
        }
    }
}
