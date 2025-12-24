import SwiftUI

struct AuthView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Text("Sign In")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                    .padding()
                
                Text("This is a placeholder for the authentication flow.")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        AuthView()
    }
}

