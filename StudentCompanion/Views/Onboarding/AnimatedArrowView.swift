import SwiftUI

struct AnimatedArrowView: View {
    let direction: ArrowDirection
    let targetFrame: CGRect

    @EnvironmentObject var themeManager: ThemeManager

    @State private var animationOffset: CGFloat = 0
    @State private var opacity: Double = 1.0

    private let arrowSize: CGFloat = 32
    private let animationDistance: CGFloat = 10

    var body: some View {
        GeometryReader { _ in
            arrowImage
                .position(arrowPosition)
                .offset(animationOffsetValue)
                .opacity(opacity)
                .animation(
                    .easeInOut(duration: 0.7)
                    .repeatForever(autoreverses: true),
                    value: animationOffset
                )
                .onAppear {
                    animationOffset = 1
                }
        }
        .allowsHitTesting(false)
    }

    private var arrowImage: some View {
        Image(systemName: arrowImageName)
            .font(.system(size: arrowSize, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(
                color: themeManager.currentTheme.primaryColor.opacity(0.6),
                radius: 10,
                x: 0,
                y: 4
            )
            .rotationEffect(rotationAngle)
    }

    private var arrowImageName: String {
        // Always use arrow.down and rotate as needed
        return "arrow.down"
    }

    private var rotationAngle: Angle {
        switch direction {
        case .up:
            return .degrees(180)
        case .down:
            return .degrees(0)
        case .left:
            return .degrees(90)
        case .right:
            return .degrees(-90)
        }
    }

    /// Position the arrow so it points AT the target
    /// - .down: Arrow is ABOVE target, pointing down towards it
    /// - .up: Arrow is BELOW target, pointing up towards it
    /// - .left: Arrow is RIGHT of target, pointing left towards it
    /// - .right: Arrow is LEFT of target, pointing right towards it
    private var arrowPosition: CGPoint {
        let padding: CGFloat = 20

        switch direction {
        case .down:
            // Arrow above target, pointing down at it
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.minY - padding - arrowSize / 2
            )
        case .up:
            // Arrow below target, pointing up at it
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.maxY + padding + arrowSize / 2
            )
        case .left:
            // Arrow to the right of target, pointing left at it
            return CGPoint(
                x: targetFrame.maxX + padding + arrowSize / 2,
                y: targetFrame.midY
            )
        case .right:
            // Arrow to the left of target, pointing right at it
            return CGPoint(
                x: targetFrame.minX - padding - arrowSize / 2,
                y: targetFrame.midY
            )
        }
    }

    private var animationOffsetValue: CGSize {
        let offset = animationOffset * animationDistance

        switch direction {
        case .down:
            // Arrow moves down towards target
            return CGSize(width: 0, height: offset)
        case .up:
            // Arrow moves up towards target
            return CGSize(width: 0, height: -offset)
        case .left:
            // Arrow moves left towards target
            return CGSize(width: -offset, height: 0)
        case .right:
            // Arrow moves right towards target
            return CGSize(width: offset, height: 0)
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()

            // Target button representation
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.blue)
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                        .font(.title2.bold())
                )
                .padding(.trailing, 20)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.bottom, 100)
        }

        // Arrow pointing at target
        AnimatedArrowView(
            direction: .down,
            targetFrame: CGRect(x: 300, y: 650, width: 64, height: 64)
        )
    }
    .environmentObject(ThemeManager())
}
