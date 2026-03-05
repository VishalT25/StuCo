import SwiftUI

struct ToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let color: Color
    
    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.color = color
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(color)
        }
    }
}