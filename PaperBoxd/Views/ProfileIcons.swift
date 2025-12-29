import SwiftUI

// MARK: - Profile Tab Icons (Based on Design Intuitive App Icons)

/// Star icon for Favourites tab
struct FavouritesIcon: View {
    let isActive: Bool
    
    var body: some View {
        Image(systemName: isActive ? "star.fill" : "star")
            .font(.system(size: 18, weight: isActive ? .semibold : .regular))
    }
}

/// Checklist icon for Lists tab
struct ListsIcon: View {
    let isActive: Bool
    
    var body: some View {
        Image(systemName: "list.bullet.rectangle")
            .font(.system(size: 18, weight: isActive ? .semibold : .regular))
            .symbolVariant(isActive ? .fill : .none)
    }
}

/// Library icon for Bookshelf tab
struct BookshelfIcon: View {
    let isActive: Bool
    
    var body: some View {
        Image(systemName: "books.vertical")
            .font(.system(size: 18, weight: isActive ? .semibold : .regular))
            .symbolVariant(isActive ? .fill : .none)
    }
}

/// Book X icon for DNF tab (book with cross overlay)
struct DNFTabIcon: View {
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Book icon
            Image(systemName: "book.closed")
                .font(.system(size: 18, weight: isActive ? .semibold : .regular))
            
            // Cross/X overlay
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .offset(x: 5, y: -5)
        }
    }
}

// MARK: - Icon Helper
struct ProfileTabIcon: View {
    let tabName: String
    let isActive: Bool
    
    var body: some View {
        Group {
            switch tabName {
            case "Favorites":
                FavouritesIcon(isActive: isActive)
            case "Lists":
                ListsIcon(isActive: isActive)
            case "Bookshelf":
                BookshelfIcon(isActive: isActive)
            case "DNF":
                DNFTabIcon(isActive: isActive)
            default:
                EmptyView()
            }
        }
    }
}

