import SwiftUI

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    
    init(icon: String, iconColor: Color, title: String, subtitle: String? = nil) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 14, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.primary)
                    .font(.forma(.body, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                if let subtitle {
                    Text(subtitle)
                        .foregroundColor(.secondary)
                        .font(.forma(.subheadline))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.forma(.footnote, weight: .semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
