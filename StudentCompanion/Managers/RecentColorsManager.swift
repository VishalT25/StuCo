import SwiftUI

class RecentColorsManager: ObservableObject {
    static let shared = RecentColorsManager()

    @Published private(set) var recentColors: [Color] = []
    private let maxRecentColors = 12
    private let userDefaultsKey = "RecentCourseColors"

    init() {
        loadRecentColors()
    }

    func addColor(_ color: Color) {
        let hexString = color.toHex() ?? ""

        // Don't add if it's a predefined color
        let predefinedColors: [Color] = [
            .red, .orange, .yellow, .green, .mint, .teal,
            .cyan, .blue, .indigo, .purple, .pink, .brown
        ]

        let predefinedHexes = predefinedColors.compactMap { $0.toHex() }

        guard !predefinedHexes.contains(hexString) else { return }

        // Remove if already exists
        recentColors.removeAll { $0.toHex() == hexString }

        // Add to front
        recentColors.insert(color, at: 0)

        // Keep only max count
        if recentColors.count > maxRecentColors {
            recentColors = Array(recentColors.prefix(maxRecentColors))
        }

        saveRecentColors()
    }

    private func saveRecentColors() {
        let hexStrings = recentColors.compactMap { $0.toHex() }
        UserDefaults.standard.set(hexStrings, forKey: userDefaultsKey)
    }

    private func loadRecentColors() {
        if let hexStrings = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] {
            recentColors = hexStrings.compactMap { Color(hex: $0) }
        }
    }
}
