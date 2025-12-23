import SwiftUI

struct SignUpSheet: View {
    @Environment(\.dismiss) var dismiss
    
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
            // Black background
            Color.black
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // PROGRESS BAR
                    HStack(spacing: 4) {
                        ForEach(1...totalSteps, id: \.self) { index in
                            Capsule()
                                .fill(index <= step ? Color.white : Color.gray.opacity(0.3))
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
                                // Handle Final Sign Up Logic Here
                                print("Sign Up Complete")
                                dismiss()
                            }
                        }) {
                            Text(step == totalSteps ? "Finish" : "Next")
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .padding(.vertical, 12)
                                .padding(.horizontal, 32)
                                .background(Color.white)
                                .cornerRadius(30)
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
                .foregroundColor(.white)
            
            ZStack(alignment: .leading) {
                // Placeholder text (shown when field is empty)
                if email.isEmpty {
                    Text("example@email.com")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 16)
                }
                
                TextField("", text: $email)
                    .focused($focusedField, equals: .email)
                    .foregroundColor(.gray)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .tint(.white)
            }
            .padding()
            .background(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(12)
        }
    }
    
    // MARK: - STEP 2: PASSWORD (With Gradient Strength)
    var passwordStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Create a password")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            SecureField("", text: $password, prompt: Text("Password").foregroundColor(.gray))
                .focused($focusedField, equals: .password)
                .padding()
                .foregroundColor(.gray)
                .background(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(12)
                .tint(.white)
            
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
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - STEP 3: USERNAME
    var usernameStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Pick a username")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            TextField("", text: $username, prompt: Text("@username").foregroundColor(.gray))
                .focused($focusedField, equals: .username)
                .padding()
                .foregroundColor(.gray)
                .background(Color.black)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )
                .cornerRadius(12)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(.white)
        }
    }
    
    // MARK: - STEP 4: BIRTHDAY
    var birthdayStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("When is your birthday?")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            DatePicker("", selection: $birthDate, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .colorScheme(.dark)
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
                .foregroundColor(.white)
            
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
                            .background(genderSelection == gender ? Color.white : Color.black)
                            .foregroundColor(genderSelection == gender ? .black : .white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
            }
            
            // Custom Input Field (Shows only if "Custom" is picked)
            if genderSelection == "Custom" {
                TextField("", text: $customGender, prompt: Text("Type your gender").foregroundColor(.gray))
                    .focused($focusedField, equals: .customGender)
                    .padding()
                    .foregroundColor(.gray)
                    .background(Color.black)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    )
                    .cornerRadius(12)
                    .tint(.white)
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
}

#Preview {
    SignUpSheet()
}

