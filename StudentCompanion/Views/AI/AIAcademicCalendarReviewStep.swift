import SwiftUI

struct AIAcademicCalendarReviewStep: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let calendarName: String
    let academicYear: String
    let startDate: Date
    let endDate: Date
    let aiImportData: AIAcademicCalendarImportData?
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            headerSection
            calendarDetailsSection
            aiImportSummarySection
            
            Spacer()
        }
        .frame(maxWidth: 360)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.15),
                                Color.pink.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.purple,
                                Color.pink
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Ready to Create")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text("Review your academic calendar details below, then create your calendar")
                    .font(.forma(.body))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
    }
    
    private var calendarDetailsSection: some View {
        AcademicCalendarReviewSection(title: "Calendar Details", icon: "calendar") {
            AcademicCalendarReviewInfoRow(icon: "textformat.abc", label: "Name", value: calendarName)
            AcademicCalendarReviewInfoRow(icon: "graduationcap", label: "Academic Year", value: academicYear)
            AcademicCalendarReviewInfoRow(icon: "calendar.badge.plus", label: "Start Date", value: formatDate(startDate))
            AcademicCalendarReviewInfoRow(icon: "calendar.badge.minus", label: "End Date", value: formatDate(endDate))
        }
        .environmentObject(themeManager)
    }
    
    private var aiImportSummarySection: some View {
        AcademicCalendarReviewSection(title: "AI Import Summary", icon: "sparkles") {
            if let importData = aiImportData {
                AcademicCalendarReviewInfoRow(
                    icon: "minus.circle.fill",
                    label: "Breaks Detected",
                    value: "\(importData.breaks.count) breaks"
                )
                
                AcademicCalendarReviewInfoRow(
                    icon: "checkmark.seal.fill",
                    label: "AI Confidence",
                    value: String(format: "%.0f%%", importData.confidence * 100)
                )
                
                if !importData.breaks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Breaks")
                            .font(.forma(.caption, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        AcademicCalendarFlowLayout(spacing: 6) {
                            ForEach(Array(importData.breaks.prefix(6).enumerated()), id: \.offset) { index, academicBreak in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.orange)
                                        .frame(width: 6, height: 6)
                                    
                                    Text(academicBreak.name)
                                        .font(.forma(.caption2, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color(.systemGray6).opacity(0.5))
                                )
                            }
                            
                            if importData.breaks.count > 6 {
                                Text("+ \(importData.breaks.count - 6)")
                                    .font(.forma(.caption2, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color(.systemGray6).opacity(0.5))
                                    )
                            }
                        }
                    }
                    .padding(.top, 8)
                }
            } else {
                AcademicCalendarReviewInfoRow(
                    icon: "exclamationmark.circle",
                    label: "No AI Data",
                    value: "Manual calendar creation"
                )
            }
        }
        .environmentObject(themeManager)
    }
}

// MARK: - Academic Calendar Specific Review Components

struct AcademicCalendarReviewSection<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let title: String
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: icon)
                        .font(.forma(.caption, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.purple,
                                    Color.pink
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                Text(title)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 10) {
                content()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.purple.opacity(0.25),
                                        Color.pink.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: Color.purple.opacity(0.1), radius: 8, x: 0, y: 4)
        }
    }
}

struct AcademicCalendarReviewInfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.forma(.caption, weight: .semibold))
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray6).opacity(0.4))
        )
    }
}

struct AcademicCalendarFlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    init(spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(minHeight: 0)
    }
    
    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            content()
                .alignmentGuide(.leading, computeValue: { d in
                    if (abs(width - d.width) > geometry.size.width) {
                        width = 0
                        height -= d.height + spacing
                    }
                    let result = width
                    if #available(iOS 17.0, *) {
                        width -= d.width + spacing
                    } else {
                        width = d.width + spacing + width
                    }
                    return result
                })
                .alignmentGuide(.top, computeValue: { _ in
                    let result = height
                    return result
                })
        }
    }
}