import SwiftUI
import Combine

struct ScheduleManagerView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSchedule = false
    @State private var showingDeleteAlert = false
    @State private var scheduleToDelete: ScheduleCollection?
    @State private var showingArchiveAlert = false
    @State private var scheduleToArchive: ScheduleCollection?
    
    // State for the new enhancement flow
    @State private var newScheduleID: UUID?
    @State private var showingEnhancementView = false
    
    private var activeSchedules: [ScheduleCollection] {
        scheduleManager.activeSchedules.sorted { first, second in
            if scheduleManager.activeScheduleID == first.id { return true }
            if scheduleManager.activeScheduleID == second.id { return false }
            return first.lastModified > second.lastModified
        }
    }
    
    private var archivedSchedules: [ScheduleCollection] {
        scheduleManager.archivedSchedules.sorted { $0.lastModified > $1.lastModified }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("My Schedules")
                            .font(.forma(.largeTitle, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 20)

                    // Active Schedules Section
                    if !activeSchedules.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Active Schedules")
                                    .font(.forma(.title2, weight: .bold))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(activeSchedules) { schedule in
                                    ScheduleCard(
                                        schedule: schedule,
                                        isActive: scheduleManager.activeScheduleID == schedule.id,
                                        isArchived: false,
                                        onSetActive: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                                scheduleManager.setActiveSchedule(schedule.id)
                                            }
                                        },
                                        onArchive: {
                                            scheduleToArchive = schedule
                                            showingArchiveAlert = true
                                        },
                                        onDelete: {
                                            scheduleToDelete = schedule
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .environmentObject(themeManager)
                                    .environmentObject(scheduleManager)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Archived Schedules Section
                    if !archivedSchedules.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Archived Schedules")
                                    .font(.forma(.title2, weight: .bold))
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Text("\(archivedSchedules.count)")
                                    .font(.forma(.caption, weight: .semibold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(.systemGray4))
                                    .foregroundColor(.secondary)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 20)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(archivedSchedules) { schedule in
                                    ScheduleCard(
                                        schedule: schedule,
                                        isActive: false,
                                        isArchived: true,
                                        onSetActive: {},
                                        onArchive: {},
                                        onDelete: {
                                            scheduleToDelete = schedule
                                            showingDeleteAlert = true
                                        }
                                    )
                                    .environmentObject(themeManager)
                                    .environmentObject(scheduleManager)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .font(.forma(.body, weight: .semibold))
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingEnhancementView = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
        }
        .sheet(isPresented: $showingEnhancementView) {
            ScheduleCreationWizardView()
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
                .environmentObject(academicCalendarManager)
        }
        .alert("Archive Schedule", isPresented: $showingArchiveAlert) {
            Button("Cancel", role: .cancel) {
                scheduleToArchive = nil
            }
            Button("Archive") {
                if let schedule = scheduleToArchive {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        scheduleManager.archiveSchedule(schedule)
                    }
                }
                scheduleToArchive = nil
            }
        } message: {
            if let schedule = scheduleToArchive {
                Text("Archive '\(schedule.displayName)'? It will be moved to archived schedules and no longer appear in your active schedules.")
            }
        }
        .alert("Delete Schedule", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                scheduleToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let schedule = scheduleToDelete {
                    scheduleManager.deleteSchedule(schedule)
                }
                scheduleToDelete = nil
            }
        } message: {
            if let schedule = scheduleToDelete {
                if scheduleManager.activeSchedules.count == 1 && !schedule.isArchived {
                    Text("This is your last active schedule. Deleting it will create a new default schedule.")
                } else {
                    Text("Are you sure you want to delete '\(schedule.displayName)'? This will remove all \(schedule.totalClasses) classes and cannot be undone.")
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("DismissScheduleManager"))) { _ in
            dismiss()
        }
    }

    private func createNewSchedule() -> ScheduleCollection {
        return ScheduleCollection(
            name: "New Schedule",
            semester: getCurrentSemester(),
            color: themeManager.currentTheme.primaryColor
        )
    }
    
    private func getCurrentSemester() -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        let year = calendar.component(.year, from: Date())
        
        if month >= 8 || month <= 1 {
            return "Fall \(year)"
        } else if month >= 2 && month <= 5 {
            return "Spring \(year)"
        } else {
            return "Summer \(year)"
        }
    }
}

