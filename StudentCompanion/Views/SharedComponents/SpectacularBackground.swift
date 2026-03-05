import SwiftUI

// MARK: - Spectacular Background Component
struct SpectacularBackground: View {
    let themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Base gradient with theme colors
            LinearGradient(
                colors: colorScheme == .dark ? [
                    Color.black,
                    Color(red: 0.02, green: 0.02, blue: 0.05),
                    Color(red: 0.04, green: 0.04, blue: 0.08),
                    themeManager.currentTheme.darkModeBackgroundFill.opacity(0.3)
                ] : [
                    Color(.systemGroupedBackground),
                    themeManager.currentTheme.quaternaryColor.opacity(0.3),
                    themeManager.currentTheme.tertiaryColor.opacity(0.2),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated mesh gradients
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.1 : 0.15),
                                themeManager.currentTheme.secondaryColor.opacity(colorScheme == .dark ? 0.05 : 0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200
                        )
                    )
                    .frame(width: 400, height: 400)
                    .offset(
                        x: CGFloat(index * 150 - 300) + sin(animationOffset * 0.001 + Double(index)) * 50,
                        y: CGFloat(index * 200 - 100) + cos(animationOffset * 0.0008 + Double(index * 2)) * 30
                    )
                    .blur(radius: 30)
            }
            
            // Subtle noise texture
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.01 : 0.03),
                            Color.clear,
                            Color.black.opacity(colorScheme == .dark ? 0.02 : 0.01)
                        ],
                        startPoint: UnitPoint(x: animationOffset * 0.0005, y: 0),
                        endPoint: UnitPoint(x: 1 + animationOffset * 0.0005, y: 1)
                    )
                )
        }
        .ignoresSafeArea()
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
}

// MARK: - View Extension for Easy Background Application
extension View {
    func spectacularBackground(themeManager: ThemeManager) -> some View {
        ZStack {
            SpectacularBackground(themeManager: themeManager)
            self
        }
    }
}

// MARK: - Preview
#Preview {
    SpectacularBackground(themeManager: ThemeManager())
        .overlay(
            VStack {
                Text("Sample Content")
                    .font(.title)
                    .foregroundColor(.primary)
                
                Text("This is how content looks over the spectacular background")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        )
}