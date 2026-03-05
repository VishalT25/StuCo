import SwiftUI
import UIKit
import AuthenticationServices

struct SignInOptionsScreen: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var socialAuthManager = SocialAuthManager()

    @State private var showLogo = false
    @State private var showHeadlines = false
    @State private var showCard = false
    @State private var showGoogleButton = false
    @State private var showEmailButton = false
    @State private var showAppleButton = false
    @State private var showEmailAuth = false
    @Binding var selectedDetent: PresentationDetent

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            // Solid dark background (matches MainContentView)
            signInGradientBackground
                .ignoresSafeArea()

            if showEmailAuth {
                // Show email auth screen
                EmailAuthScreen(onBack: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showEmailAuth = false
                        selectedDetent = .medium
                    }
                })
                .environmentObject(themeManager)
                .environmentObject(supabaseService)
            } else {
                // Show sign-in options
                VStack(spacing: 28) {
                    // Drag indicator area
                    Color.clear
                        .frame(height: 8)

                    // Headlines
                    headlinesSection
                        .padding(.horizontal, 32)
                        .padding(.top, 12)

                    // Auth options card
                    authOptionsCard
                        .padding(.horizontal, 24)

                    // Terms text
                    termsSection
                        .padding(.horizontal, 32)
                        .padding(.bottom, 20)
                }
            }

            // Loading overlay
            if socialAuthManager.isLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .alert("Authentication Error", isPresented: .constant(socialAuthManager.errorMessage != nil)) {
            Button("OK") {
                socialAuthManager.errorMessage = nil
            }
        } message: {
            if let error = socialAuthManager.errorMessage {
                Text(error)
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Background (matches MainContentView)

    private var signInGradientBackground: some View {
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
            // Logo and title
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.forma(.title2, weight: .medium))

                Text("StuCo")
                    .font(.forma(.title, weight: .bold))
            }
            .foregroundStyle(
                LinearGradient(
                    colors: [.white, .white.opacity(0.95)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(showLogo ? 1 : 0)
            .scaleEffect(showLogo ? 1.0 : 0.8)

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .opacity(showLogo ? 1 : 0)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Headlines Section

    private var headlinesSection: some View {
        VStack(spacing: 14) {
            Text("One tap to continue")
                .font(.forma(.title, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)

            Text("Choose your sign in method")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
        .opacity(showHeadlines ? 1 : 0)
        .offset(y: showHeadlines ? 0 : 10)
    }

    // MARK: - Auth Options Card

    private var authOptionsCard: some View {
        VStack(spacing: 16) {
            // Google button (full width)
            googleButton

            // Email and Apple buttons (side by side)
            HStack(spacing: 12) {
                emailButton
                appleButton
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
        .opacity(showCard ? 1 : 0)
        .offset(y: showCard ? 0 : 40)
    }

    // MARK: - Auth Buttons

    private var googleButton: some View {
        Button {
            handleGoogleSignIn()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "globe")
                    .font(.forma(.title3, weight: .medium))
                    .foregroundColor(.white)

                Text("Continue with Google")
                    .font(.forma(.body, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(AuthButtonStyle())
        .opacity(showGoogleButton ? 1 : 0)
        .scaleEffect(showGoogleButton ? 1.0 : 0.9)
    }

    private var emailButton: some View {
        Button {
            handleEmailSignIn()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)

                Text("Email")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(AuthButtonStyle())
        .opacity(showEmailButton ? 1 : 0)
        .scaleEffect(showEmailButton ? 1.0 : 0.9)
    }

    private var appleButton: some View {
        Button {
            handleAppleSignIn()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)

                Text("Apple")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.white.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
        .buttonStyle(AuthButtonStyle())
        .opacity(showAppleButton ? 1 : 0)
        .scaleEffect(showAppleButton ? 1.0 : 0.9)
    }

    // MARK: - Terms Section

    private var termsSection: some View {
        Text("By creating a new account, you agree to our [Terms & Conditions](https://www.stuco.app/terms) and [Privacy Policy](https://www.stuco.app/privacy).")
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.65))
            .multilineTextAlignment(.center)
            .lineSpacing(3)
    }

    // MARK: - Animation Methods

    private func startAnimations() {
        // Logo animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showLogo = true
        }

        // Headlines animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
            showHeadlines = true
        }

        // Card animation
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) {
            showCard = true
        }

        // Staggered button animations
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5)) {
            showGoogleButton = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.6)) {
            showEmailButton = true
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.7)) {
            showAppleButton = true
        }
    }

    // MARK: - Action Handlers

    private func handleGoogleSignIn() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        guard let topVC = UIApplication.getTopViewController() else {
            socialAuthManager.errorMessage = "Unable to present sign in"
            return
        }

        Task {
            let result = await socialAuthManager.signInWithGoogle(presentingViewController: topVC)
            switch result {
            case .success:
                // Authentication successful, will be handled by auth listener
                break
            case .failure(let error):
                print("❌ Google Sign In error: \(error)")
            }
        }
    }

    private func handleEmailSignIn() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Expand bottom sheet to full screen and show email auth
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            selectedDetent = .large
            showEmailAuth = true
        }
    }

    private func handleAppleSignIn() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        Task {
            let result = await socialAuthManager.signInWithApple()
            switch result {
            case .success:
                // Authentication successful, will be handled by auth listener
                break
            case .failure(let error):
                print("❌ Apple Sign In error: \(error)")
            }
        }
    }
}

// MARK: - Auth Button Style

struct AuthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - UIApplication Extension

extension UIApplication {
    static func getTopViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let rootVC = window.rootViewController else {
            return nil
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        return topVC
    }
}

// MARK: - Wrapper for Detent Management

struct SignInOptionsScreenWrapper: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        SignInOptionsScreen(selectedDetent: $selectedDetent)
            .environmentObject(themeManager)
            .environmentObject(supabaseService)
            .presentationDetents([.medium, .large], selection: $selectedDetent)
            .presentationDragIndicator(.visible)
    }
}

// MARK: - Previews

#Preview {
    @Previewable @State var detent: PresentationDetent = .medium
    return SignInOptionsScreen(selectedDetent: $detent)
        .environmentObject(ThemeManager())
        .environmentObject(SupabaseService.shared)
}
