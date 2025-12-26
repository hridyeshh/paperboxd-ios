import SwiftUI

struct SignUpSheet: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("isLoggedIn") private var isLoggedIn = false
    
    // Binding to communicate expansion state to parent
    @Binding var isExpanded: Bool
    
    // Current Step Tracker
    @State private var step = 1
    private let totalSteps = 5
    
    // Form Data
    @State private var email = ""
    @State private var password = ""
    @State private var username = ""
    @State private var birthDate = Date()
    @State private var genderSelection = "Male"
    @State private var customGender = ""
    
    // Loading and error states
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // Focus tracking for auto-expanding sheet
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password, username, customGender
    }
    
    // Gender Options
    let genders = ["Male", "Female", "Custom"]
    
    init(isExpanded: Binding<Bool> = .constant(false)) {
        self._isExpanded = isExpanded
    }
    
    var body: some View {
        ZStack {
            // System background
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // PROGRESS BAR
                    HStack(spacing: 4) {
                        ForEach(1...totalSteps, id: \.self) { index in
                            Capsule()
                                .fill(index <= step ? Color.primary : Color.secondary.opacity(0.3))
                                .frame(height: 4)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.top, 50)
                    .padding(.bottom, 30)
                    
                    // THE WIZARD CONTENT
                    VStack(alignment: .leading) {
                        switch step {
                        case 1: emailStep
                        case 2: passwordStep
                        case 3: usernameStep
                        case 4: birthdayStep
                        case 5: genderStep
                        default: Text("Done")
                            .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                    .animation(.easeInOut, value: step)
                    
                    // NAVIGATION BUTTONS
                    HStack {
                        if step > 1 {
                            Button(action: { 
                                // Dismiss keyboard when going back
                                focusedField = nil
                                withAnimation {
                                    step -= 1
                                }
                            }) {
                                Text("Back")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            // Dismiss keyboard when proceeding
                            focusedField = nil
                            if step < totalSteps {
                                withAnimation {
                                    step += 1
                                }
                            } else {
                                // Handle Final Sign Up Logic
                                handleSignUp()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: Color(uiColor: .systemBackground)))
                                } else {
                                    Text(step == totalSteps ? "Finish" : "Next")
                                        .fontWeight(.bold)
                                }
                            }
                            .foregroundColor(Color(uiColor: .systemBackground))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 32)
                            .background(Color.primary)
                            .cornerRadius(30)
                        }
                        .disabled(isLoading)
                        
                        // Error message display
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 30)
            }
            .onChange(of: focusedField) { oldValue, newValue in
                // Expand to full screen when any text field is focused
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded = newValue != nil
                }
            }
        }
    }
    
    // MARK: - STEP 1: EMAIL
    var emailStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("What's your email?")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            ZStack(alignment: .leading) {
                // Placeholder text (shown when field is empty)
                if email.isEmpty {
                    Text("example@email.com")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                
                TextField("", text: $email)
                    .focused($focusedField, equals: .email)
                    .foregroundColor(.primary)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .tint(.primary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - STEP 2: PASSWORD (With Gradient Strength)
    var passwordStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Create a password")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            SecureField("", text: $password, prompt: Text("Password").foregroundColor(.secondary))
                .focused($focusedField, equals: .password)
                .padding()
                .foregroundColor(.primary)
                .background(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(12)
                .tint(.primary)
            
            // The Gradient Strength Meter
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 6)
                        
                        // Active Strength Bar
                        RoundedRectangle(cornerRadius: 5)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 0.6, green: 0.9, blue: 0.6), // Light Green
                                        Color(red: 0.3, green: 0.4, blue: 0.0)  // Olive Green
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: calculateStrengthWidth(totalWidth: geometry.size.width), height: 6)
                            .animation(.spring(), value: password)
                    }
                }
                .frame(height: 6)
                
                Text(passwordStrengthText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - STEP 3: USERNAME
    var usernameStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pick a username")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            TextField("", text: $username, prompt: Text("@username").foregroundColor(.secondary))
                .focused($focusedField, equals: .username)
                .padding()
                .foregroundColor(.primary)
                .background(Color(uiColor: .secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(12)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(.primary)
        }
    }
    
    // MARK: - STEP 4: BIRTHDAY
    var birthdayStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("When is your birthday?")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            DatePicker("", selection: $birthDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 120)
                .scaleEffect(0.85)
                .offset(y: -10)
        }
    }
    
    // MARK: - STEP 5: GENDER
    var genderStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Select your gender")
                .font(.title2.bold())
                .foregroundColor(.primary)
            
            // Custom Selection Grid
            HStack(spacing: 12) {
                ForEach(genders, id: \.self) { gender in
                    Button(action: {
                        withAnimation { genderSelection = gender }
                    }) {
                        Text(gender)
                            .fontWeight(.medium)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(genderSelection == gender ? Color.primary : Color(uiColor: .secondarySystemBackground))
                            .foregroundColor(genderSelection == gender ? Color(uiColor: .systemBackground) : .primary)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            
            // Custom Input Field (Shows only if "Custom" is picked)
            if genderSelection == "Custom" {
                TextField("", text: $customGender, prompt: Text("Type your gender").foregroundColor(.secondary))
                    .focused($focusedField, equals: .customGender)
                    .padding()
                    .foregroundColor(.primary)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .tint(.primary)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // Helper: Logic for Password Bar Width
    func calculateStrengthWidth(totalWidth: CGFloat) -> CGFloat {
        if password.isEmpty { return 0 }
        let strength = min(CGFloat(password.count) / 10.0, 1.0) // Simple length check
        return totalWidth * strength
    }
    
    var passwordStrengthText: String {
        switch password.count {
        case 0: return ""
        case 1...5: return "Weak"
        case 6...9: return "Good"
        default: return "Strong"
        }
    }
    
    /// Handle user registration
    private func handleSignUp() {
        // Validate required fields
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all required fields"
            return
        }
        
        // Validate email format (basic check)
        guard email.contains("@") && email.contains(".") else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        // Validate password strength
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            return
        }
        
        // Clear previous error
        errorMessage = nil
        isLoading = true
        
        Task {
            do {
                // Determine the name to use (username or email prefix)
                let name = username.isEmpty ? email.components(separatedBy: "@").first ?? "User" : username
                
                // Call the registration API
                let response: AuthResponse = try await APIClient.shared.register(
                    name: name,
                    email: email,
                    password: password
                )
                
                // Save token securely to Keychain
                KeychainHelper.shared.saveToken(response.token)
                
                print("✅ SignUpSheet: Successfully registered user: \(response.user.email)")
                
                // Update UI on main thread
                await MainActor.run {
                    isLoggedIn = true
                    isLoading = false
                    dismiss()
                }
            } catch let error as APIError {
                await MainActor.run {
                    isLoading = false
                    switch error {
                    case .httpError(let statusCode):
                        if statusCode == 400 {
                            errorMessage = "Email already registered or invalid data"
                        } else if statusCode == 409 {
                            errorMessage = "This email is already registered"
                        } else {
                            errorMessage = "Registration failed. Please try again."
                        }
                    case .networkError:
                        errorMessage = "Network error. Please check your connection."
                    default:
                        errorMessage = "Registration failed. Please try again."
                    }
                    print("❌ SignUpSheet: Registration failed - \(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "An unexpected error occurred"
                    print("❌ SignUpSheet: Unexpected error - \(error.localizedDescription)")
                }
            }
        }
    }
}

#Preview {
    SignUpSheet()
}

