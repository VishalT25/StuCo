import SwiftUI
import UIKit

struct EmailAuthScreen: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var onBack: (() -> Void)? = nil

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false

    // Flow control
    @State private var showEmailVerification = false
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""
    @State private var showPasswordResetSuccess = false

    // Animation states
    @State private var showHeader = false
    @State private var showCard = false
    @State private var showFormContent = false

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            // Cool gradient background matching SignInOptionsScreen
            emailGradientBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header with back button
                    headerSection
                        .padding(.top, 60)

                    // Content card
                    if showEmailVerification {
                        emailVerificationCard
                    } else if showForgotPassword {
                        forgotPasswordCard
                    } else {
                        emailAuthCard
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            // Error Toast
            if showError {
                errorToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            // Success Toast
            if showPasswordResetSuccess {
                successToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            // Loading overlay
            if isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Background (matches MainContentView)

    private var emailGradientBackground: some View {
        // Same background as home screen
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.05, green: 0.05, blue: 0.08)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            // Back button
            Button {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                if let onBack = onBack {
                    onBack()
                } else {
                    dismiss()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                }
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                )
            }

            Spacer()

            // Logo
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .medium, design: .rounded))

                Text("StuCo")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .opacity(showHeader ? 1 : 0)
        .offset(y: showHeader ? 0 : -10)
    }

    // MARK: - Email Auth Card

    private var emailAuthCard: some View {
        VStack(spacing: 24) {
            // Headlines
            VStack(spacing: 12) {
                Text(isSignUp ? "Create Account" : "Sign In")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(isSignUp ? "Join the StuCo community" : "Welcome back, scholar")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            // Toggle tabs
            authToggleTabs

            // Form fields
            VStack(spacing: 16) {
                // Email field
                FloatingTextField(
                    title: "Email Address",
                    placeholder: "Enter your email",
                    text: $email,
                    keyboardType: .emailAddress,
                    autocapitalization: .never,
                    showValidation: isSignUp
                )
                .disabled(isLoading)

                // Password field
                FloatingTextField(
                    title: "Password",
                    placeholder: isSignUp ? "Create a secure password" : "Enter your password",
                    text: $password,
                    isSecure: true,
                    showValidation: isSignUp
                )
                .disabled(isLoading)

                // Confirm password (sign up only)
                if isSignUp {
                    FloatingTextField(
                        title: "Confirm Password",
                        placeholder: "Confirm your password",
                        text: $confirmPassword,
                        isSecure: true,
                        showValidation: false
                    )
                    .disabled(isLoading)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }

                // Password requirements (sign up only)
                if isSignUp {
                    passwordRequirements
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .opacity(showFormContent ? 1 : 0)
            .offset(y: showFormContent ? 0 : 10)

            // Action buttons
            VStack(spacing: 12) {
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

                // Forgot password button (sign in only)
                if !isSignUp {
                    Button("Forgot Password?") {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showForgotPassword = true
                            forgotPasswordEmail = email
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .disabled(isLoading)
                }
            }

            // Feature icons
            featureIcons
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(0.3),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
        .opacity(showCard ? 1 : 0)
        .offset(y: showCard ? 0 : 40)
    }

    // MARK: - Auth Toggle Tabs

    private var authToggleTabs: some View {
        HStack(spacing: 12) {
            // Sign In Tab
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isSignUp = false
                    clearForm()
                }
            } label: {
                Text("Sign In")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(!isSignUp ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(!isSignUp ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
            .disabled(isLoading)

            // Sign Up Tab
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isSignUp = true
                    clearForm()
                }
            } label: {
                Text("Sign Up")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(isSignUp ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSignUp ? Color.white.opacity(0.2) : Color.clear)
                    )
            }
            .disabled(isLoading)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.1))
        )
    }

    // MARK: - Password Requirements

    private var passwordRequirements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Password Requirements")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 8) {
                EmailRequirementRow(text: "8+ characters", isValid: password.count >= 8)
                EmailRequirementRow(text: "Uppercase letter", isValid: password.contains { $0.isUppercase })
                EmailRequirementRow(text: "Lowercase letter", isValid: password.contains { $0.isLowercase })
                EmailRequirementRow(text: "Number", isValid: password.contains { $0.isNumber })
            }

            // Password match indicator
            if !confirmPassword.isEmpty {
                EmailRequirementRow(text: "Passwords match", isValid: password == confirmPassword)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
    }

    // MARK: - Feature Icons

    private var featureIcons: some View {
        HStack(spacing: 0) {
            EmailFeatureIcon(icon: "icloud.and.arrow.up.fill", text: "Cloud Sync")
                .frame(maxWidth: .infinity)
            EmailFeatureIcon(icon: "shield.lefthalf.filled", text: "Secure")
                .frame(maxWidth: .infinity)
            EmailFeatureIcon(icon: "sparkles", text: "AI Powered")
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Email Verification Card

    private var emailVerificationCard: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "envelope.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            // Text content
            VStack(spacing: 12) {
                Text("Check Your Email")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("We've sent a verification link to\n\(email)")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text("Please check your email and click the verification link to activate your account. Once verified, you can sign in.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.top, 8)
            }

            // Back button
            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    showEmailVerification = false
                    clearForm()
                }
            } label: {
                Text("Back to Sign In")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.15))
                    )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(0.3),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
    }

    // MARK: - Forgot Password Card

    private var forgotPasswordCard: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "key.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
            }

            // Text content
            VStack(spacing: 12) {
                Text("Reset Password")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Email field
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

                Button {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showForgotPassword = false
                        forgotPasswordEmail = ""
                    }
                } label: {
                    Text("Back to Sign In")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.1))
                        )
                }
                .disabled(isLoading)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 32)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.6),
                                    Color.black.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: .black.opacity(0.3),
                    radius: 20,
                    x: 0,
                    y: 10
                )
        )
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
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text(errorMessage)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button("Dismiss") {
                    withAnimation {
                        showError = false
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
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
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Check your inbox for reset instructions")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                Button("Dismiss") {
                    withAnimation {
                        showPasswordResetSuccess = false
                    }
                }
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 50)

            Spacer()
        }
    }

    // MARK: - Animations

    private func startAnimations() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showHeader = true
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.2)) {
            showCard = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
            showFormContent = true
        }
    }

    // MARK: - Validation

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

struct EmailRequirementRow: View {
    let text: String
    let isValid: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isValid ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isValid ? .green : .white.opacity(0.5))
                .font(.caption)
                .frame(width: 12, height: 12)

            Text(text)
                .font(.system(size: 11, design: .rounded))
                .foregroundColor(isValid ? .white : .white.opacity(0.7))

            Spacer()
        }
        .animation(.easeInOut(duration: 0.2), value: isValid)
    }
}

struct EmailFeatureIcon: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.9))
                .frame(height: 22)

            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    NavigationStack {
        EmailAuthScreen()
            .environmentObject(SupabaseService.shared)
            .environmentObject(ThemeManager())
    }
}
