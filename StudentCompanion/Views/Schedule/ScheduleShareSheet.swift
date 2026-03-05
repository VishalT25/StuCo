import SwiftUI
import UIKit

struct ScheduleShareSheet: View {
    let schedule: ScheduleCollection
    let courses: [Course]

    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var shareURL: String?
    @State private var isGenerating = false
    @State private var error: Error?
    @State private var showCopiedFeedback = false

    var body: some View {
        ZStack {
            // Glassmorphic background matching theme
            themeManager.currentTheme.darkModeBackgroundFill
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    previewSection

                    if let error = error {
                        errorSection(error: error)
                    }

                    if let url = shareURL {
                        shareActionsSection(url: url)
                    } else if isGenerating {
                        loadingSection
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
        }
        .task {
            await generateShareLink()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.up.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.darkModeAccentHue
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Share Schedule")
                .font(.title.bold())
                .foregroundColor(.primary)

            Text("Share your schedule with friends via iMessage")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar.circle.fill")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                Text("Schedule Preview")
                    .font(.headline)
            }

            // Schedule card
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(schedule.name)
                        .font(.title3.bold())
                    Spacer()
                    Circle()
                        .fill(schedule.color)
                        .frame(width: 20, height: 20)
                }

                Text(schedule.semester)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Divider()

                HStack {
                    Label("\(courses.count) courses", systemImage: "book.fill")
                    Spacer()
                    Label("\(totalMeetings) meetings", systemImage: "clock.fill")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
        }
    }

    // MARK: - Share Actions Section

    private func shareActionsSection(url: String) -> some View {
        VStack(spacing: 16) {
            // iMessage share button
            ShareLink(item: URL(string: url)!, message: Text("Check out my schedule!")) {
                HStack {
                    Image(systemName: "message.fill")
                    Text("Share via iMessage")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [
                            themeManager.currentTheme.primaryColor,
                            themeManager.currentTheme.darkModeAccentHue
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            // Copy link button
            Button {
                UIPasteboard.general.string = url
                withAnimation(.spring(response: 0.3)) {
                    showCopiedFeedback = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.spring(response: 0.3)) {
                        showCopiedFeedback = false
                    }
                }
            } label: {
                HStack {
                    Image(systemName: showCopiedFeedback ? "checkmark.circle.fill" : "doc.on.doc.fill")
                    Text(showCopiedFeedback ? "Link Copied!" : "Copy Link")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray5))
                .foregroundColor(showCopiedFeedback ? .green : .primary)
                .cornerRadius(12)
            }

            // Info text
            Text("Shared schedules expire after 7 days")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Loading Section

    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Generating share link...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Error Section

    private func errorSection(error: Error) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Unable to Share")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await generateShareLink()
                }
            } label: {
                Text("Try Again")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding()
    }

    // MARK: - Helpers

    private var totalMeetings: Int {
        courses.reduce(0) { $0 + $1.meetings.count }
    }

    private func generateShareLink() async {
        isGenerating = true
        error = nil

        do {
            let url = try await ShareableScheduleBuilder.shared.shareSchedule(schedule, courses: courses)
            await MainActor.run {
                self.shareURL = url
                self.isGenerating = false
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isGenerating = false
            }
        }
    }
}
