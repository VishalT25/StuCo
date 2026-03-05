import SwiftUI
import Combine

@MainActor
class HierarchicalDataManager: ObservableObject {
    @Published var schedules: [Schedule] = []
    @Published var courses: [Course] = []
    @Published var assignments: [Assignment] = []
    @Published var events: [Event] = []
    @Published var categories: [Category] = []
    
    @Published var activeScheduleId: UUID?
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var syncError: String?
    
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadLocalData()
        setupSupabaseSubscriptions()
        
        // Create default data if none exists
        if schedules.isEmpty {
            createDefaultSchedule()
        }
        
        // Initial sync when authenticated
        Task {
            if supabaseService.isAuthenticated {
                await performFullSync()
            }
        }
    }
    
    // MARK: - Default Setup
    private func createDefaultSchedule() {
        let currentSemester = getCurrentSemester()
        let defaultSchedule = Schedule(name: "My Schedule", semester: currentSemester, isActive: true)
        addSchedule(defaultSchedule)
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
    
    // MARK: - Active Schedule
    var activeSchedule: Schedule? {
        guard let activeId = activeScheduleId else { return schedules.first }
        return schedules.first { $0.id == activeId && !$0.isArchived }
    }
    
    func setActiveSchedule(_ scheduleId: UUID) {
        activeScheduleId = scheduleId
        UserDefaults.standard.set(scheduleId.uuidString, forKey: "activeScheduleId")
    }
    
    // MARK: - Data Relationships
    func courses(for schedule: Schedule) -> [Course] {
        return courses.filter { $0.scheduleId == schedule.id }
    }
    
    func assignments(for course: Course) -> [Assignment] {
        return assignments.filter { $0.courseId == course.id }
    }
    
    func events(for course: Course) -> [Event] {
        return events.filter { $0.courseId == course.id }
    }
    
    func unassignedEvents() -> [Event] {
        return events.filter { $0.courseId == nil }
    }
    
    func allEventsForActiveSchedule() -> [Event] {
        guard let activeSchedule = activeSchedule else { return unassignedEvents() }
        let scheduleCoursesIds = courses(for: activeSchedule).map { $0.id }
        return events.filter { 
            $0.courseId == nil || scheduleCoursesIds.contains($0.courseId ?? UUID())
        }
    }
    
    // MARK: - CRUD Operations
    
    // Schedule Operations
    func addSchedule(_ schedule: Schedule) {
        schedules.append(schedule)
        if activeScheduleId == nil {
            setActiveSchedule(schedule.id)
        }
        saveToSupabase()
    }
    
    func updateSchedule(_ schedule: Schedule) {
        guard let index = schedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        schedules[index] = schedule
        saveToSupabase()
    }
    
    func deleteSchedule(_ schedule: Schedule) {
        // Delete all related courses and their assignments first
        let relatedCourses = courses(for: schedule)
        for course in relatedCourses {
            deleteCourse(course)
        }
        
        schedules.removeAll { $0.id == schedule.id }
        
        // Set new active schedule if needed
        if activeScheduleId == schedule.id {
            activeScheduleId = schedules.first?.id
        }
        
        saveToSupabase()
    }
    
    // Course Operations
    func addCourse(_ course: Course, to schedule: Schedule) {
        var newCourse = course
        newCourse.scheduleId = schedule.id
        courses.append(newCourse)
        saveToSupabase()
    }
    
    func updateCourse(_ course: Course) {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        courses[index] = course
        
        // Update assignments in the separate array to maintain consistency
        syncAssignmentsWithCourse(course)
        
        saveToSupabase()
    }
    
    func deleteCourse(_ course: Course) {
        // Delete all assignments for this course
        assignments.removeAll { $0.courseId == course.id }
        
        // Unassign events from this course (don't delete them)
        for index in events.indices {
            if events[index].courseId == course.id {
                events[index].courseId = nil
            }
        }
        
        courses.removeAll { $0.id == course.id }
        saveToSupabase()
    }
    
    // Assignment Operations
    func addAssignment(_ assignment: Assignment, to course: Course) {
        var newAssignment = assignment
        newAssignment.courseId = course.id
        assignments.append(newAssignment)
        
        // Update the course's assignments array
        if let courseIndex = courses.firstIndex(where: { $0.id == course.id }) {
            courses[courseIndex].assignments.append(newAssignment)
        }
        
        saveToSupabase()
    }
    
    func updateAssignment(_ assignment: Assignment) {
        guard let index = assignments.firstIndex(where: { $0.id == assignment.id }) else { return }
        assignments[index] = assignment
        
        // Update in course's assignments array
        if let courseIndex = courses.firstIndex(where: { $0.id == assignment.courseId }),
           let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) {
            courses[courseIndex].assignments[assignmentIndex] = assignment
        }
        
        saveToSupabase()
    }
    
    func deleteAssignment(_ assignment: Assignment) {
        assignments.removeAll { $0.id == assignment.id }
        
        // Remove from course's assignments array
        if let courseIndex = courses.firstIndex(where: { $0.id == assignment.courseId }) {
            courses[courseIndex].assignments.removeAll { $0.id == assignment.id }
        }
        
        saveToSupabase()
    }
    
    // Helper method to sync assignments between the separate array and course's embedded array
    private func syncAssignmentsWithCourse(_ course: Course) {
        let courseAssignments = assignments.filter { $0.courseId == course.id }
        
        if let courseIndex = courses.firstIndex(where: { $0.id == course.id }) {
            courses[courseIndex].assignments = courseAssignments
        }
    }
    
    // Event Operations
    func addEvent(_ event: Event) {
        events.append(event)
        saveToSupabase()
    }
    
    func updateEvent(_ event: Event) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index] = event
        saveToSupabase()
    }
    
    func deleteEvent(_ event: Event) {
        events.removeAll { $0.id == event.id }
        saveToSupabase()
    }
    
    func assignEventToCourse(_ event: Event, course: Course?) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        events[index].courseId = course?.id
        saveToSupabase()
    }
    
    // Category Operations
    func addCategory(_ category: Category) {
        categories.append(category)
        saveToSupabase()
    }
    
    func updateCategory(_ category: Category) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index] = category
        saveToSupabase()
    }
    
    func deleteCategory(_ category: Category) {
        categories.removeAll { $0.id == category.id }
        saveToSupabase()
    }
    
    // MARK: - Data Persistence
    private func loadLocalData() {
        // Load from UserDefaults as fallback
        loadSchedules()
        loadCourses()
        loadAssignments()
        loadEvents()
        loadCategories()
        
        // Sync assignments with courses after loading
        syncAllAssignments()
        
        // Load active schedule
        if let activeIdString = UserDefaults.standard.string(forKey: "activeScheduleId"),
           let activeId = UUID(uuidString: activeIdString) {
            activeScheduleId = activeId
        }
    }
    
    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: "hierarchical_schedules"),
           let decoded = try? JSONDecoder().decode([Schedule].self, from: data) {
            schedules = decoded
        }
    }
    
    private func loadCourses() {
        if let data = UserDefaults.standard.data(forKey: "hierarchical_courses"),
           let decoded = try? JSONDecoder().decode([Course].self, from: data) {
            courses = decoded
        }
    }
    
    private func loadAssignments() {
        if let data = UserDefaults.standard.data(forKey: "hierarchical_assignments"),
           let decoded = try? JSONDecoder().decode([Assignment].self, from: data) {
            assignments = decoded
        }
    }
    
    private func loadEvents() {
        if let data = UserDefaults.standard.data(forKey: "hierarchical_events"),
           let decoded = try? JSONDecoder().decode([Event].self, from: data) {
            events = decoded
        }
    }
    
    private func loadCategories() {
        if let data = UserDefaults.standard.data(forKey: "hierarchical_categories"),
           let decoded = try? JSONDecoder().decode([Category].self, from: data) {
            categories = decoded
        }
    }
    
    private func syncAllAssignments() {
        // Sync assignments from separate array into courses
        for courseIndex in courses.indices {
            let courseAssignments = assignments.filter { $0.courseId == courses[courseIndex].id }
            courses[courseIndex].assignments = courseAssignments
        }
    }
    
    private func saveToSupabase() {
        // Save to UserDefaults immediately for offline access
        saveToLocal()
        
        // Sync with Supabase if authenticated
        Task {
            await syncWithSupabase()
        }
    }
    
    private func saveToLocal() {
        if let schedulesData = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(schedulesData, forKey: "hierarchical_schedules")
        }
        
        if let coursesData = try? JSONEncoder().encode(courses) {
            UserDefaults.standard.set(coursesData, forKey: "hierarchical_courses")
        }
        
        if let assignmentsData = try? JSONEncoder().encode(assignments) {
            UserDefaults.standard.set(assignmentsData, forKey: "hierarchical_assignments")
        }
        
        if let eventsData = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(eventsData, forKey: "hierarchical_events")
        }
        
        if let categoriesData = try? JSONEncoder().encode(categories) {
            UserDefaults.standard.set(categoriesData, forKey: "hierarchical_categories")
        }
    }
    
    // MARK: - Supabase Sync Implementation
    
    private func syncWithSupabase() async {
        guard supabaseService.isAuthenticated else {
             ("🔄 Not authenticated, skipping sync")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            // Ensure token is valid
            await supabaseService.ensureValidToken()
            
            // Sync all data types
            try await syncSchedulesToSupabase()
            try await syncCategoriesToSupabase()
            try await syncCoursesToSupabase()
            try await syncAssignmentsToSupabase()
            try await syncEventsToSupabase()
            
            await MainActor.run {
                lastSyncTime = Date()
                 ("🔄 Successfully synced all data to Supabase")
            }
        } catch {
            await MainActor.run {
                syncError = "Sync failed: \(error.localizedDescription)"
            }
             ("🔄 Sync failed: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Individual Sync Operations
    
    private func syncSchedulesToSupabase() async throws {
        guard let currentUserId = supabaseService.currentUser?.id else {
            throw NSError(domain: "SyncError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        for schedule in schedules {
            let scheduleData = SupabaseScheduleInsert(
                id: schedule.id.uuidString,
                user_id: currentUserId.uuidString,
                name: schedule.name,
                semester: schedule.semester,
                is_active: schedule.isActive,
                is_archived: schedule.isArchived,
                color_hex: schedule.colorHex,
                schedule_type: "traditional", // Default to traditional schedule type
                academic_calendar_id: schedule.academicCalendarId?.uuidString,
                created_date: schedule.createdDate.toISOString(),
                last_modified: schedule.lastModified.toISOString()
            )
            
            _ = try await supabaseService.database
                .from("schedules")
                .upsert(scheduleData)
                .execute()
        }
    }
    
    private func syncCategoriesToSupabase() async throws {
        guard let currentUserId = supabaseService.currentUser?.id else {
            throw NSError(domain: "SyncError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        for category in categories {
            let categoryData = SupabaseCategoryInsert(
                id: category.id.uuidString,
                user_id: currentUserId.uuidString,
                name: category.name,
                color_hex: UIColor(category.color).toHex() ?? "007AFF"
            )
            
            _ = try await supabaseService.database
                .from("categories")
                .upsert(categoryData)
                .execute()
        }
    }
    
    private func syncCoursesToSupabase() async throws {
        guard let currentUserId = supabaseService.currentUser?.id else {
            throw NSError(domain: "SyncError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        for course in courses {
            let courseData = SupabaseCourseInsert(
                id: course.id.uuidString,
                schedule_id: course.scheduleId.uuidString,
                user_id: currentUserId.uuidString,
                name: course.name,
                icon_name: course.iconName,
                color_hex: course.colorHex,
                final_grade_goal: course.finalGradeGoal.isEmpty ? nil : course.finalGradeGoal,
                weight_of_remaining_tasks: course.weightOfRemainingTasks.isEmpty ? nil : course.weightOfRemainingTasks
            )
            
            _ = try await supabaseService.database
                .from("courses")
                .upsert(courseData)
                .execute()
        }
    }
    
    private func syncAssignmentsToSupabase() async throws {
        for assignment in assignments {
            let assignmentData = SupabaseAssignmentInsert(
                id: assignment.id.uuidString,
                course_id: assignment.courseId.uuidString,
                name: assignment.name,
                grade: assignment.grade.isEmpty ? nil : assignment.grade,
                weight: assignment.weight.isEmpty ? nil : assignment.weight
            )
            
            _ = try await supabaseService.database
                .from("assignments")
                .upsert(assignmentData)
                .execute()
        }
    }
    
    private func syncEventsToSupabase() async throws {
        guard let currentUserId = supabaseService.currentUser?.id else {
            throw NSError(domain: "SyncError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        for event in events {
            let eventData = SupabaseEventInsert(
                id: event.id.uuidString,
                user_id: currentUserId.uuidString,
                course_id: event.courseId?.uuidString,
                title: event.title,
                description: event.description,
                event_date: event.date.toISOString(),
                is_completed: event.isCompleted,
                notes: event.notes,
                event_type: event.eventType.rawValue,
                reminder_time: event.reminderTime.rawValue,
                category_id: event.categoryId?.uuidString,
                external_identifier: event.externalIdentifier,
                source_name: event.sourceName,
                sync_to_apple_calendar: event.syncToAppleCalendar,
                sync_to_google_calendar: event.syncToGoogleCalendar
            )
            
            _ = try await supabaseService.database
                .from("events")
                .upsert(eventData)
                .execute()
        }
    }
    
    // MARK: - Full Sync from Supabase
    
    func performFullSync() async {
        guard supabaseService.isAuthenticated else {
             ("🔄 Not authenticated, skipping full sync")
            return
        }
        
        await MainActor.run {
            isSyncing = true
            syncError = nil
        }
        
        do {
            await supabaseService.ensureValidToken()
            
            // Load all data from Supabase
            let fetchedSchedules = try await loadSchedulesFromSupabase()
            let fetchedCategories = try await loadCategoriesFromSupabase()
            let fetchedCourses = try await loadCoursesFromSupabase()
            let fetchedAssignments = try await loadAssignmentsFromSupabase()
            let fetchedEvents = try await loadEventsFromSupabase()
            
            await MainActor.run {
                // Update local data with fetched data
                schedules = fetchedSchedules
                categories = fetchedCategories
                courses = fetchedCourses
                assignments = fetchedAssignments
                events = fetchedEvents
                
                // Sync assignments with courses
                syncAllAssignments()
                
                // Save to local storage
                saveToLocal()
                
                lastSyncTime = Date()
                 ("🔄 Successfully loaded data from Supabase")
            }
        } catch {
            await MainActor.run {
                syncError = "Load failed: \(error.localizedDescription)"
            }
             ("🔄 Load from Supabase failed: \(error)")
        }
        
        await MainActor.run {
            isSyncing = false
        }
    }
    
    // MARK: - Load Operations from Supabase
    
    private func loadSchedulesFromSupabase() async throws -> [Schedule] {
        let response = try await supabaseService.database
            .from("schedules")
            .select()
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let rows = try decoder.decode([SupabaseSchedule].self, from: data)
        return rows.map { $0.toSchedule() }
    }
    
    private func loadCategoriesFromSupabase() async throws -> [Category] {
        let response = try await supabaseService.database
            .from("categories")
            .select()
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        
        let rows = try decoder.decode([SupabaseCategory].self, from: data)
        return rows.map { $0.toCategory() }
    }
    
    private func loadCoursesFromSupabase() async throws -> [Course] {
        let response = try await supabaseService.database
            .from("courses")
            .select()
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        
        let rows = try decoder.decode([SupabaseCourse].self, from: data)
        return rows.map { $0.toCourse() }
    }
    
    private func loadAssignmentsFromSupabase() async throws -> [Assignment] {
        let response = try await supabaseService.database
            .from("assignments")
            .select()
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        
        let rows = try decoder.decode([SupabaseAssignment].self, from: data)
        return rows.map { $0.toAssignment() }
    }
    
    private func loadEventsFromSupabase() async throws -> [Event] {
        let response = try await supabaseService.database
            .from("events")
            .select()
            .execute()
        
        let data = response.data
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let rows = try decoder.decode([SupabaseEvent].self, from: data)
        return rows.compactMap { $0.toEvent() }
    }
    
    // MARK: - Supabase Subscriptions
    
    private func setupSupabaseSubscriptions() {
        // Listen for authentication state changes
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { @MainActor in
                        await self?.performFullSync()
                    }
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supabase Insert Data Transfer Objects

struct SupabaseScheduleInsert: Encodable {
    let id: String
    let user_id: String
    let name: String
    let semester: String
    let is_active: Bool
    let is_archived: Bool
    let color_hex: String
    let schedule_type: String
    let academic_calendar_id: String?
    let created_date: String
    let last_modified: String
}

struct SupabaseCategoryInsert: Encodable {
    let id: String
    let user_id: String
    let name: String
    let color_hex: String
}

struct SupabaseCourseInsert: Encodable {
    let id: String
    let schedule_id: String?
    let user_id: String
    let name: String
    let icon_name: String
    let color_hex: String
    let final_grade_goal: String?
    let weight_of_remaining_tasks: String?
}

struct SupabaseAssignmentInsert: Encodable {
    let id: String
    let course_id: String?
    let name: String
    let grade: String?
    let weight: String?
}

struct SupabaseEventInsert: Encodable {
    let id: String
    let user_id: String
    let course_id: String?
    let title: String
    let description: String?
    let event_date: String
    let is_completed: Bool
    let notes: String?
    let event_type: String
    let reminder_time: Int
    let category_id: String?
    let external_identifier: String?
    let source_name: String?
    let sync_to_apple_calendar: Bool
    let sync_to_google_calendar: Bool
}

// MARK: - Supabase Data Transfer Objects

struct SupabaseSchedule: Codable {
    let id: String
    let user_id: String
    let name: String
    let semester: String
    let is_active: Bool
    let is_archived: Bool
    let color_hex: String
    let schedule_type: String
    let academic_calendar_id: String?
    let created_date: String?
    let last_modified: String?
    
    func toSchedule() -> Schedule {
        var schedule = Schedule(name: name, semester: semester, isActive: is_active)
        schedule.id = UUID(uuidString: id) ?? UUID()
        schedule.isArchived = is_archived
        schedule.colorHex = color_hex
        // Note: ignoring schedule_type since local Schedule doesn't have this property
        schedule.academicCalendarId = academic_calendar_id.flatMap { UUID(uuidString: $0) }
        
        if let createdDateString = created_date {
            schedule.createdDate = ISO8601DateFormatter().date(from: createdDateString) ?? Date()
        }
        if let lastModifiedString = last_modified {
            schedule.lastModified = ISO8601DateFormatter().date(from: lastModifiedString) ?? Date()
        }
        
        return schedule
    }
}

struct SupabaseCategory: Codable {
    let id: String
    let user_id: String
    let name: String
    let color_hex: String
    
    func toCategory() -> Category {
        let color = Color(hex: color_hex) ?? .blue
        var category = Category(name: name, color: color)
        category.id = UUID(uuidString: id) ?? UUID()
        return category
    }
}

struct SupabaseCourse: Codable {
    let id: String
    let schedule_id: String?
    let user_id: String
    let name: String
    let icon_name: String
    let color_hex: String
    let final_grade_goal: String?
    let weight_of_remaining_tasks: String?
    
    func toCourse() -> Course {
        let scheduleId = schedule_id.flatMap { UUID(uuidString: $0) } ?? UUID()
        let course = Course(
            id: UUID(uuidString: id) ?? UUID(),
            scheduleId: scheduleId,
            name: name,
            iconName: icon_name,
            colorHex: color_hex,
            assignments: [], // Will be populated separately
            finalGradeGoal: final_grade_goal ?? "",
            weightOfRemainingTasks: weight_of_remaining_tasks ?? ""
        )
        return course
    }
}

struct SupabaseAssignment: Codable {
    let id: String
    let course_id: String?
    let name: String
    let grade: String?
    let weight: String?
    
    func toAssignment() -> Assignment {
        return Assignment(
            id: UUID(uuidString: id) ?? UUID(),
            courseId: course_id.flatMap { UUID(uuidString: $0) } ?? UUID(),
            name: name,
            grade: grade ?? "",
            weight: weight ?? ""
        )
    }
}

struct SupabaseEvent: Codable {
    let id: String
    let user_id: String
    let course_id: String?
    let title: String
    let description: String?
    let event_date: String
    let is_completed: Bool
    let notes: String?
    let event_type: String
    let reminder_time: Int
    let category_id: String?
    let external_identifier: String?
    let source_name: String?
    let sync_to_apple_calendar: Bool
    let sync_to_google_calendar: Bool
    
    func toEvent() -> Event? {
        guard let date = ISO8601DateFormatter().date(from: event_date) else {
            return nil
        }
        
        var event = Event(
            title: title,
            date: date,
            courseId: course_id.flatMap { UUID(uuidString: $0) },
            categoryId: category_id.flatMap { UUID(uuidString: $0) },
            reminderTime: ReminderTime(rawValue: reminder_time) ?? .none,
            isCompleted: is_completed,
            externalIdentifier: external_identifier,
            sourceName: source_name,
            syncToAppleCalendar: sync_to_apple_calendar,
            syncToGoogleCalendar: sync_to_google_calendar
        )
        
        event.id = UUID(uuidString: id) ?? UUID()
        event.description = description
        event.notes = notes
        
        if let eventType = Event.EventType(rawValue: event_type) {
            event.eventType = eventType
        }
        
        return event
    }
}

// MARK: - Extensions

extension UIColor {
    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}