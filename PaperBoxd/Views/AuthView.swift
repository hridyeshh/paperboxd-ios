import SwiftUI

struct AuthView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Text("Sign In")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                
                Text("This is a placeholder for the authentication flow.")
                    .foregroundColor(.gray)
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