struct ScheduleCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    let schedule: ScheduleCollection
    let isActive: Bool
    let isArchived: Bool
    let onSetActive: () -> Void
    let onArchive: () -> Void
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    
    private var lastModifiedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: schedule.lastModified, relativeTo: Date()))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(schedule.displayName)
                            .font(.forma(.title2, weight: .bold))
                            .foregroundColor(isArchived ? .secondary : .primary)
                            .lineLimit(2)
                        
                        if isActive {
                            Text("ACTIVE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .cornerRadius(4)
                        }
                        
                        if isArchived {
                            Text("ARCHIVED")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.systemGray4))
                                .foregroundColor(.secondary)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(lastModifiedText)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Menu {
                        if isArchived {
                            Button("Unarchive Schedule", systemImage: "arrow.up.bin") {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    scheduleManager.unarchiveSchedule(schedule)
                                }
                            }
                        } else {
                            if !isActive {
                                Button("Set as Active", systemImage: "checkmark.circle") {
                                    onSetActive()
                                }
                            }
                            
                            Button("Edit Schedule", systemImage: "pencil") {
                                showingEditSheet = true
                            }
                            
                            Button("Archive Schedule", systemImage: "archivebox") {
                                onArchive()
                            }
                        }
                        
                        Button("Delete Schedule", systemImage: "trash", role: .destructive) {
                            onDelete()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Stats
            HStack(spacing: 24) {
                StatView(
                    value: "\(classCount())",
                    label: "Classes",
                    color: isArchived ? .secondary : themeManager.currentTheme.primaryColor
                )
                
                StatView(
                    value: String(format: "%.1f", weeklyHoursTotal()),
                    label: "Hours/Week",
                    color: isArchived ? .secondary : themeManager.currentTheme.secondaryColor
                )
                
                Spacer()
            }
            
            // keep Unarchive here (if archived). No Set Active here (moved to overlay).
            if classCount() == 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("No classes scheduled")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                        
                        Text(isArchived ? "Archived schedule" : "Add classes to get started")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isArchived {
                        Button("Unarchive") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                scheduleManager.unarchiveSchedule(schedule)
                            }
                        }
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray2))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isArchived ? Color(.systemGray6) : (isActive ? themeManager.currentTheme.quaternaryColor : Color(.systemBackground)))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isArchived ? Color(.systemGray4) : (isActive ? themeManager.currentTheme.primaryColor.opacity(0.3) : Color(.systemGray5)), lineWidth: isActive ? 2 : 1)
                )
                .shadow(color: isActive ? themeManager.currentTheme.primaryColor.opacity(0.1) : Color.black.opacity(0.05), radius: isActive ? 8 : 4, x: 0, y: isActive ? 4 : 2)
        )
        .overlay(alignment: .bottomTrailing) {
            if !isActive && !isArchived {
                Button("Set Active") {
                    onSetActive()
                }
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(themeManager.currentTheme.primaryColor)
                .cornerRadius(10)
                .padding(16) // inset from the card edges
                .buttonStyle(.plain)
            }
        }
        .scaleEffect(isActive ? 1.02 : (isArchived ? 0.98 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isArchived)
        .sheet(isPresented: $showingEditSheet) {
            EditScheduleView(schedule: schedule)
                .environmentObject(scheduleManager)
                .environmentObject(themeManager)
        }
    }


    private func classesInSchedule() -> [Course] {
        courseManager.courses.filter { course in
            course.scheduleId == schedule.id && course.hasScheduleInfo
        }
    }
    
    private func classCount() -> Int {
        // Combine Course-backed classes plus any legacy/enhanced items that don’t overlap by ID
        var ids = Set<UUID>()
        classesInSchedule().forEach { ids.insert($0.id) }
        schedule.scheduleItems.forEach { ids.insert($0.id) }
        schedule.enhancedScheduleItems.forEach { ids.insert($0.id) }
        return ids.count
    }
    
    private func weeklyHoursTotal() -> Double {
        var total = 0.0
        let courseIDs = Set(classesInSchedule().map { $0.id })
        
        // From courses
        for course in classesInSchedule() {
            total += weeklyHours(for: course)
        }
        // Include legacy items not mirrored by a course
        for item in schedule.scheduleItems where !courseIDs.contains(item.id) {
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600.0
            total += duration * Double(max(1, item.daysOfWeek.count))
        }
        // Include enhanced items not mirrored by a course
        for item in schedule.enhancedScheduleItems where !courseIDs.contains(item.id) {
            let duration = item.endTime.timeIntervalSince(item.startTime) / 3600.0
            total += duration * Double(max(1, item.daysOfWeek.count))
        }
        return total
    }
    
    private func weeklyHours(for course: Course) -> Double {
        var totalWeeklyHours = 0.0
        
        // Use the new meetings-based approach
        for meeting in course.meetings {
            let meetingDuration = meeting.endTime.timeIntervalSince(meeting.startTime) / 3600.0
            
            if meeting.isRotating {
                // For rotating meetings, they typically occur every other day or according to rotation pattern
                // Since rotation usually means alternating days, approximate as 2.5 days per week
                totalWeeklyHours += meetingDuration * 2.5
            } else {
                // For regular meetings, multiply duration by actual days per week
                let daysPerWeek = meeting.daysOfWeek.count
                totalWeeklyHours += meetingDuration * Double(max(1, daysPerWeek))
            }
        }
        
        // If no meetings found, fall back to legacy calculation for backward compatibility
        if course.meetings.isEmpty {
            if course.isRotating {
                let d1: Double = {
                    if let s = course.day1StartTime, let e = course.day1EndTime {
                        return e.timeIntervalSince(s) / 3600.0
                    }
                    return 0.0
                }()
                let d2: Double = {
                    if let s = course.day2StartTime, let e = course.day2EndTime {
                        return e.timeIntervalSince(s) / 3600.0
                    }
                    return 0.0
                }()
                
                // For rotating schedules, approximate as 2.5 times per week for each rotation day
                if d1 > 0 && d2 > 0 {
                    // Both days exist, so average them and multiply by 2.5 (approximate for rotation)
                    totalWeeklyHours += (d1 + d2) * 2.5 / 2.0
                } else if d1 > 0 {
                    totalWeeklyHours += d1 * 2.5
                } else if d2 > 0 {
                    totalWeeklyHours += d2 * 2.5
                }
            } else {
                guard let s = course.startTime, let e = course.endTime else { return 0.0 }
                let duration = e.timeIntervalSince(s) / 3600.0
                totalWeeklyHours += duration * Double(max(1, course.daysOfWeek.count))
            }
        }
        
        return totalWeeklyHours
    }
}

