import SwiftUI

struct DashboardVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 12) {
            // Mock weather widget
            HStack {
                Image(systemName: "cloud.sun.fill")
                    .foregroundColor(.orange)
                Text("22°C")
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text("Monday, Jan 15")
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )

            // Mock schedule preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Schedule")
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.white)

                // Mock class items
                ForEach(0..<3) { index in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.primaryColor)
                            .frame(width: 4, height: 40)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Course Name")
                                .font(.forma(.caption, weight: .semibold))
                                .foregroundColor(.white)
                            Text("9:00 AM - 10:30 AM")
                                .font(.forma(.caption2, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .frame(height: 300)
        .padding(.horizontal, 40)
    }
}

#Preview {
    DashboardVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
