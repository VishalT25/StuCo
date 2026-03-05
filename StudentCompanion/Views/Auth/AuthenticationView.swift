import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @StateObject private var themeManager = ThemeManager()
    
    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    // New states for better flow control
    @State private var showEmailVerification = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var showPasswordResetSuccess = false
    
    // Animation states
    @State private var showWelcome = false
    @State private var showForm = false
    @State private var logoScale: CGFloat = 0.5
    @State private var logoRotation: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Static beautiful gradient background
                AnimatedGradientBackground()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header Section with more height to prevent title cutoff
                        headerSection
                            .frame(height: geometry.size.height * 0.45) // Increased from 0.4 to 0.45
                        
                        // Main Content Card with minimal overlap
                        if showEmailVerification {
                            emailVerificationCard
                                .padding(.top, -15)
                        } else if showForgotPassword {
                            forgotPasswordCard
                                .padding(.top, -15)
                        } else {
                            mainContentCard
                                .padding(.top, -15) // Reduced overlap from -25 to -15
                        }
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
                
                // Error Toast
                if showError {
                    errorToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
                
                // Success Toast for Password Reset
                if showPasswordResetSuccess {
                    successToast
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
        }
        .onAppear {
            startIntroAnimation()
        }
        .animation(.easeInOut(duration: 0.3), value: showError)
        .animation(.easeInOut(duration: 0.3), value: showPasswordResetSuccess)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Push logo down but leave more space for title
                Color.clear
                    .frame(height: geometry.size.height * 0.35) // Reduced from 0.45 to 0.35
                
                // App Logo with animation - positioned absolutely
                ZStack {
                    // Subtle glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 20,
                                endRadius: 50
                            )
                        )
                        .frame(width: 80, height: 80)
                        .blur(radius: 4)
                        .opacity(showWelcome ? 1 : 0)
                    
                    // Main logo
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(logoScale)
                        .rotationEffect(.degrees(logoRotation))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .padding(.bottom, 20) // Further reduced spacing
                
                // Welcome Text with subtle shadow - ensure it has enough space
                VStack(spacing: 6) {
                    Text("StuCo")
                        .font(.forma(.largeTitle, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.95)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 1, x: 0, y: 1) // Reduced shadow
                    
                    Text(getHeaderSubtitle())
                        .font(.forma(.title3, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1) // Reduced shadow
                }
                .opacity(showWelcome ? 1 : 0)
                .offset(y: showWelcome ? 0 : 15)
                .padding(.bottom, 30) // Add explicit bottom padding for title
                
                Spacer() // This ensures text doesn't get cut off
            }
        }
    }
    
    // MARK: - Email Verification Card
    
    private var emailVerificationCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                // Title and message
                VStack(spacing: 12) {
                    Text("Check Your Email")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("We've sent a verification link to\n\(email)")
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
                
                // Instructions
                VStack(spacing: 16) {
                    Text("Please check your email and click the verification link to activate your account. Once verified, you can sign in.")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .padding(.horizontal, 4)
                    
                    // Action button - only back to sign in
                    Button("Back to Sign In") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showEmailVerification = false
                            clearForm()
                        }
                    }
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 20)
            .opacity(showForm ? 1 : 0)
            .offset(y: showForm ? 0 : 30)
            
            // Bottom spacing for safe area
            Color.clear.frame(height: 50)
        }
    }
    
    // MARK: - Forgot Password Card
    
    private var forgotPasswordCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "key.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                // Title and message
                VStack(spacing: 12) {
                    Text("Reset Password")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Enter your email address and we'll send you a link to reset your password.")
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 4)
                }
                
                // Email input
                FloatingTextField(
                    title: "Email Address",
                    placeholder: "Enter your email",
                    text: $forgotPasswordEmail,
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    showValidation: true
                )
                .disabled(isLoading)
                
                // Action buttons
                VStack(spacing: 12) {
                    AnimatedButton(
                        title: "Send Reset Link",
                        subtitle: "Check your email",
                        icon: "paperplane.fill",
                        isPrimary: true,
                        isLoading: isLoading,
                        isDisabled: forgotPasswordEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !isValidEmail(forgotPasswordEmail)
                    ) {
                        resetPassword()
                    }
                    
                    Button("Back to Sign In") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showForgotPassword = false
                            forgotPasswordEmail = ""
                        }
                    }
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 20)
            .opacity(showForm ? 1 : 0)
            .offset(y: showForm ? 0 : 30)
            
            // Bottom spacing for safe area
            Color.clear.frame(height: 50)
        }
    }
    
    // MARK: - Main Content Card
    
    private var mainContentCard: some View {
        VStack(spacing: 0) {
            // Card with glassmorphism
            VStack(spacing: 0) {
                // Toggle Tabs
                authToggleTabs
                    .padding(.bottom, 24)
                
                // Form Section
                authForm
                    .padding(.bottom, 24)
                
                // Action Buttons
                actionButtons
                    .padding(.bottom, 20)
                
                // Additional Info
                additionalInfo
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.8
                            )
                    )
                    .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
            )
            .padding(.horizontal, 20)
            .opacity(showForm ? 1 : 0)
            .offset(y: showForm ? 0 : 30)
            
            // Bottom spacing for safe area
            Color.clear.frame(height: 50)
        }
    }
    
    // MARK: - Auth Toggle Tabs
    
    private var authToggleTabs: some View {
        HStack(spacing: 0) {
            // Sign In Tab
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isSignUp = false
                    clearForm()
                }
            }) {
                VStack(spacing: 8) {
                    Text("Sign In")
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(!isSignUp ? themeManager.currentTheme.primaryColor : .secondary)
                    
                    Rectangle()
                        .fill(themeManager.currentTheme.primaryColor)
                        .frame(height: 2.5)
                        .opacity(!isSignUp ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSignUp)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isLoading)
            
            // Sign Up Tab
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isSignUp = true
                    clearForm()
                }
            }) {
                VStack(spacing: 8) {
                    Text("Sign Up")
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(isSignUp ? themeManager.currentTheme.primaryColor : .secondary)
                    
                    Rectangle()
                        .fill(themeManager.currentTheme.primaryColor)
                        .frame(height: 2.5)
                        .opacity(isSignUp ? 1 : 0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSignUp)
                }
                .frame(maxWidth: .infinity)
            }
            .disabled(isLoading)
        }
    }
    
    // MARK: - Auth Form
    
    private var authForm: some View {
        VStack(spacing: 16) {
            // Email Field
            FloatingTextField(
                title: "Email Address",
                placeholder: "Enter your email",
                text: $email,
                keyboardType: .emailAddress,
                autocapitalization: .never,
                showValidation: isSignUp // Only show validation for sign up
            )
            .disabled(isLoading)
            
            // Password Field
            FloatingTextField(
                title: "Password",
                placeholder: isSignUp ? "Create a secure password" : "Enter your password",
                text: $password,
                isSecure: true,
                showValidation: isSignUp // Only show validation for sign up
            )
            .disabled(isLoading)
            
            // Confirm Password Field (Sign Up only)
            if isSignUp {
                FloatingTextField(
                    title: "Confirm Password",
                    placeholder: "Confirm your password",
                    text: $confirmPassword,
                    isSecure: true,
                    showValidation: false // Don't show individual validation, we check matching instead
                )
                .disabled(isLoading)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
            
            // Password Requirements (Sign Up only)
            if isSignUp {
                passwordRequirements
                    .padding(.top, 4)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
    }
    
    // MARK: - Password Requirements
    
    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Password Requirements")
                .font(.forma(.caption, weight: .semibold))
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 8) {
                AuthRequirementRow(text: "8+ characters", isValid: password.count >= 8)
                AuthRequirementRow(text: "Uppercase letter", isValid: password.contains { $0.isUppercase })
                AuthRequirementRow(text: "Lowercase letter", isValid: password.contains { $0.isLowercase })
                AuthRequirementRow(text: "Number", isValid: password.contains { $0.isNumber })
            }

            // Password match indicator
            if !confirmPassword.isEmpty {
                HStack(spacing: 8) {
                    AuthRequirementRow(text: "Passwords match", isValid: password == confirmPassword)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.4))
                .background(.ultraThinMaterial)
        )
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 14) {
            // Primary Action Button
            AnimatedButton(
                title: isSignUp ? "Create Account" : "Sign In",
                subtitle: isSignUp ? "Join now" : "Access your dashboard",
                icon: isSignUp ? "person.badge.plus" : "person.fill.checkmark",
                isPrimary: true,
                isLoading: isLoading,
                isDisabled: !isFormValid
            ) {
                primaryAction()
            }
            
            // Alternative Actions
            if !isSignUp {
                Button("Forgot Password?") {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showForgotPassword = true
                        forgotPasswordEmail = email // Pre-fill if user has entered email
                    }
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .disabled(isLoading)
                .padding(.top, 2)
            }
        }
    }
    
    // MARK: - Additional Info
    
    private var additionalInfo: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                FeatureIcon(icon: "icloud.and.arrow.up.fill", text: "Cloud Sync")
                    .frame(maxWidth: .infinity)
                FeatureIcon(icon: "shield.lefthalf.filled", text: "Secure")
                    .frame(maxWidth: .infinity)
                FeatureIcon(icon: "sparkles", text: "AI Powered")
                    .frame(maxWidth: .infinity)
            }
            
            Text(isSignUp ? 
                "By creating an account, you agree to sync your academic data across devices securely." :
                "Your data is encrypted and synced across all your devices in real-time."
            )
            .font(.forma(.caption2))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 4)
            .lineSpacing(1)
        }
    }
    
    // MARK: - Error Toast
    
    private var errorToast: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Authentication Error")
                        .font(.forma(.subheadline, weight: .semibold))
                    Text(errorMessage)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation {
                        showError = false
                    }
                }
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Success Toast
    
    private var successToast: some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email Sent!")
                        .font(.forma(.subheadline, weight: .semibold))
                    Text("Check your inbox for reset instructions")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Dismiss") {
                    withAnimation {
                        showPasswordResetSuccess = false
                    }
                }
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 50)
            
            Spacer()
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        let emailValid = !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let passwordValid = !password.isEmpty
        
        if isSignUp {
            let emailFormatValid = isValidEmail(email)
            let passwordStrong = isStrongPassword(password)
            let confirmValid = password == confirmPassword && !confirmPassword.isEmpty
            return emailFormatValid && passwordStrong && confirmValid
        } else {
            return emailValid && passwordValid
        }
    }
    
    // MARK: - Helper Methods
    
    private func getHeaderSubtitle() -> String {
        if showEmailVerification {
            return "Verify your email"
        } else if showForgotPassword {
            return "Reset your password"
        } else {
            return isSignUp ? "Join the community" : "Welcome back, scholar"
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isStrongPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        
        let hasUppercase = password.contains { $0.isUppercase }
        let hasLowercase = password.contains { $0.isLowercase }
        let hasNumbers = password.contains { $0.isNumber }
        
        return hasUppercase && hasLowercase && hasNumbers
    }
    
    private func startIntroAnimation() {
        // Logo animation
        withAnimation(.spring(response: 0.7, dampingFraction: 0.6).delay(0.2)) {
            logoScale = 1.0
        }
        
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(1.0)) {
            logoRotation = 3
        }
        
        // Welcome text animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
            showWelcome = true
        }
        
        // Form animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8)) {
            showForm = true
        }
    }
    
    // MARK: - Actions
    
    private func primaryAction() {
        if isSignUp {
            signUp()
        } else {
            signIn()
        }
    }
    
    private func signUp() {
        guard password == confirmPassword else {
            showErrorMessage("Passwords do not match")
            return
        }
        
        isLoading = true
        Task {
            let result = await supabaseService.signUp(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            
            await MainActor.run {
                switch result {
                case .success(let signUpResult):
                    switch signUpResult {
                    case .confirmedImmediately:
                        break
                    case .needsEmailConfirmation:
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showEmailVerification = true
                        }
                    }
                case .failure(let error):
                    if case .emailAlreadyExists = error {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            isSignUp = false
                        }
                    }
                    showErrorMessage(error.localizedDescription)
                }
                isLoading = false
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        Task {
            let result = await supabaseService.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            
            await MainActor.run {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    if case .emailNotConfirmed = error {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showEmailVerification = true
                        }
                    }
                    showErrorMessage(error.localizedDescription)
                }
                isLoading = false
            }
        }
    }
    
    private func resetPassword() {
        isLoading = true
        Task {
            let result = await supabaseService.resetPassword(
                email: forgotPasswordEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            await MainActor.run {
                switch result {
                case .success:
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showPasswordResetSuccess = true
                        showForgotPassword = false
                        forgotPasswordEmail = ""
                    }
                    
                    // Auto dismiss success message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            showPasswordResetSuccess = false
                        }
                    }
                case .failure(let error):
                    showErrorMessage(error.localizedDescription)
                }
                isLoading = false
            }
        }
    }
    
    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        errorMessage = ""
        showError = false
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showError = true
        }
        
        // Auto dismiss after 4 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showError = false
            }
        }
    }
}

// MARK: - Supporting Views

private struct AuthRequirementRow: View {
    let text: String
    let isValid: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .gray)
                .font(.caption)
                .frame(width: 12, height: 12)

            Text(text)
                .font(.forma(.caption2))
                .foregroundColor(isValid ? .primary : .secondary)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }
}

struct FeatureIcon: View {
    let icon: String
    let text: String
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(height: 22)
            
            Text(text)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(SupabaseService.shared)
}
