import SwiftUI

struct AnimatedGradientBackground: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        // Beautiful static gradient with subtle color transitions
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: themeManager.currentTheme.primaryColor.opacity(0.95), location: 0.0),
                .init(color: themeManager.currentTheme.secondaryColor.opacity(0.85), location: 0.3),
                .init(color: themeManager.currentTheme.tertiaryColor.opacity(0.75), location: 0.6),
                .init(color: themeManager.currentTheme.primaryColor.opacity(0.8), location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(
            // Subtle texture overlay for depth
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.clear,
                            Color.black.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .ignoresSafeArea()
        )
    }
}

#Preview {
    AnimatedGradientBackground()
        .overlay(
            VStack {
                Text("StuCo")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Sample text over background")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding()
            }
        )
}