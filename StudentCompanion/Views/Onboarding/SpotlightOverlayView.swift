import SwiftUI

struct SpotlightOverlayView: View {
    let targetFrame: CGRect
    let cornerRadius: CGFloat
    @EnvironmentObject var themeManager: ThemeManager

    @State private var animatedFrame: CGRect = .zero
    @State private var pulseScale: CGFloat = 1.0

    private let overlayOpacity: Double = 0.75

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Fill with semi-transparent overlay
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(overlayOpacity))
                )

                // Cut out spotlight area
                guard !targetFrame.isEmpty else { return }

                context.blendMode = .destinationOut

                // Create spotlight path with padding for visual breathing room
                let spotlightRect = targetFrame.insetBy(dx: -12, dy: -12)
                let spotlightPath = RoundedRectangle(cornerRadius: cornerRadius + 8)
                    .path(in: spotlightRect)

                context.fill(spotlightPath, with: .color(.white))
            }
            .allowsHitTesting(false)
            .compositingGroup()
            .overlay {
                // Add a subtle glow around the spotlight
                if !targetFrame.isEmpty {
                    RoundedRectangle(cornerRadius: cornerRadius + 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.6),
                                    themeManager.currentTheme.secondaryColor.opacity(0.4),
                                    themeManager.currentTheme.primaryColor.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(
                            width: targetFrame.width + 24,
                            height: targetFrame.height + 24
                        )
                        .position(
                            x: targetFrame.midX,
                            y: targetFrame.midY
                        )
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.5),
                            radius: 20,
                            x: 0,
                            y: 0
                        )
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                        .onAppear {
                            pulseScale = 1.05
                        }
                }
            }
        }
        .ignoresSafeArea()
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: targetFrame)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        VStack {
            Text("Background Content")
                .font(.largeTitle)

            Spacer()

            Button("Example Button") {}
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.bottom, 100)
        }

        SpotlightOverlayView(
            targetFrame: CGRect(x: 150, y: 600, width: 120, height: 50),
            cornerRadius: 12
        )
    }
    .environmentObject(ThemeManager())
}
