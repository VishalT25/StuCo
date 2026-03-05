import SwiftUI

struct PasswordResetView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var isPresented: Bool

    let accessToken: String

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showSuccess = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                themeManager.currentTheme.primaryColor,
                                                themeManager.currentTheme.primaryColor.opacity(0.7)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)

                                Image(systemName: "key.fill")
                                    .font(.system(size: 36, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            VStack(spacing: 8) {
                                Text("Reset Your Password")
                                    .font(.forma(.title, weight: .bold))
                                    .foregroundColor(.white)

                                Text("Create a new password for your account")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, 40)

                        // Form
                        VStack(spacing: 20) {
                            // New Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                        .frame(width: 24)

                                    Text("New Password")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.white)
                                }

                                SecureField("Enter new password", text: $newPassword)
                                    .font(.forma(.body))
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.white)
                            }

                            // Confirm Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 18))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                        .frame(width: 24)

                                    Text("Confirm Password")
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.white)
                                }

                                SecureField("Confirm new password", text: $confirmPassword)
                                    .font(.forma(.body))
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                                    .foregroundColor(.white)
                            }

                            // Password Requirements
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password must contain:")
                                    .font(.forma(.caption, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))

                                RequirementRow(
                                    text: "At least 8 characters",
                                    isMet: newPassword.count >= 8
                                )
                                RequirementRow(
                                    text: "Uppercase and lowercase letters",
                                    isMet: newPassword.contains(where: { $0.isUppercase }) &&
                                           newPassword.contains(where: { $0.isLowercase })
                                )
                                RequirementRow(
                                    text: "At least one number",
                                    isMet: newPassword.contains(where: { $0.isNumber })
                                )
                                RequirementRow(
                                    text: "Passwords match",
                                    isMet: !newPassword.isEmpty && !confirmPassword.isEmpty &&
                                           newPassword == confirmPassword
                                )
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                            )

                            // Error Message
                            if !errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                    Text(errorMessage)
                                        .font(.forma(.subheadline))
                                }
                                .foregroundColor(.red)
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.red.opacity(0.15))
                                )
                            }

                            // Reset Button
                            Button {
                                resetPassword()
                            } label: {
                                HStack(spacing: 12) {
                                    if isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Text("Reset Password")
                                            .font(.forma(.headline, weight: .bold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            isFormValid ?
                                            LinearGradient(
                                                colors: [
                                                    themeManager.currentTheme.primaryColor,
                                                    themeManager.currentTheme.primaryColor.opacity(0.8)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ) :
                                            LinearGradient(
                                                colors: [Color.gray.opacity(0.3)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                                .foregroundColor(.white)
                                .shadow(
                                    color: isFormValid ?
                                        themeManager.currentTheme.primaryColor.opacity(0.4) :
                                        Color.clear,
                                    radius: 15,
                                    x: 0,
                                    y: 8
                                )
                            }
                            .disabled(!isFormValid || isLoading)
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
            }
        }
        .alert("Password Reset Successful", isPresented: $showSuccess) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("Your password has been successfully reset. You can now sign in with your new password.")
        }
    }

    private var isFormValid: Bool {
        !newPassword.isEmpty &&
        !confirmPassword.isEmpty &&
        newPassword == confirmPassword &&
        newPassword.count >= 8 &&
        newPassword.contains(where: { $0.isUppercase }) &&
        newPassword.contains(where: { $0.isLowercase }) &&
        newPassword.contains(where: { $0.isNumber })
    }

    private func resetPassword() {
        guard isFormValid else {
            errorMessage = "Please meet all password requirements"
            return
        }

        isLoading = true
        errorMessage = ""

        Task {
            // Use the recovery token to reset password
            let result = await supabaseService.resetPasswordWithToken(
                accessToken: accessToken,
                newPassword: newPassword
            )

            await MainActor.run {
                isLoading = false

                switch result {
                case .success:
                    print("🎉 Password reset successful")
                    showSuccess = true

                case .failure(let error):
                    print("❌ Password reset failed: \(error)")
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct RequirementRow: View {
    let text: String
    let isMet: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundColor(isMet ? .green : .white.opacity(0.4))

            Text(text)
                .font(.forma(.caption))
                .foregroundColor(isMet ? .white : .white.opacity(0.6))
        }
    }
}

#Preview {
    PasswordResetView(
        isPresented: .constant(true),
        accessToken: "dummy_token"
    )
    .environmentObject(SupabaseService.shared)
    .environmentObject(ThemeManager())
}
