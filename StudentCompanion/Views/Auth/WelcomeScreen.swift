import SwiftUI
import UIKit

struct WelcomeScreen: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @Environment(\.colorScheme) private var colorScheme

    @State private var showLogo = false
    @State private var showHeadline = false
    @State private var showSwipeIndicator = false
    @State private var showSignInOptions = false
    @State private var dragOffset: CGFloat = 0

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        ZStack {
            // Elegant dark background
            improvedGradientBackground
                .ignoresSafeArea()

            // Subtle decorative elements
            decorativeElements
                .opacity(showLogo ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 140)

                // Main content
                VStack(spacing: 40) {
                    // Logo mark
                    logoMark
                        .opacity(showLogo ? 1 : 0)
                        .scaleEffect(showLogo ? 1.0 : 0.9)

                    // Headline (no animation)
                    headlineSection
                        .padding(.horizontal, 40)
                }

                Spacer()

                // Swipe indicator
                swipeIndicator
                    .padding(.bottom, 80)
            }
            .offset(y: dragOffset)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow upward swipes
                    if value.translation.height < 0 {
                        dragOffset = value.translation.height * 0.5
                    }
                }
                .onEnded { value in
                    if value.translation.height < -100 {
                        // Swipe threshold met - show sign in options
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                        showSignInOptions = true
                    } else {
                        // Snap back
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .sheet(isPresented: $showSignInOptions) {
            SignInOptionsScreenWrapper()
                .environmentObject(themeManager)
                .environmentObject(supabaseService)
                .presentationCornerRadius(32)
                .presentationBackgroundInteraction(.enabled)
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Background

    private var improvedGradientBackground: some View {
        ZStack {
            // Deep, rich dark base
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.10),
                    Color(red: 0.04, green: 0.06, blue: 0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle accent glow
            RadialGradient(
                colors: [
                    currentTheme.primaryColor.opacity(0.08),
                    Color.clear
                ],
                center: .top,
                startRadius: 200,
                endRadius: 700
            )
        }
    }

    // MARK: - Logo Mark

    private var logoMark: some View {
        ZStack {
            // Subtle glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            currentTheme.primaryColor.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 80
                    )
                )
                .frame(width: 130, height: 130)

            // Icon
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            currentTheme.primaryColor,
                            currentTheme.primaryColor.opacity(0.8)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - Headline Section

    private var headlineSection: some View {
        VStack(spacing: 20) {
            // App name
            Text("StuCo")
                .font(.forma(.largeTitle, weight: .black))
                .foregroundColor(.white)
                .tracking(2)

            // Main headline
            VStack(spacing: 8) {
                Text("Your academic life,")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundColor(.white.opacity(0.95))

                Text("finally organized")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundColor(currentTheme.primaryColor)
            }
            .multilineTextAlignment(.center)
        }
    }

    // MARK: - Swipe Indicator

    private var swipeIndicator: some View {
        VStack(spacing: 20) {
            // Static chevrons
            VStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Image(systemName: "chevron.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }

            // Swipe text with subtle background
            Text("Swipe up to continue")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                )
        }
        .opacity(showSwipeIndicator ? 1 : 0)
    }

    // MARK: - Decorative Elements

    private var decorativeElements: some View {
        ZStack {
            // Top accent circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            currentTheme.primaryColor.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: -120, y: -300)
                .blur(radius: 40)

            // Bottom accent circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            currentTheme.secondaryColor.opacity(0.08),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 250, height: 250)
                .offset(x: 130, y: 320)
                .blur(radius: 50)
        }
    }

    // MARK: - Animation Methods

    private func startAnimations() {
        // Logo mark fade in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) {
            showLogo = true
        }

        // Swipe indicator fade in
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.3)) {
            showSwipeIndicator = true
        }
    }
}

// MARK: - Previews

#Preview {
    WelcomeScreen()
        .environmentObject(ThemeManager())
}
