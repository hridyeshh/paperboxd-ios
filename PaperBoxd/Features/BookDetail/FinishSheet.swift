import SwiftUI

/// The finish moment: rate → note → who else loved it → what next. Finishing
/// is the most rewarding action in the product, so it connects the reader to
/// other readers instead of ending at a poster.
struct FinishSheet: View {
    @ObservedObject var viewModel: BookDetailViewModel
    let user: User
    let onWriteNote: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var rating = 0

    private var lovedBy: [BookSocialResponse.Friend] {
        viewModel.socialFriends.filter { $0.status == "read" && ($0.rating ?? 0) >= 4 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FINISHED").font(PB.mono(11)).tracking(2.4).foregroundStyle(.secondary)
                        Text(viewModel.book?.title ?? "").font(PB.serif(24))
                        Text("What did you think? Your followers will see that you finished it.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                                Task { _ = await viewModel.submitReview(rating: star, review: nil) }
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(Color("Accent"))
                            }
                            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
                        }
                    }

                    Button {
                        dismiss()
                        onWriteNote()
                    } label: {
                        Text("Add a note")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.3)))
                    }
                    .buttonStyle(.plain)

                    if let first = lovedBy.first {
                        let others = lovedBy.count - 1
                        Text("\(first.name ?? first.username)\(others > 0 ? " and \(others) other\(others == 1 ? "" : "s") you follow" : "") also loved this.")
                            .font(.subheadline)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !viewModel.similarBooks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("READERS LIKE YOU ALSO LOVED").font(PB.mono(10)).tracking(1.8).foregroundStyle(.secondary)
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(viewModel.similarBooks.prefix(3)) { item in
                                    NavigationLink(value: item.id) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            BookCoverView(url: item.coverURL, width: 96, cornerRadius: 4)
                                            Text(item.title).font(.caption).lineLimit(2)
                                        }
                                        .frame(width: 96, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationDestination(for: String.self) { BookDetailView(bookId: $0, user: user) }
        }
        .presentationDetents([.medium, .large])
        .onAppear { rating = viewModel.myReview?.rating ?? 0 }
    }
}
