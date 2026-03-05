import SwiftUI

struct AuthenticationSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var forgotPasswordMessage = ""
    @State private var showingForgotPasswordAlert = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 72, height: 72)
                            Image(systemName: "icloud")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Text(isSignUp ? "Create Account" : "Welcome Back")
                            .font(.forma(.title2, weight: .bold))
                        Text(isSignUp ? "Join StuCo to sync your data across devices" : "Sign in to access your synced data")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(spacing: 16) {
                        CustomTextField(
                            title: "Email",
                            placeholder: "Enter your email",
                            text: $email,
                            icon: "envelope"
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                        CustomSecureField(
                            title: "Password",
                            placeholder: "Enter your password",
                            text: $password,
                            icon: "lock"
                        )
                        
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.forma(.footnote))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button {
                            if isSignUp { signUp() } else { signIn() }
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView().tint(.white)
                                }
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .font(.forma(.headline))
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        
                        Button {
                            isSignUp.toggle()
                            errorMessage = ""
                        } label: {
                            HStack {
                                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                                    .foregroundColor(.secondary)
                                Text(isSignUp ? "Sign In" : "Sign Up")
                                    .fontWeight(.semibold)
                            }
                            .font(.forma(.subheadline))
                        }

                        if !isSignUp {
                            Button {
                                showingForgotPassword = true
                            } label: {
                                Text("Forgot Password?")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.forma(.body))
                }
            }
            .alert("Reset Password", isPresented: $showingForgotPassword) {
                TextField("Email", text: $forgotPasswordEmail)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                Button("Send Reset Link") {
                    sendPasswordReset()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Enter your email address and we'll send you a link to reset your password.")
            }
            .alert("Password Reset", isPresented: $showingForgotPasswordAlert) {
                Button("OK") { }
            } message: {
                Text(forgotPasswordMessage)
            }
        }
    }

    func sendPasswordReset() {
        Task {
            let result = await supabaseService.resetPassword(email: forgotPasswordEmail)
            await MainActor.run {
                switch result {
                case .success:
                    forgotPasswordMessage = "Password reset link sent! Check your email."
                case .failure(let error):
                    forgotPasswordMessage = error.localizedDescription
                }
                showingForgotPasswordAlert = true
                forgotPasswordEmail = ""
            }
        }
    }

    func signIn() {
        isLoading = true
        errorMessage = ""
        Task {
            let result = await supabaseService.signIn(email: email, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success: dismiss()
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    func signUp() {
        isLoading = true
        errorMessage = ""
        Task {
            let result = await supabaseService.signUp(email: email, password: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success: dismiss()
                case .failure(let error): errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct CustomSecureField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    @EnvironmentObject var themeManager: ThemeManager
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 24)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            SecureField(placeholder, text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
        }
    }
}
