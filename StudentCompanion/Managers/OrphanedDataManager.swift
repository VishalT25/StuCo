import SwiftUI
import Foundation

// MARK: - Orphaned Data Detection

struct OrphanedDataResult {
    let orphanedCourses: [Course]
    let orphanedScheduleItems: [ScheduleItemWithScheduleID]
    
    var hasOrphanedData: Bool {
        return !orphanedCourses.isEmpty || !orphanedScheduleItems.isEmpty
    }
    
    var totalOrphaned: Int {
        return orphanedCourses.count + orphanedScheduleItems.count
    }
}

struct ScheduleItemWithScheduleID {
    let scheduleItem: ScheduleItem
    let scheduleId: UUID
    let scheduleName: String
}

class OrphanedDataDetector {
    static func detectOrphanedData(courses: [Course], schedules: [ScheduleCollection]) -> OrphanedDataResult {
        let scheduleIds = Set(schedules.map { $0.id })
        let courseIds = Set(courses.map { $0.id })
        
        // Find courses without valid schedules
        let orphanedCourses = courses.filter { course in
            !scheduleIds.contains(course.scheduleId)
        }
        
        // Find schedule items without corresponding courses
        var orphanedScheduleItems: [ScheduleItemWithScheduleID] = []
        
        for schedule in schedules {
            for scheduleItem in schedule.scheduleItems {
                if !courseIds.contains(scheduleItem.id) {
                    orphanedScheduleItems.append(
                        ScheduleItemWithScheduleID(
                            scheduleItem: scheduleItem,
                            scheduleId: schedule.id,
                            scheduleName: schedule.displayName
                        )
                    )
                }
            }
        }
        
        return OrphanedDataResult(
            orphanedCourses: orphanedCourses,
            orphanedScheduleItems: orphanedScheduleItems
        )
    }
}

// MARK: - Conflict Resolution Types

enum OrphanResolutionAction {
    case assignCourseToActiveSchedule(Course)
    case createScheduleForCourse(Course)
    case createCourseFromScheduleItem(ScheduleItemWithScheduleID)
    case mergeScheduleItemWithCourse(ScheduleItemWithScheduleID, Course)
    case deleteOrphanedCourse(Course)
    case deleteOrphanedScheduleItem(ScheduleItemWithScheduleID)
}

// MARK: - Data Conflict Resolution View

