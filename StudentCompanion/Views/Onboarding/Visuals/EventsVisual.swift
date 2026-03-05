import SwiftUI

struct EventsVisual: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 16) {
            // Mock event form
            VStack(alignment: .leading, spacing: 12) {
                // Title field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Event Title")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 44)
                        .overlay(
                            HStack {
                                Text("Math Midterm")
                                    .font(.forma(.body, weight: .regular))
                                    .foregroundColor(.white.opacity(0.5))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                        )
                }

                // Date and category
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Date")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(theme.primaryColor)
                            Text("Oct 15")
                                .font(.forma(.body, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                        )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Category")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))

                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(theme.primaryColor)
                            Text("CS 101")
                                .font(.forma(.body, weight: .regular))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )

            // Reminder options
            VStack(alignment: .leading, spacing: 10) {
                Text("Reminders & Sync")
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))

                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundColor(.orange)
                    Text("15 minutes before")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 18, height: 18)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )

                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundColor(.blue)
                    Text("Sync to Google Calendar")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                    Spacer()
                    Circle()
                        .fill(theme.primaryColor)
                        .frame(width: 18, height: 18)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
            }
            .padding(12)
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
    EventsVisual(theme: AppTheme.forest)
        .preferredColorScheme(.dark)
        .background(Color.black)
}
