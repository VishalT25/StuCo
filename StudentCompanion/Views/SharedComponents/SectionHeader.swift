import SwiftUI

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
        }
    }
}