struct StatView: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.forma(.title2, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.forma(.caption))
                .foregroundColor(.secondary)
        }
    }
}

struct EditScheduleView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let schedule: ScheduleCollection
    @State private var name: String
    @State private var semester: String

    @State private var color: Color
    @State private var scheduleType: ScheduleType
    @State private var useSemesterDates: Bool
    @State private var semesterStartDate: Date
    @State private var semesterEndDate: Date
    @State private var showingTypeSwitchAlert = false
    @State private var pendingScheduleType: ScheduleType? = nil
    @State private var willWipeOnSave = false
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!useSemesterDates || semesterStartDate <= semesterEndDate)
    }
    
    init(schedule: ScheduleCollection) {
        self.schedule = schedule
        self._name = State(initialValue: schedule.name)
        self._semester = State(initialValue: schedule.semester)
        self._color = State(initialValue: schedule.color)
        self._scheduleType = State(initialValue: schedule.scheduleType)
        let start = schedule.semesterStartDate ?? Date()
        let end = schedule.semesterEndDate ?? Calendar.current.date(byAdding: .month, value: 4, to: Date()) ?? Date()
        self._useSemesterDates = State(initialValue: schedule.semesterStartDate != nil && schedule.semesterEndDate != nil)
        self._semesterStartDate = State(initialValue: start)
        self._semesterEndDate = State(initialValue: end)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // DETAILS CARD
                    VStack(alignment: .leading, spacing: 16) {
                        ScheduleEditSectionHeader(title: "Schedule Details", icon: "calendar", color: themeManager.currentTheme.primaryColor)
                        
                        VStack(spacing: 12) {
                            ScheduleIconTextFieldRow(title: "Schedule Name", text: $name, icon: "text.alignleft", placeholder: "e.g., Fall Schedule")
                            ScheduleIconTextFieldRow(title: "Semester", text: $semester, icon: "graduationcap", placeholder: "e.g., Fall 2025")
                        }
                    }
                    .scheduleCardStyle(themeManager)
                    
                    // TYPE CARD
                    VStack(alignment: .leading, spacing: 16) {
                        ScheduleEditSectionHeader(title: "Type", icon: "square.grid.2x2", color: themeManager.currentTheme.secondaryColor)
                        
                        HStack(spacing: 10) {
                            ScheduleTypePill(
                                title: ScheduleType.traditional.displayName,
                                icon: ScheduleType.traditional.icon,
                                isSelected: scheduleType == .traditional,
                                color: themeManager.currentTheme.primaryColor
                            ) {
                                if scheduleType != .traditional {
                                    pendingScheduleType = .traditional
                                    showingTypeSwitchAlert = true
                                }
                            }
                            
                            ScheduleTypePill(
                                title: ScheduleType.rotating.displayName,
                                icon: ScheduleType.rotating.icon,
                                isSelected: scheduleType == .rotating,
                                color: themeManager.currentTheme.secondaryColor
                            ) {
                                if scheduleType != .rotating {
                                    pendingScheduleType = .rotating
                                    showingTypeSwitchAlert = true
                                }
                            }
                        }
                    }
                    .scheduleCardStyle(themeManager)
                    
                    // DATES CARD
                    VStack(alignment: .leading, spacing: 16) {
                        ScheduleEditSectionHeader(title: "Semester Dates", icon: "calendar.badge.clock", color: themeManager.currentTheme.tertiaryColor)
                        
                        Toggle(isOn: $useSemesterDates) {
                            Text("Set semester date range")
                                .font(.forma(.subheadline, weight: .medium))
                        }
                        .tint(themeManager.currentTheme.primaryColor)
                        
                        if useSemesterDates {
                            VStack(spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                    DatePicker("Start", selection: $semesterStartDate, displayedComponents: .date)
                                        .font(.forma(.subheadline))
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.secondary)
                                    DatePicker("End", selection: $semesterEndDate, in: semesterStartDate..., displayedComponents: .date)
                                        .font(.forma(.subheadline))
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
                                
                                if semesterStartDate > semesterEndDate {
                                    Text("End date must be on or after start date")
                                        .font(.forma(.caption))
                                        .foregroundColor(.red)
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .scheduleCardStyle(themeManager)
                    
                    // STATS CARD
                    VStack(alignment: .leading, spacing: 16) {
                        ScheduleEditSectionHeader(title: "Statistics", icon: "chart.bar.xaxis", color: themeManager.currentTheme.primaryColor)
                        
                        HStack(spacing: 12) {
                            ScheduleStatCard(icon: "list.bullet.rectangle", title: "Total Classes", value: "\(schedule.totalClasses)", color: themeManager.currentTheme.primaryColor)
                            ScheduleStatCard(icon: "clock.badge", title: "Weekly Hours", value: String(format: "%.1f", schedule.weeklyHours), color: themeManager.currentTheme.secondaryColor)
                        }
                        
                        HStack(spacing: 12) {
                            ScheduleStatCard(icon: "calendar.badge.plus", title: "Created", value: schedule.createdDate.formatted(date: .abbreviated, time: .omitted), color: themeManager.currentTheme.tertiaryColor)
                            ScheduleStatCard(icon: "arrow.uturn.backward.circle", title: "Last Edited", value: schedule.lastModified.formatted(date: .abbreviated, time: .omitted), color: themeManager.currentTheme.quaternaryColor)
                        }
                    }
                    .scheduleCardStyle(themeManager)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Schedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        var updated = schedule
                        updated.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.semester = semester.trimmingCharacters(in: .whitespacesAndNewlines)
                        updated.color = color
                        updated.scheduleType = scheduleType
                        updated.lastModified = Date()
                        if useSemesterDates {
                            updated.semesterStartDate = Calendar.current.startOfDay(for: semesterStartDate)
                            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: semesterEndDate) ?? semesterEndDate
                            updated.semesterEndDate = endOfDay
                        } else {
                            updated.semesterStartDate = nil
                            updated.semesterEndDate = nil
                        }
                        if willWipeOnSave || scheduleType != schedule.scheduleType {
                            updated.scheduleItems = []
                            updated.enhancedScheduleItems = []
                        }
                        scheduleManager.updateSchedule(updated)
                        dismiss()
                    }
                    .disabled(!isValid)
                    .foregroundColor(isValid ? themeManager.currentTheme.primaryColor : .secondary)
                    .font(.forma(.subheadline, weight: .semibold))
                }
            }
        }
        .alert("Switch schedule type?", isPresented: $showingTypeSwitchAlert) {
            Button("Cancel", role: .cancel) {
                pendingScheduleType = nil
            }
            Button("Switch & Wipe", role: .destructive) {
                if let newType = pendingScheduleType {
                    scheduleType = newType
                    willWipeOnSave = true
                }
                pendingScheduleType = nil
            }
        } message: {
            Text("Changing between Weekly Schedule and Day 1 / Day 2 can cause conflicts. If you proceed, all existing classes in this schedule will be removed. You can add/migrate classes after switching.")
        }
    }
}


