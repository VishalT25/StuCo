import SwiftUI

/// A view that displays either an emoji or SF Symbol icon for a course
struct CourseIconView: View {
    let iconName: String
    let emoji: String?
    let color: Color
    let size: CGFloat

    init(course: Course, size: CGFloat = 24) {
        self.iconName = course.iconName
        self.emoji = course.emoji
        self.color = course.color
        self.size = size
    }

    init(iconName: String, emoji: String?, color: Color, size: CGFloat = 24) {
        self.iconName = iconName
        self.emoji = emoji
        self.color = color
        self.size = size
    }

    var body: some View {
        Group {
            if let emoji = emoji, !emoji.isEmpty {
                // Display emoji
                Text(emoji)
                    .font(.system(size: size * 0.8))
            } else {
                // Display SF Symbol
                Image(systemName: iconName)
                    .font(.system(size: size * 0.6))
                    .foregroundColor(color)
            }
        }
    }
}

/// Extension to make it easier to display course icons with proper styling
extension View {
    func courseIcon(course: Course, size: CGFloat = 24) -> some View {
        CourseIconView(course: course, size: size)
    }
}
