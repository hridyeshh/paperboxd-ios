import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack {
                Text("Onboarding")
                    .font(.largeTitle)
                    .foregroundColor(.primary)
                    .padding()
                
                Text("This is a placeholder for the onboarding flow.")
                    .foregroundColor(.secondary)
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

