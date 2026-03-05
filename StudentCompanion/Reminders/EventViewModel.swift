import SwiftUI
import Combine

@MainActor
class EventViewModel: ObservableObject {
    // Delegate data management to EventManager (simple, robust replacement)
    private var eventManager: EventManager { EventManager.shared }

    @Published var schedules: [ScheduleItem] = []
    @Published var scheduleItems: [ScheduleItem] = []
    @Published var isRefreshing: Bool = false
    @Published var lastRefreshTime: Date?
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var selectedCategoryFilter: UUID? = {
        guard let str = UserDefaults.standard.string(forKey: "selectedCategoryFilter") else { return nil }
        return UUID(uuidString: str)
    }() {
        didSet {
            if let id = selectedCategoryFilter {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedCategoryFilter")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedCategoryFilter")
            }
        }
    }

    private var isUpdatingCoursesFromNotification = false
    @Published var courses: [Course] = [] {
        didSet {
            if !isUpdatingCoursesFromNotification {
                updateSmartEngineWithCourses()
            }
        }
    }

    // @Published arrays that sync with EventManager for proper SwiftUI updates
    @Published private(set) var categories: [Category] = []
    @Published private(set) var events: [Event] = []

    // MARK: - Schedule Manager Reference
    @Published var scheduleManager: ScheduleManager?

    // MARK: - Category Grouping

    // PERFORMANCE FIX: Removed excessive debug prints from these frequently-called functions
    func groupedCategories(activeScheduleId: UUID?) -> [CategoryGroup] {
        guard let scheduleManager = scheduleManager else {
            return []
        }

        var groups: [CategoryGroup] = []

        for schedule in scheduleManager.scheduleCollections {
            let scheduleCategories = categories.filter { $0.scheduleId == schedule.id }

            if !scheduleCategories.isEmpty {
                let group = CategoryGroup(
                    scheduleName: schedule.name,
                    scheduleId: schedule.id,
                    categories: scheduleCategories.sorted { $0.name < $1.name }
                )
                groups.append(group)
            }
        }

        // Sort: active schedule first, then alphabetically
        groups.sort { group1, group2 in
            if group1.scheduleId == activeScheduleId { return true }
            if group2.scheduleId == activeScheduleId { return false }
            return group1.scheduleName < group2.scheduleName
        }

        return groups
    }

    func activeScheduleCategories(activeScheduleId: UUID?) -> [Category] {
        guard let activeId = activeScheduleId else {
            return []
        }

        return categories.filter { $0.scheduleId == activeId }.sorted { $0.name < $1.name }
    }

    func unlinkedCategories() -> [Category] {
        return categories.filter { $0.scheduleId == nil }.sorted { $0.name < $1.name }
    }
    
    private let scheduleKey = "savedSchedule"
    private let coursesKey = "savedCourses"
    private let notificationManager = NotificationManager.shared

    private var calendarSyncManager: CalendarSyncManager?

    private var cancellables = Set<AnyCancellable>()

    // PERFORMANCE FIX: Debounce rapid updates to prevent cascading re-renders
    private var eventUpdateSubject = PassthroughSubject<[Event], Never>()
    private var categoryUpdateSubject = PassthroughSubject<[Category], Never>()
    
    private func updateSmartEngineWithCourses() {
        let courseNames = courses.map { $0.name }
    }
    
    init() {
        print(" EventViewModel: Initializing with EventManager...")

        // CRITICAL: Set up observers to sync @Published arrays with EventManager
        // This ensures SwiftUI properly tracks changes and re-renders views
        setupDataSyncObservers()

        loadSchedules()
        loadCourses()

        // Force EventManager to load data immediately
        Task {
            await notificationManager.requestAuthorization()

            print(" EventViewModel: Triggering EventManager to load data...")
            await eventManager.refreshData()

            // After refresh, sync the data
            await MainActor.run {
                self.syncDataFromOperationsManager()
            }
        }

        NotificationCenter.default.publisher(for: .googleCalendarEventsFetched)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.processFetchedGoogleCalendarEvents()
                }
            }
            .store(in: &cancellables)

        // Listen for data clearing when user signs out
        NotificationCenter.default.publisher(for: .init("UserDataCleared"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print(" EventViewModel: Received UserDataCleared notification")
                self?.clearScheduleData()
            }
            .store(in: &cancellables)

        // Listen for offline sync completion to refresh data
        NotificationCenter.default.publisher(for: .init("RefreshAllData"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                print(" EventViewModel: Received RefreshAllData notification - syncing from manager")
                Task {
                    await self?.refreshLiveData()
                }
            }
            .store(in: &cancellables)

        print(" EventViewModel: Initialization complete (delegating to EventManager)")
    }

    // MARK: - Data Sync Setup

    private func setupDataSyncObservers() {
        // PERFORMANCE FIX: Use debounced updates to batch rapid changes and prevent UI freezing
        // This is critical for preventing cascading re-renders when swiping between tabs

        // Set up debounced event updates (100ms debounce to batch rapid changes)
        eventUpdateSubject
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] newEvents in
                guard let self = self else { return }
                // Only update if actually different (simple count + first/last ID check for efficiency)
                let isDifferent = self.events.count != newEvents.count ||
                    self.events.first?.id != newEvents.first?.id ||
                    self.events.last?.id != newEvents.last?.id ||
                    self.hasSignificantChanges(old: self.events, new: newEvents)

                if isDifferent {
                    self.events = newEvents
                }
            }
            .store(in: &cancellables)

        // Set up debounced category updates
        categoryUpdateSubject
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] newCategories in
                guard let self = self else { return }
                if self.categories.count != newCategories.count ||
                   self.categories.map(\.id) != newCategories.map(\.id) {
                    self.categories = newCategories
                }
            }
            .store(in: &cancellables)

        // Observe events changes from EventManager - forward to debounced subject
        eventManager.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newEvents in
                self?.eventUpdateSubject.send(newEvents)
            }
            .store(in: &cancellables)

        // Observe categories changes from EventManager - forward to debounced subject
        eventManager.$categories
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newCategories in
                self?.categoryUpdateSubject.send(newCategories)
            }
            .store(in: &cancellables)

        // Immediately sync any existing data
        syncDataFromOperationsManager()
    }

    /// PERFORMANCE FIX: Efficient change detection - only check a sample of events
    /// instead of comparing every single property of every event
    private func hasSignificantChanges(old: [Event], new: [Event]) -> Bool {
        guard old.count == new.count else { return true }
        guard !old.isEmpty else { return false }

        // Check first, middle, and last events for changes (O(1) instead of O(n))
        let indices = [0, old.count / 2, old.count - 1]
        for i in indices {
            let oldEvent = old[i]
            let newEvent = new[i]
            if oldEvent.id != newEvent.id ||
               oldEvent.isCompleted != newEvent.isCompleted ||
               oldEvent.title != newEvent.title {
                return true
            }
        }
        return false
    }

    /// Manually sync data from EventManager to @Published arrays
    private func syncDataFromOperationsManager() {
        let newEvents = eventManager.events
        let newCategories = eventManager.categories

        print(" EventViewModel: Syncing data - Events: \(newEvents.count), Categories: \(newCategories.count)")

        self.events = newEvents
        self.categories = newCategories
    }
    
    // MARK: - Data Clearing
    
    private func clearScheduleData() {
        print(" EventViewModel: Clearing schedule data")
        schedules.removeAll()
        scheduleItems.removeAll()
        courses.removeAll()
        
        // Save empty state
        saveScheduleDataLocally()
        
        print(" EventViewModel: Schedule data cleared")
    }
    
    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: scheduleKey),
           let decodedScheduleItems = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
            scheduleItems = decodedScheduleItems
        }
    }
    
    private func loadCourses() {
        if let data = UserDefaults.standard.data(forKey: coursesKey),
           let decodedCourses = try? JSONDecoder().decode([Course].self, from: data) {
            courses = decodedCourses
        }
    }
    
    private func registerDefaultIntegrationToggles() {
        UserDefaults.standard.register(defaults: [
            "GoogleCalendarIntegrationEnabled": false,
            "AppleCalendarIntegrationEnabled": false,
            "NotificationIntegrationEnabled": true
        ])
    }
    
    private func setupCalendarSyncSubscriptions() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.refreshLiveData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func processFetchedGoogleCalendarEvents() async {
        await refreshLiveData()
    }
    
    private func handleCalendarSyncOnUpdate(oldEvent: Event, newEvent: Event) {
        // Google Calendar sync can be implemented here in the future
    }
    
    @MainActor
    func refreshLiveData() async {
        isRefreshing = true

        print(" EventViewModel: Delegating refreshLiveData to EventManager...")

        // Delegate to EventManager
        await eventManager.refreshData()

        // Sync data after refresh completes
        syncDataFromOperationsManager()

        lastRefreshTime = Date()
        isRefreshing = false

        print(" EventViewModel: refreshLiveData completed - Events: \(events.count), Categories: \(categories.count)")
    }
    
    private func setupSyncStatusObservation() {
        eventManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isSyncing = isLoading
                self?.syncStatus = isLoading ? "Syncing..." : "Ready"
            }
            .store(in: &cancellables)
    }
    
    private func saveScheduleDataLocally() {
        do {
            let encoder = JSONEncoder()
            let scheduleData = try encoder.encode(scheduleItems)
            let coursesData = try encoder.encode(courses)
            UserDefaults.standard.set(scheduleData, forKey: scheduleKey)
            UserDefaults.standard.set(coursesData, forKey: coursesKey)
        } catch {
            print(" ❌ Failed to save schedule data: \(error)")
        }
    }
    
    private func handleCalendarSyncForNewEvent(_ event: Event) {
        // Google Calendar sync can be implemented here in the future
    }

    func setLiveDataServices(calendarSyncManager: CalendarSyncManager) {
        self.calendarSyncManager = calendarSyncManager
    }
    
    func manageLiveActivities(themeManager: ThemeManager) {
    }
    
    func todaysEvents() -> [Event] {
        let now = Date()
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.date, inSameDayAs: now) && 
            !event.isCompleted && 
            event.date > now
        }
        .sorted { $0.date < $1.date }
    }
    
    func todayEvents() -> [Event] {
        let calendar = Calendar.current
        let now = Date()
        let baseEvents = events.filter { event in
            calendar.isDateInToday(event.date) && !event.isCompleted
        }

        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }

        return filteredEvents.sorted { $0.date < $1.date }
    }

    func upcomingEvents() -> [Event] {
        let calendar = Calendar.current
        let now = Date()
        let baseEvents = events.filter { event in
            event.date > now &&
            !event.isCompleted &&
            !calendar.isDateInToday(event.date) // Exclude today's events
        }

        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }

        return filteredEvents.sorted { $0.date < $1.date }
    }

    func pastEvents() -> [Event] {
        let now = Date()
        let baseEvents = events.filter { $0.date <= now || $0.isCompleted }

        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }

        return filteredEvents.sorted { $0.date > $1.date }
    }

    func events(for date: Date) -> [Event] {
        let calendar = Calendar.current
        let baseEvents = events.filter { calendar.isDate($0.date, inSameDayAs: date) }

        // Apply category filter if one is selected
        let filteredEvents = selectedCategoryFilter == nil ? baseEvents : baseEvents.filter { $0.categoryId == selectedCategoryFilter }

        return filteredEvents.sorted { $0.date < $1.date }
    }
    
    func bulkDeleteEvents(_ eventIDs: Set<UUID>) {
        let eventsToDelete = events.filter { eventIDs.contains($0.id) }
        for event in eventsToDelete {
            deleteEvent(event)
        }
    }
    
    func bulkDeleteCategories(_ categoryIDs: Set<UUID>) {
        let categoriesToDelete = categories.filter { categoryIDs.contains($0.id) }
        for category in categoriesToDelete {
            deleteCategory(category)
        }
    }
    
    func bulkDeleteScheduleItems(_ scheduleItemIDs: Set<UUID>, themeManager: ThemeManager) {
        let itemsToDelete = scheduleItems.filter { scheduleItemIDs.contains($0.id) }
        for item in itemsToDelete {
            scheduleItems.removeAll { $0.id == item.id }
        }
        saveScheduleDataLocally()
    }
    
    func markEventCompleted(_ event: Event) {
        var updatedEvent = event
        updatedEvent.isCompleted = true

        eventManager.updateEvent(updatedEvent)

        // IMMEDIATE SYNC: Update local arrays right away for instant UI update
        syncDataFromOperationsManager()

        notificationManager.removeAllEventNotifications(for: updatedEvent)
    }

    func toggleEventCompleted(_ event: Event) {
        var updated = event
        updated.isCompleted.toggle()

        updateEvent(updated)

        if updated.isCompleted {
            notificationManager.removeAllEventNotifications(for: updated)
        }
    }

    func addEvent(_ event: Event) {
        eventManager.addEvent(event)

        // IMMEDIATE SYNC: Update local arrays right away for instant UI update
        syncDataFromOperationsManager()

        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }

        handleCalendarSyncForNewEvent(event)
    }

    func updateEvent(_ event: Event) {
        guard let oldEvent = events.first(where: { $0.id == event.id }) else { return }

        eventManager.updateEvent(event)

        // IMMEDIATE SYNC: Update local arrays right away for instant UI update
        syncDataFromOperationsManager()

        notificationManager.removeAllEventNotifications(for: oldEvent)
        if event.reminderTime != .none {
            notificationManager.scheduleEventNotification(for: event, reminderTime: event.reminderTime, categories: categories)
        }

        handleCalendarSyncOnUpdate(oldEvent: oldEvent, newEvent: event)
    }

    func deleteEvent(_ event: Event) {
        eventManager.deleteEvent(event)

        // IMMEDIATE SYNC: Update local arrays right away for instant UI update
        syncDataFromOperationsManager()

        notificationManager.removeAllEventNotifications(for: event)

        // Calendar sync functionality removed
    }

    func addCategory(_ category: Category) {
        eventManager.saveCategory(category)
        syncDataFromOperationsManager()
    }

    func updateCategory(_ category: Category) {
        eventManager.saveCategory(category)
        syncDataFromOperationsManager()
    }

    func deleteCategory(_ category: Category) {
        // Unlink events referencing this category before deleting it
        let orphanedEvents = events.filter { $0.categoryId == category.id }
        for var event in orphanedEvents {
            event.categoryId = nil
            eventManager.updateEvent(event)
        }

        eventManager.deleteCategory(category)

        // IMMEDIATE SYNC: Update local arrays right away for instant UI update
        syncDataFromOperationsManager()
    }
}