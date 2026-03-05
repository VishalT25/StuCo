import Foundation
import SwiftUI
import Combine

/// Simple, robust event manager that uses database as source of truth
/// Uses UPSERT for all saves to prevent duplicates
@MainActor
final class EventManager: ObservableObject {

    // MARK: - Singleton
    static let shared = EventManager()

    // MARK: - Published Properties
    @Published private(set) var events: [Event] = []
    @Published private(set) var categories: [Category] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastSyncTime: Date?

    // MARK: - Dependencies
    private let supabaseService = SupabaseService.shared
    private let authPromptHandler = AuthenticationPromptHandler.shared
    private weak var courseManager: UnifiedCourseManager?

    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        print("EventManager: Initializing...")
        setupAuthObserver()
    }

    // MARK: - Dependency Injection

    func setCourseManager(_ courseManager: UnifiedCourseManager) {
        guard self.courseManager !== courseManager else { return }
        self.courseManager = courseManager
        print("EventManager: CourseManager reference set")
    }

    // MARK: - Auth Observer

    private func setupAuthObserver() {
        supabaseService.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second for auth to settle
                        await self?.loadAll()
                    }
                } else {
                    self?.clearData()
                }
            }
            .store(in: &cancellables)

        // Listen for offline sync completion to refresh data
        NotificationCenter.default.publisher(for: .init("RefreshAllData"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print("EventManager: Received RefreshAllData notification - reloading data")
                Task {
                    await self?.refreshData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API: Load

    /// Load all events and categories from database
    func loadAll() async {
        await loadCategories()
        await loadEvents()
    }

    /// Refresh data from database
    func refreshData() async {
        print("EventManager: Refreshing data...")
        await loadAll()
    }

    /// Load events from database
    func loadEvents() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            print("EventManager: No user ID, cannot load events")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await supabaseService.client
                .from("events")
                .select()
                .eq("user_id", value: userId)
                .order("event_date")
                .execute()

            let dbEvents = try JSONDecoder().decode([DatabaseEvent].self, from: response.data)
            events = dbEvents.map { $0.toLocal() }
            lastSyncTime = Date()

            print("EventManager: Loaded \(events.count) events")
        } catch {
            print("EventManager: Failed to load events: \(error)")
        }
    }

    /// Load categories from database with deduplication
    func loadCategories() async {
        guard let userId = supabaseService.currentUser?.id.uuidString else {
            print("EventManager: No user ID, cannot load categories")
            return
        }

        do {
            let response = try await supabaseService.client
                .from("categories")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false) // Most recent first for dedup
                .execute()

            let dbCategories = try JSONDecoder().decode([DatabaseCategory].self, from: response.data)
            var loadedCategories = dbCategories.map { $0.toLocal() }

            // DEDUPLICATION: Remove duplicate categories for the same course
            // Keep the most recently updated one (already sorted by updated_at DESC)
            var seenCourseIds = Set<UUID>()
            var duplicatesToDelete: [Category] = []

            loadedCategories = loadedCategories.filter { category in
                if let courseId = category.courseId {
                    if seenCourseIds.contains(courseId) {
                        // This is a duplicate - mark for deletion
                        duplicatesToDelete.append(category)
                        return false
                    }
                    seenCourseIds.insert(courseId)
                }
                return true
            }

            // Delete duplicates from database in background
            if !duplicatesToDelete.isEmpty {
                print("EventManager: Found \(duplicatesToDelete.count) duplicate categories, cleaning up...")
                Task {
                    for duplicate in duplicatesToDelete {
                        try? await supabaseService.client
                            .from("categories")
                            .delete()
                            .eq("id", value: duplicate.id.uuidString)
                            .execute()
                    }
                    print("EventManager: Cleaned up \(duplicatesToDelete.count) duplicate categories")
                }
            }

            categories = loadedCategories.sorted { $0.name < $1.name }
            print("EventManager: Loaded \(categories.count) categories")
        } catch {
            print("EventManager: Failed to load categories: \(error)")
        }
    }

    // MARK: - Public API: Events

    /// Save an event (creates or updates via UPSERT)
    func saveEvent(_ event: Event) {
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Save Event",
                description: "save your event"
            ) { [weak self] in
                self?.saveEvent(event)
            }
            return
        }

        guard let userId = supabaseService.currentUser?.id.uuidString else { return }

        // Optimistic update
        let oldEvents = events
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
            events.sort { $0.date < $1.date }
        }

        Task {
            do {
                let dbEvent = DatabaseEvent(from: event, userId: userId)

                _ = try await supabaseService.client
                    .from("events")
                    .upsert(dbEvent)
                    .execute()

                print("EventManager: Saved event '\(event.title)' (completed: \(event.isCompleted))")
            } catch {
                // Rollback on failure
                events = oldEvents
                print("EventManager: Failed to save event '\(event.title)': \(error)")
            }
        }
    }

    /// Toggle completion status of an event
    func toggleCompletion(_ event: Event) {
        var updated = event
        updated.isCompleted.toggle()
        saveEvent(updated)
    }

    /// Mark event as completed
    func completeEvent(_ event: Event) {
        var updated = event
        updated.isCompleted = true
        saveEvent(updated)
    }

    /// Mark event as not completed
    func uncompleteEvent(_ event: Event) {
        var updated = event
        updated.isCompleted = false
        saveEvent(updated)
    }

    /// Delete an event
    func deleteEvent(_ event: Event) {
        // Optimistic update
        let oldEvents = events
        events.removeAll { $0.id == event.id }

        Task {
            do {
                _ = try await supabaseService.client
                    .from("events")
                    .delete()
                    .eq("id", value: event.id.uuidString)
                    .execute()

                print("EventManager: Deleted event '\(event.title)'")
            } catch {
                // Rollback on failure
                events = oldEvents
                print("EventManager: Failed to delete event '\(event.title)': \(error)")
            }
        }
    }

    /// Add event (alias for saveEvent for compatibility)
    func addEvent(_ event: Event) {
        saveEvent(event)
    }

    /// Update event (alias for saveEvent for compatibility)
    func updateEvent(_ event: Event) {
        saveEvent(event)
    }

    // MARK: - Public API: Categories

    /// Save a category (creates or updates via UPSERT)
    /// Prevents duplicates by checking for existing category with same courseId
    func saveCategory(_ category: Category) {
        guard supabaseService.isAuthenticated else {
            authPromptHandler.promptForSignIn(
                title: "Save Category",
                description: "save your category"
            ) { [weak self] in
                self?.saveCategory(category)
            }
            return
        }

        guard let userId = supabaseService.currentUser?.id.uuidString else { return }

        // DUPLICATE PREVENTION: If this category has a courseId, check if one already exists
        var categoryToSave = category
        if let courseId = category.courseId {
            if let existingCategory = categories.first(where: { $0.courseId == courseId && $0.id != category.id }) {
                // A category for this course already exists - update it instead
                print("EventManager: Category for course already exists, updating existing instead of creating new")
                categoryToSave = existingCategory
                categoryToSave.name = category.name
                categoryToSave.color = category.color
                categoryToSave.scheduleId = category.scheduleId
            }
        }

        // Optimistic update
        let oldCategories = categories
        if let index = categories.firstIndex(where: { $0.id == categoryToSave.id }) {
            categories[index] = categoryToSave
        } else {
            categories.append(categoryToSave)
            categories.sort { $0.name < $1.name }
        }

        Task {
            do {
                let dbCategory = DatabaseCategory(from: categoryToSave, userId: userId)

                _ = try await supabaseService.client
                    .from("categories")
                    .upsert(dbCategory)
                    .execute()

                print("EventManager: Saved category '\(categoryToSave.name)'")

                // Sync to course if linked
                await syncCategoryToCourse(categoryToSave)
            } catch {
                // Rollback on failure
                categories = oldCategories
                print("EventManager: Failed to save category '\(categoryToSave.name)': \(error)")
            }
        }
    }

    /// Delete a category
    func deleteCategory(_ category: Category) {
        // Clear category from affected events first
        for event in events where event.categoryId == category.id {
            var updated = event
            updated.categoryId = nil
            saveEvent(updated)
        }

        // Optimistic update
        let oldCategories = categories
        categories.removeAll { $0.id == category.id }

        Task {
            do {
                _ = try await supabaseService.client
                    .from("categories")
                    .delete()
                    .eq("id", value: category.id.uuidString)
                    .execute()

                print("EventManager: Deleted category '\(category.name)'")
            } catch {
                // Rollback on failure
                categories = oldCategories
                print("EventManager: Failed to delete category '\(category.name)': \(error)")
            }
        }
    }

    /// Add category (alias for saveCategory for compatibility)
    func addCategory(_ category: Category) {
        saveCategory(category)
    }

    /// Update category (alias for saveCategory for compatibility)
    func updateCategory(_ category: Category) {
        saveCategory(category)
    }

    /// Async version for when you need to wait for completion
    /// Prevents duplicates by checking for existing category with same courseId
    func addCategoryAsync(_ category: Category) async throws {
        guard supabaseService.isAuthenticated else {
            throw NSError(domain: "EventManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw NSError(domain: "EventManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No user ID"])
        }

        // DUPLICATE PREVENTION: If this category has a courseId, check if one already exists
        var categoryToSave = category
        if let courseId = category.courseId {
            // Check locally first
            if let existingCategory = categories.first(where: { $0.courseId == courseId }) {
                print("EventManager: Category for course already exists locally, updating instead")
                categoryToSave = existingCategory
                categoryToSave.name = category.name
                categoryToSave.color = category.color
                categoryToSave.scheduleId = category.scheduleId
            } else {
                // Also check database to handle race conditions
                let response = try await supabaseService.client
                    .from("categories")
                    .select()
                    .eq("user_id", value: userId)
                    .eq("course_id", value: courseId.uuidString)
                    .limit(1)
                    .execute()

                let existingDbCategories = try JSONDecoder().decode([DatabaseCategory].self, from: response.data)
                if let existingDb = existingDbCategories.first {
                    print("EventManager: Category for course already exists in database, updating instead")
                    categoryToSave = existingDb.toLocal()
                    categoryToSave.name = category.name
                    categoryToSave.color = category.color
                    categoryToSave.scheduleId = category.scheduleId
                }
            }
        }

        // Update local array
        if let index = categories.firstIndex(where: { $0.id == categoryToSave.id }) {
            categories[index] = categoryToSave
        } else {
            categories.append(categoryToSave)
        }
        categories.sort { $0.name < $1.name }

        // Sync to database
        let dbCategory = DatabaseCategory(from: categoryToSave, userId: userId)
        _ = try await supabaseService.client
            .from("categories")
            .upsert(dbCategory)
            .execute()

        print("EventManager: Added/updated category '\(categoryToSave.name)' (async)")
    }

    /// Async version for when you need to wait for completion
    func updateCategoryAsync(_ category: Category) async throws {
        guard supabaseService.isAuthenticated else {
            throw NSError(domain: "EventManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        guard let userId = supabaseService.currentUser?.id.uuidString else {
            throw NSError(domain: "EventManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "No user ID"])
        }

        // Update locally
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
            categories.sort { $0.name < $1.name }
        }

        // Sync to database
        let dbCategory = DatabaseCategory(from: category, userId: userId)
        _ = try await supabaseService.client
            .from("categories")
            .upsert(dbCategory)
            .execute()

        // Sync to course if linked
        await syncCategoryToCourse(category)

        print("EventManager: Updated category '\(category.name)' (async)")
    }

    // MARK: - Query Helpers

    func getEvent(by id: UUID) -> Event? {
        events.first { $0.id == id }
    }

    func getEvents(for date: Date) -> [Event] {
        let calendar = Calendar.current
        return events.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func getEvents(from startDate: Date, to endDate: Date) -> [Event] {
        events.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func getEvents(for courseId: UUID) -> [Event] {
        events.filter { $0.courseId == courseId }
    }

    func getEventsForCategory(_ categoryId: UUID) -> [Event] {
        events.filter { $0.categoryId == categoryId }
    }

    func getIncompleteEvents() -> [Event] {
        events.filter { !$0.isCompleted }
    }

    func getOverdueEvents() -> [Event] {
        let now = Date()
        return events.filter { !$0.isCompleted && $0.date < now }
    }

    func getUpcomingEvents(limit: Int = 10) -> [Event] {
        let now = Date()
        return Array(events
            .filter { !$0.isCompleted && $0.date >= now }
            .prefix(limit))
    }

    func getCategory(by id: UUID) -> Category? {
        categories.first { $0.id == id }
    }

    func getCategory(forCourseId courseId: UUID) -> Category? {
        categories.first { $0.courseId == courseId }
    }

    func getCategoriesForSchedule(_ scheduleId: UUID) -> [Category] {
        categories.filter { $0.scheduleId == scheduleId }
    }

    // MARK: - Computed Properties

    var isEmpty: Bool { events.isEmpty }
    var eventCount: Int { events.count }
    var categoryCount: Int { categories.count }

    // MARK: - Private Helpers

    private func clearData() {
        events.removeAll()
        categories.removeAll()
        lastSyncTime = nil
        print("EventManager: Data cleared")
    }

    /// Sync category changes to linked course
    private func syncCategoryToCourse(_ category: Category) async {
        guard let courseId = category.courseId,
              let courseManager = courseManager,
              let linkedCourse = courseManager.courses.first(where: { $0.id == courseId }) else {
            return
        }

        // Only sync if color actually differs
        if category.color != linkedCourse.color {
            await courseManager.syncCourseFromCategory(
                courseId: courseId,
                newColor: category.color,
                newName: nil
            )
        }
    }
}
