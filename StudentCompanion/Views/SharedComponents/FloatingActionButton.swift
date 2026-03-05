import SwiftUI

struct FloatingActionButton: View {
    let systemImage: String
    let color: Color
    let foreground: Color
    let action: () -> Void

    init(systemImage: String, color: Color, foreground: Color = .white, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.color = color
        self.foreground = foreground
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.bold())
                .foregroundColor(foreground)
                .padding(20)
                .background(Circle().fill(color))
                .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(SpringButtonStyle())
    }
}

// MARK: - Button Style
//struct SpringButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
//            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
//    }
//}
