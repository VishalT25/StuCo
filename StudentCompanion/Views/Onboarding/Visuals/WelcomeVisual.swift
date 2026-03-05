import SwiftUI

struct WelcomeVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Actual app screenshot
            Image("OnboardingHomeScreen")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 280)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.primaryColor.opacity(0.3),
                                    theme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            Text("Your all-in-one academic companion")
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }
}

#Preview {
    WelcomeVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
}
