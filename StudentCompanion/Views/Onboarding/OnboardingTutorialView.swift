import SwiftUI

struct OnboardingTutorialView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentPage: Int = 0

    private let pages = TutorialPage.allPages
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        ZStack {
            // Background with texture
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    themeManager.currentTheme.primaryColor.opacity(0.05),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with skip button and progress
                header

                // TabView with pages
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        TutorialPageView(page: page)
                            .environmentObject(themeManager)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _ in
                    haptic.impactOccurred()
                }

                // Get Started button (only on final page)
                if currentPage == pages.count - 1 {
                    getStartedButton
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Spacer()

            // Progress indicators (centered)
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? themeManager.currentTheme.primaryColor : Color.white.opacity(0.3))
                        .frame(width: index == currentPage ? 12 : 8, height: index == currentPage ? 12 : 8)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }

            Spacer()

            // X button (top right)
            Button {
                dismissTutorial()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var getStartedButton: some View {
        Button {
            completeTutorial()
        } label: {
            Text("Get Started")
                .font(.forma(.headline, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.primaryColor.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }

    private func dismissTutorial() {
        let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
        mediumHaptic.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }
    }

    private func completeTutorial() {
        let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
        mediumHaptic.impactOccurred()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

#Preview {
    OnboardingTutorialView(isPresented: .constant(true))
        .environmentObject(ThemeManager())
}
