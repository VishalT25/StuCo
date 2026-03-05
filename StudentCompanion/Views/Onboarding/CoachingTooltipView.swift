import SwiftUI

struct CoachingTooltipView: View {
    let text: String
    let position: TooltipPosition
    let targetFrame: CGRect
    let showNextButton: Bool
    let onNext: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme

    @State private var tooltipSize: CGSize = .zero
    @State private var appeared = false

    var body: some View {
        GeometryReader { geometry in
            let screenSize = geometry.size
            let safeArea = geometry.safeAreaInsets

            tooltipContent
                .background(
                    GeometryReader { tooltipGeometry in
                        Color.clear
                            .preference(key: TooltipSizeKey.self, value: tooltipGeometry.size)
                    }
                )
                .onPreferenceChange(TooltipSizeKey.self) { size in
                    tooltipSize = size
                }
                .position(
                    calculatePosition(
                        screenSize: screenSize,
                        safeArea: safeArea
                    )
                )
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.9)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appeared)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                appeared = true
            }
        }
    }

    private var tooltipContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(text)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if showNextButton {
                Button {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onNext()
                } label: {
                    Text("Next")
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
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
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: min(320, UIScreen.main.bounds.width - 48))
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
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
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.3),
                    radius: 24,
                    x: 0,
                    y: 12
                )
        )
    }

    private func calculatePosition(screenSize: CGSize, safeArea: EdgeInsets) -> CGPoint {
        let padding: CGFloat = 24
        let halfWidth = tooltipSize.width / 2
        let halfHeight = tooltipSize.height / 2

        // Calculate center of screen for horizontal positioning
        let screenCenterX = screenSize.width / 2

        // For FAB-related tooltips (bottom-right area), position tooltip in center-left area
        let targetIsInBottomRight = targetFrame.midX > screenSize.width * 0.5 && targetFrame.midY > screenSize.height * 0.5

        var calculatedPosition: CGPoint

        if targetIsInBottomRight {
            // Position tooltip above and to the left of target (centered horizontally)
            calculatedPosition = CGPoint(
                x: screenCenterX,
                y: targetFrame.minY - halfHeight - padding - 20
            )
        } else {
            // Default position calculation based on specified position
            calculatedPosition = position.calculatePosition(
                for: targetFrame,
                tooltipSize: tooltipSize,
                screenSize: screenSize,
                safeArea: safeArea
            )
        }

        // Ensure tooltip stays within screen bounds horizontally
        if calculatedPosition.x - halfWidth < padding {
            calculatedPosition.x = halfWidth + padding
        } else if calculatedPosition.x + halfWidth > screenSize.width - padding {
            calculatedPosition.x = screenSize.width - halfWidth - padding
        }

        // Ensure tooltip stays within screen bounds vertically
        let topBound = safeArea.top + padding + 60 // Extra space for skip button
        let bottomBound = screenSize.height - safeArea.bottom - padding

        if calculatedPosition.y - halfHeight < topBound {
            calculatedPosition.y = halfHeight + topBound
        } else if calculatedPosition.y + halfHeight > bottomBound {
            calculatedPosition.y = bottomBound - halfHeight
        }

        return calculatedPosition
    }
}

// MARK: - Size Preference Key

private struct TooltipSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()

            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue)
                .frame(width: 100, height: 50)
                .padding(.bottom, 100)
        }

        CoachingTooltipView(
            text: "Tap the + button to create your first schedule or course",
            position: .above,
            targetFrame: CGRect(x: 300, y: 650, width: 64, height: 64),
            showNextButton: true,
            onNext: { print("Next tapped") }
        )
    }
    .environmentObject(ThemeManager())
}
