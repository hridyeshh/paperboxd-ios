import SwiftUI

/// Rate + review sheet for the book page. Stars are required, text optional.
/// Posting stores both on the viewer's bookshelf entry and refreshes the
/// Reviews tab via the shared view model.
struct RateReviewSheet: View {
    @ObservedObject var viewModel: BookDetailViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var rating: Int?
    @State private var reviewText = ""
    @FocusState private var reviewFocused: Bool

    var body: some View {
        ZStack {
            Color("Background").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Your rating")
                        RatingPickerView(rating: $rating)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "Your review")
                        ZStack(alignment: .topLeading) {
                            if reviewText.isEmpty {
                                Text("Write your thoughts...")
                                    .font(PB.serifItalic(15))
                                    .foregroundStyle(Color("TextSecondary").opacity(0.7))
                                    .padding(.top, 12)
                                    .padding(.leading, 14)
                            }
                            TextEditor(text: $reviewText)
                                .focused($reviewFocused)
                                .font(.system(size: 15, design: .serif))
                                .foregroundStyle(Color("TextPrimary"))
                                .scrollContentBackground(.hidden)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .frame(minHeight: 140)
                        }
                        .background(Color("Surface"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color("Border"), lineWidth: 1)
                        )
                    }

                    postButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)

                Spacer(minLength: 0)
            }
        }
        .onAppear {
            // Pre-fill with the existing review so posting acts as an edit.
            if let mine = viewModel.myReview {
                rating = mine.rating
                reviewText = mine.review ?? ""
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 14))
                .foregroundStyle(Color("TextSecondary"))
            Spacer()
            Text(viewModel.book?.title ?? "Rate this book")
                .font(PB.serif(16))
                .foregroundStyle(Color("TextPrimary"))
                .lineLimit(1)
            Spacer()
            // balances the Cancel button so the title stays centered
            Text("Cancel").font(.system(size: 14)).hidden()
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
    }

    private var postButton: some View {
        Button {
            guard let rating else { return }
            let trimmed = reviewText.trimmingCharacters(in: .whitespacesAndNewlines)
            Task {
                if await viewModel.submitReview(rating: rating, review: trimmed.isEmpty ? nil : trimmed) {
                    dismiss()
                }
            }
        } label: {
            HStack(spacing: 7) {
                if viewModel.isSubmittingReview {
                    ProgressView().tint(Color("Background"))
                }
                Text("Post Review")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Color("Background"))
            .frame(maxWidth: .infinity).frame(height: 46)
            .background(
                Color("TextPrimary").opacity(rating == nil ? 0.4 : 1),
                in: RoundedRectangle(cornerRadius: 11, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(rating == nil || viewModel.isSubmittingReview)
    }
}
