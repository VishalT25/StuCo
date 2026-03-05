import SwiftUI

struct AIScheduleImportVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Phone mockup with camera
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 130, height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 2)
                    )

                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(theme.primaryColor)

                    Text("Scan")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                }
            }

            // Arrow
            Image(systemName: "arrow.down")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(theme.primaryColor)

            // Result mockup
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("3 Classes Detected")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(.white)
                }

                // Mock extracted classes
                ForEach(0..<2) { _ in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(theme.primaryColor)
                            .frame(width: 3, height: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("CS 101")
                                .font(.forma(.caption2, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Mon, Wed 9:00 AM")
                                .font(.forma(.caption2, weight: .regular))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
            )
        }
        .frame(height: 260)
        .padding(.horizontal, 40)
    }
}

#Preview {
    AIScheduleImportVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
