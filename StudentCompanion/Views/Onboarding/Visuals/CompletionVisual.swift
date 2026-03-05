import SwiftUI

struct CompletionVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 24) {
            // Celebration checkmark
            ZStack {
                // Outer glow rings
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                theme.primaryColor.opacity(0.3),
                                theme.primaryColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)

                // Middle ring
                Circle()
                    .fill(theme.primaryColor.opacity(0.2))
                    .frame(width: 120, height: 120)

                // Inner circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primaryColor,
                                theme.primaryColor.opacity(0.8)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                // Checkmark
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
            }

            // Celebration sparkles
            HStack(spacing: 30) {
                sparkle(size: 20, offset: CGSize(width: -10, height: -20))
                sparkle(size: 16, offset: CGSize(width: 0, height: -30))
                sparkle(size: 24, offset: CGSize(width: 10, height: -15))
            }

            // Success message
            VStack(spacing: 12) {
                Text("All Set!")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)

                Text("You're ready to make the most of StuCo")
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }

    private func sparkle(size: CGFloat, offset: CGSize) -> some View {
        ZStack {
            // Vertical line
            RoundedRectangle(cornerRadius: size / 8)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.primaryColor,
                            theme.secondaryColor
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size / 6, height: size)

            // Horizontal line
            RoundedRectangle(cornerRadius: size / 8)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.primaryColor,
                            theme.secondaryColor
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size, height: size / 6)

            // Diagonal line 1
            RoundedRectangle(cornerRadius: size / 8)
                .fill(theme.primaryColor.opacity(0.8))
                .frame(width: size / 6, height: size * 0.7)
                .rotationEffect(.degrees(45))

            // Diagonal line 2
            RoundedRectangle(cornerRadius: size / 8)
                .fill(theme.primaryColor.opacity(0.8))
                .frame(width: size / 6, height: size * 0.7)
                .rotationEffect(.degrees(-45))
        }
        .offset(offset)
    }
}

#Preview {
    CompletionVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
