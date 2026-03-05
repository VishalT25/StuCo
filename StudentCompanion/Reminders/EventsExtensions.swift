import SwiftUI
import Combine

// MARK: - Extensions
extension Notification.Name {
    static let googleCalendarEventsFetched = Notification.Name("googleCalendarEventsFetched")
}

extension Color {
    static let primaryGreen = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
        } else {
            return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
        }
    })
    
    static let Color_secondary = Color(UIColor { traitCollection in
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor.secondarySystemBackground
        } else {
            return UIColor.systemGray4
        }
    })
}