struct DataConflictResolutionView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @Environment(\.dismiss) var dismiss
    
    let orphanedData: OrphanedDataResult
    let onResolution: (OrphanResolutionAction) -> Void
    
    @State private var resolutions: [OrphanResolutionAction] = []
    @State private var currentStep = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerView
                
                ScrollView {
                    VStack(spacing: 24) {
                        summaryCard
                        
                        if !orphanedData.orphanedCourses.isEmpty {
                            orphanedCoursesSection
                        }
                        
                        if !orphanedData.orphanedScheduleItems.isEmpty {
                            orphanedScheduleItemsSection
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Resolve Conflicts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply All") {
                        applyResolutions()
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .disabled(resolutions.isEmpty)
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Data Sync Issues Found")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("We found \(orphanedData.totalOrphaned) item(s) that need your attention")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
    
    private var summaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Summary")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            VStack(spacing: 12) {
                if !orphanedData.orphanedCourses.isEmpty {
                    HStack {
                        Image(systemName: "book.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        
                        Text("\(orphanedData.orphanedCourses.count) course(s) not linked to any schedule")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
                
                if !orphanedData.orphanedScheduleItems.isEmpty {
                    HStack {
                        Image(systemName: "calendar.fill")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        Text("\(orphanedData.orphanedScheduleItems.count) schedule item(s) not linked to any course")
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var orphanedCoursesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Courses Without Schedules")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(orphanedData.orphanedCourses.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(orphanedData.orphanedCourses, id: \.id) { course in
                    OrphanedCourseCard(
                        course: course,
                        onResolution: { resolution in
                            resolutions.append(resolution)
                        }
                    )
                    .environmentObject(themeManager)
                    .environmentObject(scheduleManager)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var orphanedScheduleItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Schedule Items Without Courses")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(orphanedData.orphanedScheduleItems.count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(orphanedData.orphanedScheduleItems, id: \.scheduleItem.id) { item in
                    OrphanedScheduleItemCard(
                        item: item,
                        availableCourses: orphanedData.orphanedCourses,
                        onResolution: { resolution in
                            resolutions.append(resolution)
                        }
                    )
                    .environmentObject(themeManager)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func applyResolutions() {
        for resolution in resolutions {
            onResolution(resolution)
        }
    }
}

// MARK: - Orphaned Course Card

struct OrphanedCourseCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    
    let course: Course
    let onResolution: (OrphanResolutionAction) -> Void
    
    @State private var selectedAction: CourseResolutionAction = .assignToActive
    
    enum CourseResolutionAction: CaseIterable {
        case assignToActive
        case createNewSchedule
        case delete
        
        var title: String {
            switch self {
            case .assignToActive: return "Add to Active Schedule"
            case .createNewSchedule: return "Create New Schedule"
            case .delete: return "Delete Course"
            }
        }
        
        var icon: String {
            switch self {
            case .assignToActive: return "plus.circle"
            case .createNewSchedule: return "calendar.badge.plus"
            case .delete: return "trash"
            }
        }
        
        var color: Color {
            switch self {
            case .assignToActive: return .green
            case .createNewSchedule: return .blue
            case .delete: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Course info
            HStack(spacing: 12) {
                Image(systemName: course.iconName)
                    .font(.title2)
                    .foregroundColor(course.color)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(course.color.opacity(0.15))
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(course.name)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                    
                    Text("\(course.assignments.count) assignment(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Resolution options
            VStack(spacing: 8) {
                ForEach(CourseResolutionAction.allCases, id: \.self) { action in
                    Button(action: {
                        selectedAction = action
                        applyAction(action)
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: action.icon)
                                .font(.subheadline)
                                .foregroundColor(action.color)
                                .frame(width: 20)
                            
                            Text(action.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedAction == action {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.bold())
                                    .foregroundColor(action.color)
                            }
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedAction == action ? action.color.opacity(0.1) : Color(.systemGray6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedAction == action ? action.color.opacity(0.3) : Color.clear, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func applyAction(_ action: CourseResolutionAction) {
        switch action {
        case .assignToActive:
            onResolution(.assignCourseToActiveSchedule(course))
        case .createNewSchedule:
            onResolution(.createScheduleForCourse(course))
        case .delete:
            onResolution(.deleteOrphanedCourse(course))
        }
    }
}

// MARK: - Orphaned Schedule Item Card

struct OrphanedScheduleItemCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let item: ScheduleItemWithScheduleID
    let availableCourses: [Course]
    let onResolution: (OrphanResolutionAction) -> Void
    
    @State private var selectedAction: ScheduleItemResolutionAction = .createCourse
    @State private var selectedCourseId: UUID?

    enum ScheduleItemResolutionAction: CaseIterable {
        case createCourse
        case mergWithCourse
        case delete
        
        var title: String {
            switch self {
            case .createCourse: return "Create Course"
            case .mergWithCourse: return "Merge with Course"
            case .delete: return "Delete Schedule Item"
            }
        }
        
        var icon: String {
            switch self {
            case .createCourse: return "plus.circle"
            case .mergWithCourse: return "arrow.triangle.merge"
            case .delete: return "trash"
            }
        }
        
        var color: Color {
            switch self {
            case .createCourse: return .green
            case .mergWithCourse: return .blue
            case .delete: return .red
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            scheduleItemInfoView
            resolutionOptionsView
        }
        .padding(16)
        .background(cardBackground)
    }
    
    private var scheduleItemInfoView: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.scheduleItem.color)
                .frame(width: 4, height: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.scheduleItem.title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text("In: \(item.scheduleName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(item.scheduleItem.timeRange)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var resolutionOptionsView: some View {
        VStack(spacing: 8) {
            ForEach(ScheduleItemResolutionAction.allCases, id: \.self) { action in
                actionButton(for: action)
            }
            
            if selectedAction == .mergWithCourse && !availableCourses.isEmpty {
                coursePickerView
            }
        }
    }
    
    private func actionButton(for action: ScheduleItemResolutionAction) -> some View {
        Button(action: {
            selectedAction = action
            applyAction(action)
        }) {
            HStack(spacing: 12) {
                Image(systemName: action.icon)
                    .font(.subheadline)
                    .foregroundColor(action.color)
                    .frame(width: 20)
                
                Text(action.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if selectedAction == action {
                    Image(systemName: "checkmark")
                        .font(.subheadline.bold())
                        .foregroundColor(action.color)
                }
            }
            .padding(12)
            .background(actionButtonBackground(for: action))
        }
        .buttonStyle(.plain)
    }
    
    private func actionButtonBackground(for action: ScheduleItemResolutionAction) -> some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(selectedAction == action ? action.color.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selectedAction == action ? action.color.opacity(0.3) : Color.clear, lineWidth: 1)
            )
    }
    
    private var coursePickerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select course to merge with:")
                .font(.caption.weight(.medium))
                .foregroundColor(.secondary)
            
            Picker("Course", selection: $selectedCourseId) {
                Text("Select a course").tag(UUID?.none)
                ForEach(availableCourses, id: \.id) { course in
                    Text(course.name).tag(UUID?.some(course.id))
                }
            }
            .pickerStyle(.menu)
        }
        .padding(.top, 8)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(.systemGray6).opacity(0.5))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
    }
    
    private func applyAction(_ action: ScheduleItemResolutionAction) {
        switch action {
        case .createCourse:
            onResolution(.createCourseFromScheduleItem(item))
        case .mergWithCourse:
            if let courseId = selectedCourseId,
               let course = availableCourses.first(where: { $0.id == courseId }) {
                onResolution(.mergeScheduleItemWithCourse(item, course))
            }
        case .delete:
            onResolution(.deleteOrphanedScheduleItem(item))
        }
    }
}

#Preview {
    let sampleOrphanedData = OrphanedDataResult(
        orphanedCourses: [
            Course(scheduleId: UUID(), name: "Psychology 101"),
            Course(scheduleId: UUID(), name: "Mathematics")
        ],
        orphanedScheduleItems: []
    )

    DataConflictResolutionView(orphanedData: sampleOrphanedData) { _ in }
        .environmentObject(ThemeManager())
        .environmentObject(UnifiedCourseManager())
        .environmentObject(ScheduleManager())
}