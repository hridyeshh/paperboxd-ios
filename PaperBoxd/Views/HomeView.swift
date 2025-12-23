import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    if viewModel.isLoading {
                        // Show skeleton cards while loading
                        ForEach(0..<10, id: \.self) { _ in
                            BookSkeletonCard()
                        }
                    } else {
                        // Show actual books when loaded
                        ForEach(viewModel.books) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                BookCard(book: book)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.loadBooks()
            }
        }
    }
}

#Preview {
    HomeView()
}