private struct ScheduleEditSectionHeader: View {
    let title: String
    let icon: String
    let color: Color
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.forma(.subheadline, weight: .bold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(
                    Circle().fill(color.opacity(0.12))
                        .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1))
                )
            Text(title)
                .font(.forma(.subheadline, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
        }
    }
}

private struct ScheduleIconTextFieldRow: View {
    let title: String
    @Binding var text: String
    let icon: String
    let placeholder: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.secondary)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                TextField(placeholder, text: $text)
                    .font(.forma(.subheadline))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
        }
    }
}

private struct ScheduleTypePill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.forma(.caption, weight: .semibold))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? Color.clear : Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct ScheduleColorSwatchRow: View {
    @Binding var selected: Color
    let theme: AppTheme
    private var palette: [Color] {
        [
            theme.primaryColor, theme.secondaryColor, theme.tertiaryColor, theme.quaternaryColor,
            .blue, .indigo, .teal, .green, .yellow, .orange, .pink, .red, .purple
        ]
    }
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(palette.indices, id: \.self) { idx in
                    let color = palette[idx]
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selected = color
                        }
                    } label: {
                        ZStack {
                            Circle().fill(color).frame(width: 30, height: 30)
                            if UIColor(selected).rgbaString == UIColor(color).rgbaString {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(UIColor(selected).rgbaString == UIColor(color).rgbaString ? Color.white.opacity(0.9) : Color.black.opacity(0.1), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct ScheduleStatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(color.opacity(0.12))
                        .overlay(Circle().stroke(color.opacity(0.25), lineWidth: 1))
                )
            VStack(spacing: 2) {
                Text(value)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
    }
}

private extension View {
    func scheduleCardStyle(_ themeManager: ThemeManager) -> some View {
        self
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
            )
    }
}

private extension UIColor {
    var rgbaString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(r)-\(g)-\(b)-\(a)"
    }
}