import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Text("Onboarding")
                    .font(.largeTitle)
                    .foregroundColor(.white)
                    .padding()
                
                Text("This is a placeholder for the onboarding flow.")
                    .foregroundColor(.gray)
                    .padding()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationView {
        OnboardingView()
    }
}

