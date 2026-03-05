import SwiftUI

struct OnboardingSkipButton: View {
    let onSkip: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var showConfirmation = false

    var body: some View {
        Button {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            showConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Text("Skip")
                    .font(.forma(.subheadline, weight: .medium))

                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ScaleButtonStyle())
        .alert("Skip Tutorial?", isPresented: $showConfirmation) {
            Button("Continue Tutorial", role: .cancel) {}
            Button("Skip", role: .destructive) {
                onSkip()
            }
        } message: {
            Text("You can restart the tutorial anytime from Settings.")
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()

        VStack {
            HStack {
                Spacer()
                OnboardingSkipButton(onSkip: { print("Skipped") })
            }
            .padding()

            Spacer()
        }
    }
    .environmentObject(ThemeManager())
}
