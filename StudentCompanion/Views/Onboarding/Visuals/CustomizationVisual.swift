import SwiftUI

struct CustomizationVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 20) {
            // Theme selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Your Theme")
                    .font(.forma(.body, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        themeOption(name: "Forest", color: Color(red: 95/255, green: 135/255, blue: 105/255), isSelected: true)
                        themeOption(name: "Ice", color: Color(red: 95/255, green: 135/255, blue: 155/255), isSelected: false)
                    }

                    HStack(spacing: 12) {
                        themeOption(name: "Fire", color: Color(red: 155/255, green: 95/255, blue: 105/255), isSelected: false)
                        themeOption(name: "Prime", color: Color(red: 140/255, green: 20/255, blue: 30/255), isSelected: false)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )

            // Description
            Text("Personalize your experience with beautiful themes that match your style")
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }

    private func themeOption(name: String, color: Color, isSelected: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(color)
                    .frame(width: 70, height: 70)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )

            Text(name)
                .font(.forma(.caption, weight: .semibold))
                .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.6))
        }
    }
}

#Preview {
    CustomizationVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
