import SwiftUI

// MARK: - Review Modal (High-performance List + caching)
struct AIImportReviewModal: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @Binding var importData: AIImportData?
    let scheduleType: ScheduleType
    let palette: [Color]
    let resolveColorForCourse: (String) -> Color
    let baseCourseName: (String) -> String

    @State private var searchText: String = ""
    @State private var showAddCourseSheet: Bool = false
    @State private var newCourseName: String = ""
    @State private var newCourseColor: Color = .blue
    @State private var selectedFilter: CourseFilter = .all

    @State private var groupsCache: [CourseGroup] = []
    @State private var editingMeeting: ScheduleItem?
    @State private var isEditingMeeting: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 20) {
                    ReviewSearchBar(text: $searchText)
                        .environmentObject(themeManager)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                ScrollViewReader { proxy in
                    List {
                        Section {
                            summaryCard
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                                .listRowBackground(Color.clear)
                        }

                        Section {
                            ForEach(filteredGroups, id: \.id) { group in
                                CourseGroupRow(
                                    group: group,
                                    scheduleType: scheduleType,
                                    importData: $importData,
                                    onColorChange: { color in setColorForCourse(group.name, color) },
                                    onTitleChange: { newTitle in renameCourseGroup(oldName: group.name, newName: newTitle) },
                                    onAddMeeting: { addMeeting(to: group.name) },
                                    onRemoveMeeting: { removeMeeting(at: $0) },
                                    onUpdateMeeting: { idx, meeting in
                                        if importData?.parsedItems.indices.contains(idx) == true {
                                            importData!.parsedItems[idx] = meeting
                                            recomputeGroupsCache()
                                        }
                                    },
                                    onEditMeeting: { meeting in
                                        editingMeeting = meeting
                                        isEditingMeeting = true
                                    }
                                )
                                .environmentObject(themeManager)
                                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowBackground(Color.clear)
                                .id(group.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 20)
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.03),
                        themeManager.currentTheme.secondaryColor.opacity(0.02),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Review Courses")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.forma(.subheadline, weight: .semibold))
                            Text("Done")
                                .font(.forma(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newCourseName = ""
                        newCourseColor = palette.randomElement() ?? .blue
                        showAddCourseSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.forma(.subheadline, weight: .semibold))
                            Text("Add")
                                .font(.forma(.subheadline, weight: .semibold))
                        }
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor,
                                    themeManager.currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }
            }
            .sheet(isPresented: $showAddCourseSheet) {
                addCourseSheet
                    .presentationDetents([.height(350)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isEditingMeeting) {
                if let meeting = editingMeeting {
                    MeetingEditorSheet(
                        initial: meeting,
                        scheduleType: scheduleType,
                        rotationAssignment: { id in importData?.rotationAssignmentByItemID[id] ?? 1 },
                        updateRotationAssignment: { id, day in importData?.rotationAssignmentByItemID[id] = day },
                        onSave: { updated in
                            if let idx = importData?.parsedItems.firstIndex(where: { $0.id == updated.id }) {
                                importData!.parsedItems[idx] = updated
                                recomputeGroupsCache()
                            }
                            editingMeeting = nil
                            isEditingMeeting = false
                        },
                        onCancel: {
                            editingMeeting = nil
                            isEditingMeeting = false
                        }
                    )
                    .environmentObject(themeManager)
                }
            }
            .onAppear {
                recomputeGroupsCache()
            }
            .onChange(of: searchText) { _, _ in
                // no-op, filteredGroups derives from state
            }
            .onChange(of: selectedFilter) { _, _ in
                // no-op, filteredGroups derives from state
            }
            .onChange(of: importData?.parsedItems.count ?? 0) { _, _ in
                recomputeGroupsCache()
            }
        }
    }

    private var filteredGroups: [CourseGroup] {
        var base = groupsCache
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return base }
        return base.filter { group in
            if group.name.lowercased().contains(q) { return true }
            guard let items = importData?.parsedItems else { return false }
            for idx in group.indices {
                let item = items[idx]
                if item.location.lowercased().contains(q) ||
                    item.instructor.lowercased().contains(q) ||
                    item.title.lowercased().contains(q) {
                    return true
                }
            }
            return false
        }
    }

    private func recomputeGroupsCache() {
        guard let items = importData?.parsedItems else {
            groupsCache = []
            return
        }
        var map: [String: (Color, [Int])] = [:]
        for (idx, item) in items.enumerated() {
            let key = baseCourseName(item.title)
            if map[key] != nil {
                map[key]!.1.append(idx)
            } else {
                map[key] = (item.color, [idx])
            }
        }
        groupsCache = map.map { (name, data) in
            CourseGroup(id: UUID(), name: name, indices: data.1, color: data.0)
        }.sorted { $0.name < $1.name }
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.forma(.subheadline, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Import Summary")
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)

                    Text("AI analyzed your schedule successfully")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            HStack(spacing: 16) {
                SummaryStatCard(
                    value: "\(groupsCache.count)",
                    label: "Courses",
                    icon: "book.closed.fill",
                    color: .indigo
                )

                SummaryStatCard(
                    value: "\(importData?.parsedItems.count ?? 0)",
                    label: "Classes",
                    icon: "calendar.badge.plus",
                    color: .teal
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }

    private var filtersSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CourseFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        onTap: { selectedFilter = filter }
                    )
                    .environmentObject(themeManager)
                }
            }
        }
    }

    private func setColorForCourse(_ courseName: String, _ color: Color) {
        guard importData != nil else { return }
        for i in importData!.parsedItems.indices {
            let name = baseCourseName(importData!.parsedItems[i].title)
            if name == courseName {
                importData!.parsedItems[i].color = color
            }
        }
        recomputeGroupsCache()
    }

    private func renameCourseGroup(oldName: String, newName: String) {
        guard var data = importData else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        for i in data.parsedItems.indices {
            let title = data.parsedItems[i].title
            let currentBase = baseCourseName(title)
            if currentBase == oldName {
                if let range = title.range(of: " - ") {
                    let suffix = String(title[range.upperBound...])
                    data.parsedItems[i].title = "\(trimmed) - \(suffix)"
                } else {
                    data.parsedItems[i].title = trimmed
                }
            }
        }
        importData = data
        recomputeGroupsCache()
    }

    private func addMeeting(to courseName: String) {
        guard var data = importData else { return }

        let indices = data.parsedItems.indices.filter {
            baseCourseName(data.parsedItems[$0].title) == courseName
        }

        var newItem: ScheduleItem

        if let lastIdx = indices.last {
            let last = data.parsedItems[lastIdx]
            newItem = ScheduleItem(
                id: UUID(),
                title: last.title,
                startTime: last.startTime,
                endTime: last.endTime,
                daysOfWeek: last.daysOfWeek,
                location: last.location,
                instructor: last.instructor,
                color: last.color,
                isLiveActivityEnabled: last.isLiveActivityEnabled,
                reminderTime: last.reminderTime
            )

            if let day = data.rotationAssignmentByItemID[last.id] {
                data.rotationAssignmentByItemID[newItem.id] = day
            }
            if let labels = data.rotationLabelsByItemID[last.id] {
                data.rotationLabelsByItemID[newItem.id] = labels
            }
        } else {
            let cal = Calendar.current
            let base = cal.startOfDay(for: Date())
            let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? Date()
            let end = cal.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? Date()
            let color = resolveColorForCourse(courseName)
            newItem = ScheduleItem(
                id: UUID(),
                title: "\(courseName) - Lecture",
                startTime: start,
                endTime: end,
                daysOfWeek: [.monday, .wednesday],
                location: "",
                instructor: "",
                color: color,
                isLiveActivityEnabled: true,
                reminderTime: .none
            )
        }

        data.parsedItems.append(newItem)
        importData = data
        recomputeGroupsCache()
    }

    private func removeMeeting(at index: Int) {
        guard importData != nil else { return }
        if importData!.parsedItems.indices.contains(index) {
            importData!.parsedItems.remove(at: index)
            recomputeGroupsCache()
        }
    }

    private var addCourseSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course Name")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        TextField("e.g., Calculus I", text: $newCourseName)
                            .textInputAutocapitalization(.words)
                            .font(.forma(.body))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Course Color")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.primary)

                        HStack {
                            ColorPicker("", selection: $newCourseColor)
                                .labelsHidden()

                            Text("Color selection")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                        )
                    }
                }

                Spacer()

                Button {
                    createNewCourse()
                    showAddCourseSheet = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.subheadline, weight: .semibold))

                        Text("Create Course")
                            .font(.forma(.headline, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .disabled(newCourseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newCourseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
            }
            .padding(20)
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showAddCourseSheet = false
                    }
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    private func createNewCourse() {
        guard var data = importData else { return }
        let cal = Calendar.current
        let base = cal.startOfDay(for: Date())
        let start = cal.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? Date()
        let end = cal.date(bySettingHour: 10, minute: 0, second: 0, of: base) ?? Date()

        let name = newCourseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let item = ScheduleItem(
            id: UUID(),
            title: "\(name) - Lecture",
            startTime: start,
            endTime: end,
            daysOfWeek: scheduleType == .rotating ? [] : [.monday, .wednesday],
            location: "",
            instructor: "",
            color: newCourseColor,
            isLiveActivityEnabled: true,
            reminderTime: .none
        )
        data.parsedItems.append(item)
        importData = data
        recomputeGroupsCache()
    }
}

enum CourseFilter: String, CaseIterable {
    case all = "All"
    case needsReview = "Needs Review"
    case hasIssues = "Has Issues"

    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .needsReview: return "exclamationmark.triangle"
        case .hasIssues: return "exclamationmark.circle"
        }
    }
}

struct CourseGroup: Identifiable {
    let id: UUID
    var name: String
    let indices: [Int]
    var color: Color
}

struct ReviewSearchBar: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search courses, instructor, or location", text: $text)
                .font(.forma(.body))
                .focused($isFocused)
                .textInputAutocapitalization(.words)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            isFocused
                            ? themeManager.currentTheme.primaryColor.opacity(0.5)
                            : Color.clear,
                            lineWidth: 1
                        )
                )
        )
    }
}

struct SummaryStatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(color)

                Text(value)
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.primary)
            }

            Text(label)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct FilterChip: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let filter: CourseFilter
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.forma(.caption, weight: .semibold))
                Text(filter.rawValue)
                    .font(.forma(.subheadline, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : themeManager.currentTheme.primaryColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        themeManager.currentTheme.primaryColor.opacity(0.1)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}
