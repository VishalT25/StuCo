import SwiftUI

struct SyncStatsView: View {
    @Binding var syncStats: SyncStats?
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sizeCategory) private var sizeCategory
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                List {
                    if let stats = syncStats {
                        Section(header: Text("Cloud Data Summary")) {
                            StatRow(label: "Schedules", count: stats.schedulesCount, icon: "calendar", color: .blue)
                            StatRow(label: "Courses", count: stats.coursesCount, icon: "book.closed", color: .purple)
                            StatRow(label: "Assignments", count: stats.assignmentsCount, icon: "doc.text", color: .orange)
                            StatRow(label: "Events", count: stats.eventsCount, icon: "bell", color: .green)
                            StatRow(label: "Categories", count: stats.categoriesCount, icon: "tag", color: .red)
                        }
                        
                        Section(header: Text("Total")) {
                            HStack {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                }
                                Text("Total Items")
                                    .font(.forma(.body, weight: .semibold))
                                Spacer()
                                Text("\(stats.totalItems)")
                                    .font(.forma(.title3, weight: .bold))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                    } else {
                        Section {
                            HStack {
                                ProgressView()
                                Text("Loading statistics...")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                }
                .frame(width: geometry.size.width, alignment: .leading)
                .listRowSpacing(4)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .environment(\.defaultMinListRowHeight, 38)
                .navigationTitle("Sync Statistics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .dynamicTypeSize(.small ... .large)
        .environment(\.sizeCategory, .large)
    }
}

struct StatRow: View {
    let label: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .foregroundColor(color)
            }
            Text(label)
                .font(.forma(.body, weight: .medium))
            Spacer()
            Text("\(count)")
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}
