import SwiftUI

struct ScheduleWizardVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // 4-step wizard indicators
            HStack(spacing: 12) {
                ForEach(1...4, id: \.self) { step in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(step <= 2 ? theme.primaryColor : Color.white.opacity(0.3))
                            .frame(width: 32, height: 32)
                            .overlay(
                                Text("\(step)")
                                    .font(.forma(.caption, weight: .bold))
                                    .foregroundColor(.white)
                            )

                        Text("Step \(step)")
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    if step < 4 {
                        Rectangle()
                            .fill(step < 2 ? theme.primaryColor : Color.white.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            // Mock form
            VStack(alignment: .leading, spacing: 12) {
                Text("Schedule Details")
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.white)

                // Mock input field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Schedule Name")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 44)
                        .overlay(
                            HStack {
                                Text("Fall 2026")
                                    .font(.forma(.body, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                        )
                }

                // Mock date range
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Start Date")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 44)
                            .overlay(
                                Text("Sep 3")
                                    .font(.forma(.body, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("End Date")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 44)
                            .overlay(
                                Text("Dec 20")
                                    .font(.forma(.body, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
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
    ScheduleWizardVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
