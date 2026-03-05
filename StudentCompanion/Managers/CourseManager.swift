import SwiftUI
import Combine
import Supabase

// MARK: - Enhanced Course Operations Manager with Real-time Sync and Schedule Integration
@MainActor
class UnifiedCourseManager: ObservableObject, RealtimeSyncDelegate {
    @Published var courses: [Course] = []
    @Published var isSyncing: Bool = false
    @Published var syncStatus: String = "Ready"
    @Published var lastSyncTime: Date?
    
    // NEW: Schedule integration
    private var scheduleManager: ScheduleManager?

    // Event integration for assignment due dates and categories
    private var eventManager: EventManager { EventManager.shared }

    private let realtimeSyncManager = RealtimeSyncManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var isInitialLoad = true

    // ROBUST FIX: Track meetings with pending updates to prevent sync overwrites
    private var pendingMeetingUpdates: Set<UUID> = []
    
    init() {
        // Set up real-time sync delegate
        realtimeSyncManager.courseDelegate = self
        realtimeSyncManager.assignmentDelegate = self
        
        // Load local data first for offline support
        loadCourses()
        
        // Setup sync status observation
        setupSyncStatusObservation()
        
        // Setup authentication observer
        setupAuthenticationObserver()
        
        Task {
            await realtimeSyncManager.ensureStarted()
            await self.refreshCourseData()
        }
    }
    
    // MARK: - Authentication Observer
    
    private func setupAuthenticationObserver() {
        // CRITICAL: Listen for data clearing when user signs out
        NotificationCenter.default.addObserver(
            forName: .init("UserDataCleared"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🧹 UnifiedCourseManager: Received UserDataCleared notification")
            self?.clearAllData()
        }
        
        // Listen for post sign-in data refresh notification
        NotificationCenter.default.addObserver(
            forName: .init("UserSignedInDataRefresh"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 UnifiedCourseManager: Received post sign-in data refresh notification")
            Task { 
                await self?.refreshCourseData()
                await self?.backfillUnsyncedCourses()
            }
        }
        
        // Listen for data sync completed notification
        NotificationCenter.default.addObserver(
            forName: .init("DataSyncCompleted"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("📢 UnifiedCourseManager: Received data sync completed notification")
            Task { 
                await self?.reloadFromCache()
                await self?.backfillUnsyncedCourses()
            }
        }
        
        // Listen for course deletion notifications from other parts of the app
        NotificationCenter.default.addObserver(
            forName: Notification.Name("CourseDeleted"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let courseIdString = notification.userInfo?["courseId"] as? String,
               let courseId = UUID(uuidString: courseIdString) {
                print("🗑️ UnifiedCourseManager: Received CourseDeleted notification for: \(courseIdString)")
                
                // Ensure the course is removed from our local state
                if let index = self?.courses.firstIndex(where: { $0.id == courseId }) {
                    let removedCourse = self?.courses.remove(at: index)
                    self?.saveCoursesLocally()
                    print("🗑️ UnifiedCourseManager: Confirmed removal of '\(removedCourse?.name ?? "unknown")' from notification")
                }
            }
        }
    }
    
    // MARK: - Data Clearing
    
    private func clearAllData() {
        print("🧹 UnifiedCourseManager: Clearing all local data")
        courses.removeAll()
        
        // Force save empty state
        saveCoursesLocally()
        
        print("🧹 UnifiedCourseManager: All data cleared")
    }
    
    // MARK: - Cache Reload
    
    private func reloadFromCache() async {
        print("🔄 UnifiedCourseManager: Reloading data from cache")
        
        // Load courses from cache
        let cachedCourses = await CacheSystem.shared.courseCache.retrieve()
        
        // Load assignments from cache
        let cachedAssignments = await CacheSystem.shared.assignmentCache.retrieve()
        
        // Load course meetings from cache
        let cachedMeetings = await CacheSystem.shared.courseMeetingCache.retrieve()
        
        // If cache is empty, do not wipe locally stored courses
        guard !cachedCourses.isEmpty else {
            print("🔄 UnifiedCourseManager: Cache empty, preserving existing local courses")
            return
        }

        // ROBUST FIX: Preserve local courses for gradeCurve (not stored in cache/database)
        let existingLocalCourses = self.courses

        var updatedCourses: [Course] = []
        for course in cachedCourses {
            var updatedCourse = course
            updatedCourse.assignments = cachedAssignments.filter { $0.courseId == course.id }
            updatedCourse.meetings = cachedMeetings.filter { $0.courseId == course.id }

            // ROBUST FIX: Preserve gradeCurve from local state (NOT stored in database/cache)
            if let localCourse = existingLocalCourses.first(where: { $0.id == course.id }) {
                updatedCourse.gradeCurve = localCourse.gradeCurve
            }

            updatedCourses.append(updatedCourse)
        }
        
        await MainActor.run {
            self.courses = updatedCourses
        }
        
        saveCoursesLocally()
        
        print("🔄 UnifiedCourseManager: Reloaded \(cachedCourses.count) courses with \(cachedAssignments.count) total assignments and \(cachedMeetings.count) total meetings from cache")
    }
    
    // NEW: Set schedule manager for synchronization
    func setScheduleManager(_ scheduleManager: ScheduleManager) {
        // Skip if already set to the same instance to prevent redundant work on tab switches
        guard self.scheduleManager !== scheduleManager else {
            return
        }

        self.scheduleManager = scheduleManager
        print("🔄 UnifiedCourseManager: Schedule manager reference set")

        // The course manager will be the single source of truth for course data
    }

    // EventManager is now accessed via EventManager.shared (no setter needed)

    // MARK: - RealtimeSyncDelegate
    
    func didReceiveRealtimeUpdate(_ data: [String: Any], action: String, table: String) {
        switch (table, action) {
        case ("courses", "SYNC"):
            if let coursesData = data["courses"] as? [DatabaseCourse] {
                syncCoursesFromDatabase(coursesData)
            }
        case ("courses", "INSERT"):
            if let courseData = try? JSONSerialization.data(withJSONObject: data),
               let dbCourse = try? JSONDecoder().decode(DatabaseCourse.self, from: courseData) {
                handleCourseInsert(dbCourse)
            }
        case ("courses", "UPDATE"):
            if let courseData = try? JSONSerialization.data(withJSONObject: data),
               let dbCourse = try? JSONDecoder().decode(DatabaseCourse.self, from: courseData) {
                handleCourseUpdate(dbCourse)
            }
        case ("courses", "DELETE"):
            if let courseId = data["id"] as? String {
                handleCourseDelete(courseId)
            }
            
        case ("course_meetings", "SYNC"):
            if let meetingsData = data["course_meetings"] as? [DatabaseCourseMeeting] {
                syncCourseMeetingsFromDatabase(meetingsData)
            }
        case ("course_meetings", "INSERT"):
            if let meetingData = try? JSONSerialization.data(withJSONObject: data),
               let dbMeeting = try? JSONDecoder().decode(DatabaseCourseMeeting.self, from: meetingData) {
                handleCourseMeetingInsert(dbMeeting)
            }
        case ("course_meetings", "UPDATE"):
            if let meetingData = try? JSONSerialization.data(withJSONObject: data),
               let dbMeeting = try? JSONDecoder().decode(DatabaseCourseMeeting.self, from: meetingData) {
                handleCourseMeetingUpdate(dbMeeting)
            }
        case ("course_meetings", "DELETE"):
            if let meetingId = data["id"] as? String {
                handleCourseMeetingDelete(meetingId)
            }
            
        case ("assignments", "SYNC"):
            if let assignmentsData = data["assignments"] as? [DatabaseAssignment] {
                syncAssignmentsFromDatabase(assignmentsData)
            }
        case ("assignments", "INSERT"):
            if let assignmentData = try? JSONSerialization.data(withJSONObject: data),
               let dbAssignment = try? JSONDecoder().decode(DatabaseAssignment.self, from: assignmentData) {
                handleAssignmentInsert(dbAssignment)
            }
        case ("assignments", "UPDATE"):
            if let assignmentData = try? JSONSerialization.data(withJSONObject: data),
               let dbAssignment = try? JSONDecoder().decode(DatabaseAssignment.self, from: assignmentData) {
                handleAssignmentUpdate(dbAssignment)
            }
        case ("assignments", "DELETE"):
            if let assignmentId = data["id"] as? String {
                handleAssignmentDelete(assignmentId)
            }
            
        default:
            break
        }
    }
    
    // MARK: - Course Meeting Sync Handlers
    
    private func syncCourseMeetingsFromDatabase(_ meetings: [DatabaseCourseMeeting]) {
        print("🔄 UnifiedCourseManager: Syncing \(meetings.count) course meetings from database")

        let remoteMeetings = meetings.map { $0.toLocal() }
        let groupedMeetings = Dictionary(grouping: remoteMeetings) { $0.courseId }

        var coursesUpdated = false

        for (courseId, meetingsForCourse) in groupedMeetings {
            if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
                // ROBUST FIX: MERGE instead of REPLACE to preserve local edits
                let existingMeetings = courses[courseIndex].meetings
                var mergedMeetings: [CourseMeeting] = []

                // For each remote meeting, prefer local version if it exists (may have pending edits)
                for remoteMeeting in meetingsForCourse {
                    if let localMeeting = existingMeetings.first(where: { $0.id == remoteMeeting.id }) {
                        // Local version exists - keep it (may have unsaved edits)
                        // Skip if it's in pending updates
                        if pendingMeetingUpdates.contains(localMeeting.id) {
                            mergedMeetings.append(localMeeting)
                            print("🔄 UnifiedCourseManager: Keeping pending local meeting: \(localMeeting.displayName)")
                        } else {
                            // No pending edits - use remote version
                            mergedMeetings.append(remoteMeeting)
                        }
                    } else {
                        // New remote meeting - add it
                        mergedMeetings.append(remoteMeeting)
                    }
                }

                // Keep local-only meetings (might be pending creation)
                for localMeeting in existingMeetings {
                    if !meetingsForCourse.contains(where: { $0.id == localMeeting.id }) {
                        // This meeting only exists locally - keep it (pending creation)
                        mergedMeetings.append(localMeeting)
                        print("🔄 UnifiedCourseManager: Keeping local-only meeting: \(localMeeting.displayName)")
                    }
                }

                courses[courseIndex].meetings = mergedMeetings
                coursesUpdated = true
                print("🔄 UnifiedCourseManager: Merged \(mergedMeetings.count) meetings for course: \(courses[courseIndex].name) (remote: \(meetingsForCourse.count), local had: \(existingMeetings.count))")
            }
        }

        // Save to local storage after sync
        if coursesUpdated {
            saveCoursesLocally()
            print("🔄 UnifiedCourseManager: Saved courses with meetings to local storage")
        }

        print("🔄 UnifiedCourseManager: Course meeting sync complete")
    }
    
    private func handleCourseMeetingInsert(_ dbMeeting: DatabaseCourseMeeting) {
        let localMeeting = dbMeeting.toLocal()

        guard let courseIndex = courses.firstIndex(where: { $0.id == localMeeting.courseId }) else {
            print("🔄 UnifiedCourseManager: Course not found for meeting: \(localMeeting.displayName)")
            return
        }

        // ROBUST FIX: Check for existing meeting by ID to prevent duplicates
        if let existingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == localMeeting.id }) {
            // Meeting already exists - update it instead of adding duplicate
            courses[courseIndex].meetings[existingIndex] = localMeeting
            print("🔄 UnifiedCourseManager: Updated existing meeting \(localMeeting.displayName) in course \(courses[courseIndex].name)")
        } else {
            // Meeting doesn't exist - add it
            courses[courseIndex].meetings.append(localMeeting)
            print("🔄 UnifiedCourseManager: Added new meeting \(localMeeting.displayName) to course \(courses[courseIndex].name)")
        }

        // Force UI update by reassigning the courses array
        courses = courses
        saveCoursesLocally() // Save to UserDefaults for UI consistency
    }
    
    private func handleCourseMeetingUpdate(_ dbMeeting: DatabaseCourseMeeting) {
        let localMeeting = dbMeeting.toLocal()

        // ROBUST FIX: Handle case where meeting or course is not found
        guard let courseIndex = courses.firstIndex(where: { $0.id == localMeeting.courseId }) else {
            print("🔄 UnifiedCourseManager: Course not found for meeting update: \(localMeeting.displayName)")
            return
        }

        if let meetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == localMeeting.id }) {
            // Meeting found - update it
            courses[courseIndex].meetings[meetingIndex] = localMeeting
            print("🔄 UnifiedCourseManager: Updated meeting \(localMeeting.displayName) in course \(courses[courseIndex].name)")
        } else {
            // Meeting not found - add it (fallback for sync edge cases)
            courses[courseIndex].meetings.append(localMeeting)
            print("🔄 UnifiedCourseManager: Added missing meeting \(localMeeting.displayName) to course \(courses[courseIndex].name)")
        }

        // Force UI update by reassigning the courses array
        courses = courses
        saveCoursesLocally() // Save to UserDefaults for UI consistency
    }
    
    private func handleCourseMeetingDelete(_ meetingId: String) {
        guard let uuid = UUID(uuidString: meetingId) else { return }
        
        for courseIndex in courses.indices {
            if let meetingIndex = courses[courseIndex].meetings.firstIndex(where: { $0.id == uuid }) {
                let removedMeeting = courses[courseIndex].meetings.remove(at: meetingIndex)
                // Force UI update by reassigning the courses array
                courses = courses
                saveCoursesLocally() // Save to UserDefaults for UI consistency
                print("🔄 UnifiedCourseManager: Deleted meeting \(removedMeeting.displayName) from course \(courses[courseIndex].name)")
                break
            }
        }
    }
    
    // MARK: - Real-time Course Handlers
    
    private func syncCoursesFromDatabase(_ dbCourses: [DatabaseCourse]) {
        print("🔄 UnifiedCourseManager: Syncing \(dbCourses.count) courses from database")
        
        let remoteCourses = dbCourses.map { $0.toLocal() }
        
        // Preserve existing locally stored courses (including unsynced ones)
        let existingCourses = CourseStorage.load()
        let remoteIDs = Set(remoteCourses.map { $0.id })
        
        // IMPORTANT: Check for recently deleted courses to prevent restoration
        let recentlyDeletedCourses = getRecentlyDeletedCourses()
        let deletedIDs = Set(recentlyDeletedCourses)
        
        // Start with remote courses, but exclude recently deleted ones
        var updatedCourses: [Course] = remoteCourses.compactMap { remote in
            // Skip courses that were recently deleted
            if deletedIDs.contains(remote.id) {
                print("🚫 UnifiedCourseManager: Skipping restoration of recently deleted course: \(remote.name)")
                return nil
            }
            
            if let existing = existingCourses.first(where: { $0.id == remote.id }) {
                // Start with existing (local) data to preserve recent edits
                // This prevents course detail edits from being overwritten by stale database data
                var merged = existing

                // ROBUST FIX: MERGE meetings instead of REPLACE to preserve pending local edits
                var mergedMeetings: [CourseMeeting] = []

                // For each remote meeting, prefer local version if pending
                for remoteMeeting in remote.meetings {
                    if let localMeeting = existing.meetings.first(where: { $0.id == remoteMeeting.id }) {
                        // Local version exists - check if pending
                        if pendingMeetingUpdates.contains(localMeeting.id) {
                            mergedMeetings.append(localMeeting)
                        } else {
                            mergedMeetings.append(remoteMeeting)
                        }
                    } else {
                        mergedMeetings.append(remoteMeeting)
                    }
                }

                // Keep local-only meetings (pending creation)
                for localMeeting in existing.meetings {
                    if !remote.meetings.contains(where: { $0.id == localMeeting.id }) {
                        mergedMeetings.append(localMeeting)
                    }
                }

                merged.meetings = mergedMeetings

                print("🔄 UnifiedCourseManager: Preserved local course details for '\(existing.name)' with \(mergedMeetings.count) merged meetings (remote: \(remote.meetings.count), local: \(existing.meetings.count))")
                return merged
            } else {
                return remote
            }
        }
        
        // Add any local-only courses that don't exist remotely yet (unsynced) and aren't deleted
        let localOnly = existingCourses.filter { 
            !remoteIDs.contains($0.id) && !deletedIDs.contains($0.id)
        }
        updatedCourses.append(contentsOf: localOnly)
        
        // Update courses immediately - don't wait for async meeting loading
        self.courses = updatedCourses
        saveCoursesLocally()
        
        print("🔄 UnifiedCourseManager: Synced courses (remote=\(remoteCourses.count), excluded deleted=\(recentlyDeletedCourses.count), preserved local-only=\(localOnly.count), total=\(updatedCourses.count))")
        
        // Load meetings from database for courses that don't have them - but don't block
        Task {
            await loadMeetingsForCoursesIfNeeded()
        }
    }
    
    // Helper function to track recently deleted courses
    private func getRecentlyDeletedCourses() -> [UUID] {
        // Get list of recently deleted course IDs (last 10 minutes)
        if let deletedData = UserDefaults.standard.data(forKey: "recentlyDeletedCourses"),
           let deletedDict = try? JSONDecoder().decode([String: Date].self, from: deletedData) {
            
            let tenMinutesAgo = Date().addingTimeInterval(-10 * 60) // 10 minutes ago
            let recentIds = deletedDict.compactMap { (idString, deletionTime) -> UUID? in
                guard deletionTime > tenMinutesAgo,
                      let uuid = UUID(uuidString: idString) else { return nil }
                return uuid
            }
            
            return recentIds
        }
        return []
    }
    
    // Helper function to mark a course as recently deleted
    private func markCourseAsRecentlyDeleted(_ courseId: UUID) {
        var deletedDict: [String: Date] = [:]
        
        if let existingData = UserDefaults.standard.data(forKey: "recentlyDeletedCourses"),
           let existing = try? JSONDecoder().decode([String: Date].self, from: existingData) {
            deletedDict = existing
        }
        
        deletedDict[courseId.uuidString] = Date()
        
        if let encodedData = try? JSONEncoder().encode(deletedDict) {
            UserDefaults.standard.set(encodedData, forKey: "recentlyDeletedCourses")
        }
    }
    
    // MARK: - Load meetings for courses that don't have them (simplified)
    private func loadMeetingsForCoursesIfNeeded() async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.currentUser?.id.uuidString else { 
            print("🔄 UnifiedCourseManager: Cannot load meetings - no auth or user ID")
            return 
        }
        
        print("🔄 UnifiedCourseManager: Loading meetings for courses that need them...")
        #if DEBUG
        print("🔄 UnifiedCourseManager: User ID: \(userId)")
        #endif
        
        let meetingRepo = CourseMeetingRepository()
        var coursesNeedingUpdate: [(Int, Course)] = []
        
        // Check which courses need meetings loaded
        for (index, course) in courses.enumerated() {
            if course.meetings.isEmpty {
                print("🔄 UnifiedCourseManager: Course '\(course.name)' has no meetings, loading from database...")
                do {
                    let meetings = try await meetingRepo.findByCourse(course.id.uuidString, userId: userId)
                    print("🔄 UnifiedCourseManager: Found \(meetings.count) meetings for course '\(course.name)' in database")
                    
                    if !meetings.isEmpty {
                        var updatedCourse = course
                        updatedCourse.meetings = meetings
                        coursesNeedingUpdate.append((index, updatedCourse))
                        
                        // Debug each meeting
                        for meeting in meetings {
                            print("  - Meeting: \(meeting.displayName) on days \(meeting.daysOfWeek) at \(meeting.timeRange)")
                        }
                    } else {
                        print("🔄 UnifiedCourseManager: No meetings found for course '\(course.name)' in database")
                    }
                } catch {
                    print("❌ UnifiedCourseManager: Failed to load meetings for course '\(course.name)': \(error)")
                    print("❌ Error type: \(type(of: error))")
                    print("❌ Error details: \(error.localizedDescription)")
                }
            } else {
                print("🔄 UnifiedCourseManager: Course '\(course.name)' already has \(course.meetings.count) meetings")
            }
        }
        
        // Update courses with loaded meetings
        if !coursesNeedingUpdate.isEmpty {
            await MainActor.run {
                for (index, updatedCourse) in coursesNeedingUpdate {
                    if index < self.courses.count && self.courses[index].id == updatedCourse.id {
                        print("🔄 UnifiedCourseManager: Updating course '\(updatedCourse.name)' with \(updatedCourse.meetings.count) meetings")
                        self.courses[index] = updatedCourse
                    }
                }
                // Force UI update
                self.courses = self.courses
                self.saveCoursesLocally()
                print("✅ UnifiedCourseManager: Updated \(coursesNeedingUpdate.count) courses with meetings from database")
            }
        } else {
            print("🔄 UnifiedCourseManager: No courses needed meeting updates")
        }
    }
    
    private func syncAssignmentsFromDatabase(_ assignments: [DatabaseAssignment]) {
        print("🔄 UnifiedCourseManager: Syncing \(assignments.count) assignments from database")

        let localAssignments = assignments.map { $0.toLocal() }

        // DEBUG: Log full UUIDs from database
        for assignment in localAssignments {
            print("🔍 DEBUG: Assignment from DB - FULL ID: \(assignment.id.uuidString) - Name: '\(assignment.name)'")
        }

        let groupedAssignments = Dictionary(grouping: localAssignments.filter { assignment in
            // Ensure we only include assignments with valid course IDs
            return self.courses.contains { $0.id == assignment.courseId }
        }, by: { $0.courseId })

        var coursesUpdated = false

        for (courseId, dbAssignments) in groupedAssignments {
            if let courseIndex = courses.firstIndex(where: { $0.id == courseId }) {
                print("🔍 DEBUG: Before replace - Course '\(courses[courseIndex].name)' has \(courses[courseIndex].assignments.count) assignments:")
                for existingAssignment in courses[courseIndex].assignments {
                    print("  - FULL ID: \(existingAssignment.id.uuidString) - Name: '\(existingAssignment.name)'")
                }

                // Replace assignments for this course
                courses[courseIndex].assignments = dbAssignments
                coursesUpdated = true

                print("🔍 DEBUG: After replace - Course '\(courses[courseIndex].name)' now has \(courses[courseIndex].assignments.count) assignments:")
                for newAssignment in courses[courseIndex].assignments {
                    print("  - FULL ID: \(newAssignment.id.uuidString) - Name: '\(newAssignment.name)'")
                }
            }
        }
        
        // Save to local storage after sync
        if coursesUpdated {
            saveCoursesLocally()
            print("🔄 UnifiedCourseManager: Saved courses with assignments to local storage")
        }
        
        print("🔄 UnifiedCourseManager: Assignment sync complete")
    }
    
    private func handleCourseInsert(_ dbCourse: DatabaseCourse) {
        let localCourse = dbCourse.toLocal()
        
        // Check if course already exists locally
        if !courses.contains(where: { $0.id == localCourse.id }) {
            courses.append(localCourse)
            saveCoursesLocally()
        }
    }
    
    private func handleCourseUpdate(_ dbCourse: DatabaseCourse) {
        let localCourse = dbCourse.toLocal()
        
        if let index = courses.firstIndex(where: { $0.id == localCourse.id }) {
            // Preserve existing assignments
            var updatedCourse = localCourse
            updatedCourse.assignments = courses[index].assignments
            courses[index] = updatedCourse
            saveCoursesLocally()
        }
    }
    
    private func handleCourseDelete(_ courseId: String) {
        guard let uuid = UUID(uuidString: courseId) else { 
            print("🗑️ Invalid courseId format: \(courseId)")
            return 
        }
        
        print("🗑️ HandleCourseDelete: Processing deletion for course ID: \(courseId)")
        
        if let index = courses.firstIndex(where: { $0.id == uuid }) {
            let removedCourse = courses.remove(at: index)
            print("🗑️ HandleCourseDelete: Removed '\(removedCourse.name)' from courses array")
            
            // Force UI update
            courses = courses
            
            saveCoursesLocally()
            print("🗑️ HandleCourseDelete: Saved updated courses to local storage")
            
            // Remove from cache as well
            Task {
                await CacheSystem.shared.courseCache.delete(id: courseId)
                print("🗑️ HandleCourseDelete: Removed from cache")
            }
        } else {
            print("🗑️ HandleCourseDelete: Course \(courseId) not found in local courses array")
        }
    }
    
    private func handleAssignmentInsert(_ dbAssignment: DatabaseAssignment) {
        let localAssignment = dbAssignment.toLocal()
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == localAssignment.courseId }) else {
            print("🔄 UnifiedCourseManager: Course not found for assignment: \(localAssignment.name)")
            return
        }
        
        if !courses[courseIndex].assignments.contains(where: { $0.id == localAssignment.id }) {
            courses[courseIndex].addAssignment(localAssignment)
            saveCoursesLocally() // Save to UserDefaults for UI consistency
            print("🔄 UnifiedCourseManager: Added assignment \(localAssignment.name) to course \(courses[courseIndex].name)")
        }
    }
    
    private func handleAssignmentUpdate(_ dbAssignment: DatabaseAssignment) {
        let localAssignment = dbAssignment.toLocal()
        
        guard let courseIndex = courses.firstIndex(where: { $0.id == localAssignment.courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == localAssignment.id }) else {
            print("🔄 UnifiedCourseManager: Assignment or course not found for update: \(localAssignment.name)")
            return
        }
        
        courses[courseIndex].assignments[assignmentIndex] = localAssignment
        saveCoursesLocally() // Save to UserDefaults for UI consistency
        print("🔄 UnifiedCourseManager: Updated assignment \(localAssignment.name) in course \(courses[courseIndex].name)")
    }
    
    private func handleAssignmentDelete(_ assignmentId: String) {
        guard let uuid = UUID(uuidString: assignmentId) else { return }
        
        for courseIndex in courses.indices {
            if let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == uuid }) {
                let removedAssignment = courses[courseIndex].assignments.remove(at: assignmentIndex)
                saveCoursesLocally() // Save to UserDefaults for UI consistency
                print("🔄 UnifiedCourseManager: Deleted assignment \(removedAssignment.name) from course \(courses[courseIndex].name)")
                break
            }
        }
    }
    
    // MARK: - Enhanced Course Operations with Sync
    
    func addCourse(_ course: Course) {
        courses.append(course)
        saveCoursesLocally()

        // Auto-create linked category
        Task {
            await createLinkedCategoryForCourse(course)
        }

        // If authenticated, queue sync to backend; otherwise, it will remain local until sign-in.
        if SupabaseService.shared.isAuthenticated {
            syncCourseToDatabase(course, action: .create)
        } else {
            print("🔒 UnifiedCourseManager: Added course locally (offline). Will sync when signed in.")
        }
    }
    
    func updateCourse(_ course: Course) async throws {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else {
            throw NSError(domain: "CourseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "Course not found"])
        }

        // Get the old course from the array (this is the ORIGINAL before any changes)
        let oldCourse = courses[index]
        let oldColorHex = oldCourse.colorHex
        let oldName = oldCourse.name
        let oldCode = oldCourse.courseCode
        let oldScheduleId = oldCourse.scheduleId

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔄 DEBUG: updateCourse() called for '\(course.name)'")
        print("   Course ID: \(course.id.uuidString)")
        print("   Schedule ID: \(course.scheduleId)")
        print("   Old course object ID: \(ObjectIdentifier(oldCourse))")
        print("   New course object ID: \(ObjectIdentifier(course))")
        print("   Are they the same object? \(oldCourse === course)")
        print("   Old colorHex: \(oldColorHex), New colorHex: \(course.colorHex)")
        print("   Old name: '\(oldName)', New name: '\(course.name)'")
        print("   Old code: '\(oldCode)', New code: '\(course.courseCode)'")
        print("   Color changed: \(oldColorHex != course.colorHex)")
        print("   Name changed: \(oldName != course.name)")
        print("   Code changed: \(oldCode != course.courseCode)")

        // Update locally first for immediate UI response
        courses[index] = course
        saveCoursesLocally()

        // Sync linked category if color or name changed
        if oldColorHex != course.colorHex ||
           oldName != course.name ||
           oldCode != course.courseCode ||
           oldScheduleId != course.scheduleId {
            print("✅ DEBUG: Changes detected! Calling createLinkedCategoryForCourse()...")
            await createLinkedCategoryForCourse(course)
            print("✅ DEBUG: createLinkedCategoryForCourse() completed")
        } else {
            print("⏭️ DEBUG: No changes detected, skipping category sync")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Sync directly to database and WAIT for completion
        // This prevents race conditions where sync fires before database update completes
        try await syncCourseDirectlyToDatabase(course, action: .update)
    }

    /// Directly syncs a course to the database and waits for completion
    /// This ensures changes are persisted before any refresh can overwrite them
    private func syncCourseDirectlyToDatabase(_ course: Course, action: SyncAction) async throws {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("⚠️ UnifiedCourseManager: No user ID for course sync")
            return
        }

        let dbCourse = DatabaseCourse(from: course, userId: userId)

        switch action {
        case .create:
            print("📤 UnifiedCourseManager: Creating course '\(course.name)' in database...")
            let response = try await SupabaseService.shared.client
                .from("courses")
                .insert(dbCourse)
                .select()
                .single()
                .execute()

            let created = try JSONDecoder().decode(DatabaseCourse.self, from: response.data)
            print("✅ UnifiedCourseManager: Course '\(created.name)' created successfully")

        case .update:
            print("📤 UnifiedCourseManager: Updating course '\(course.name)' in database...")
            let response = try await SupabaseService.shared.client
                .from("courses")
                .update(dbCourse)
                .eq("id", value: course.id.uuidString)
                .select()
                .single()
                .execute()

            let updated = try JSONDecoder().decode(DatabaseCourse.self, from: response.data)
            print("✅ UnifiedCourseManager: Course '\(updated.name)' updated successfully")

        case .delete:
            print("📤 UnifiedCourseManager: Deleting course '\(course.name)' from database...")
            _ = try await SupabaseService.shared.client
                .from("courses")
                .delete()
                .eq("id", value: course.id.uuidString)
                .execute()

            print("✅ UnifiedCourseManager: Course '\(course.name)' deleted successfully")
        }

        // Update cache
        await CacheSystem.shared.courseCache.update(course)
    }

    func deleteCourse(_ courseID: UUID) {
        print("🗑️ UnifiedCourseManager: Deleting course \(courseID)")
        
        guard let course = courses.first(where: { $0.id == courseID }) else { 
            print("🗑️ Course not found locally: \(courseID)")
            return 
        }
        
        let courseName = course.name
        print("🗑️ Deleting course: '\(courseName)'")
        
        // 0. Mark as recently deleted to prevent sync restoration
        markCourseAsRecentlyDeleted(courseID)

        // 0.5. Delete linked category
        if let linkedCategory = eventManager.categories.first(where: { $0.courseId == courseID }) {
            print("Deleting linked category '\(linkedCategory.name)'")
            eventManager.deleteCategory(linkedCategory)
        }

        // 1. Remove from local state immediately
        courses.removeAll { $0.id == courseID }
        saveCoursesLocally()
        print("🗑️ Removed '\(courseName)' from local state")
        
        // 2. Remove from cache immediately
        Task {
            await CacheSystem.shared.courseCache.delete(id: courseID.uuidString)
            
            // Also remove related assignments and meetings from cache
            let allAssignments = await CacheSystem.shared.assignmentCache.retrieve()
            let courseAssignments = allAssignments.filter { $0.courseId == courseID }
            for assignment in courseAssignments {
                await CacheSystem.shared.assignmentCache.delete(id: assignment.id.uuidString)
            }
            
            let allMeetings = await CacheSystem.shared.courseMeetingCache.retrieve()
            let courseMeetings = allMeetings.filter { $0.courseId == courseID }
            for meeting in courseMeetings {
                await CacheSystem.shared.courseMeetingCache.delete(id: meeting.id.uuidString)
            }
            
            print("🗑️ Removed '\(courseName)' and related data from cache")
        }
        
        // 3. Sync to database (queue for deletion)
        syncCourseToDatabase(course, action: .delete)
        print("🗑️ Queued '\(courseName)' for database deletion")
        
        // 4. Post notification to prevent other managers from restoring
        NotificationCenter.default.post(
            name: Notification.Name("CourseDeleted"),
            object: nil,
            userInfo: ["courseId": courseID.uuidString]
        )
        print("🗑️ Posted CourseDeleted notification for '\(courseName)'")
    }
    
    func addAssignment(_ assignment: Assignment, to courseId: UUID) {
        print("➕ UnifiedCourseManager: addAssignment called - '\(assignment.name)' to course \(courseId)")
        print("➕ UnifiedCourseManager: Authenticated: \(SupabaseService.shared.isAuthenticated)")
        print("➕ UnifiedCourseManager: Total courses: \(courses.count)")

        guard SupabaseService.shared.isAuthenticated else {
            print("🔒 UnifiedCourseManager: Add assignment blocked - user not authenticated")
            return
        }

        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            print("❌ UnifiedCourseManager: Course not found with ID: \(courseId)")
            print("❌ UnifiedCourseManager: Available course IDs:")
            for (idx, course) in courses.enumerated() {
                print("  [\(idx)] \(course.name): \(course.id)")
            }
            return
        }

        print("➕ UnifiedCourseManager: Found course at index \(courseIndex): '\(courses[courseIndex].name)'")
        print("➕ UnifiedCourseManager: Assignments before add: \(courses[courseIndex].assignments.count)")
        print("🔍 DEBUG: Adding assignment with FULL ID: \(assignment.id.uuidString) - Name: '\(assignment.name)'")

        // DEBUG: Log existing assignments before add
        print("🔍 DEBUG: Existing assignments in course:")
        for (index, existingAssignment) in courses[courseIndex].assignments.enumerated() {
            print("  [\(index)] FULL ID: \(existingAssignment.id.uuidString) - Name: '\(existingAssignment.name)'")
        }

        courses[courseIndex].addAssignment(assignment)
        print("➕ UnifiedCourseManager: Assignments after add: \(courses[courseIndex].assignments.count)")

        // DEBUG: Log assignments after add
        print("🔍 DEBUG: Assignments after add:")
        for (index, existingAssignment) in courses[courseIndex].assignments.enumerated() {
            print("  [\(index)] FULL ID: \(existingAssignment.id.uuidString) - Name: '\(existingAssignment.name)'")
        }

        // CRITICAL FIX: Ensure UI updates with new grade calculations
        courses[courseIndex].objectWillChange.send()
        courses[courseIndex].refreshObservationsAndSignalChange()

        saveCoursesLocally()
        print("➕ UnifiedCourseManager: Saved courses locally")

        // Create event for assignment if it has a due date
        createOrUpdateEventForAssignment(assignment, courseId: courseId)

        // Sync directly to database instead of queuing
        Task {
            print("➕ UnifiedCourseManager: Starting database sync for '\(assignment.name)'")
            await syncAssignmentDirectlyToDatabase(assignment, courseId: courseId, action: .create)
        }
    }
    
    func updateAssignment(_ assignment: Assignment, in courseId: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }),
              let assignmentIndex = courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) else { return }

        // Track if due date changed
        let oldDueDate = courses[courseIndex].assignments[assignmentIndex].dueDate
        let newDueDate = assignment.dueDate

        if oldDueDate != newDueDate {
            print("📅 UnifiedCourseManager: Due date changed for '\(assignment.name)'")
            print("   Old: \(oldDueDate?.description ?? "none")")
            print("   New: \(newDueDate?.description ?? "none")")
        }

        // Update locally first for immediate UI response
        courses[courseIndex].assignments[assignmentIndex] = assignment

        // CRITICAL FIX: Trigger course's change observers to update grades
        // Modifying array element doesn't trigger didSet, so we manually trigger observers
        courses[courseIndex].objectWillChange.send()
        courses[courseIndex].refreshObservationsAndSignalChange()

        saveCoursesLocally()

        // Update event for assignment (handles create/update/delete based on due date)
        createOrUpdateEventForAssignment(assignment, courseId: courseId)

        // Sync directly to database instead of queuing
        Task {
            await syncAssignmentDirectlyToDatabase(assignment, courseId: courseId, action: .update)
        }
    }
    
    func deleteAssignment(_ assignmentId: UUID, from courseId: UUID) {
        print("🗑️ UnifiedCourseManager: deleteAssignment called")
        print("🔍 DEBUG: Looking for assignment with FULL ID: \(assignmentId.uuidString)")
        print("🔍 DEBUG: In course with FULL ID: \(courseId.uuidString)")
        print("🗑️ UnifiedCourseManager: Total courses: \(courses.count)")

        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            print("❌ UnifiedCourseManager: Course not found with ID: \(courseId)")
            return
        }

        print("🗑️ UnifiedCourseManager: Course found at index \(courseIndex): '\(courses[courseIndex].name)'")
        print("🗑️ UnifiedCourseManager: Assignments in course: \(courses[courseIndex].assignments.count)")

        // DEBUG: Log all assignment IDs in the course
        print("🔍 DEBUG: Assignments currently in course:")
        for (index, existingAssignment) in courses[courseIndex].assignments.enumerated() {
            print("  [\(index)] FULL ID: \(existingAssignment.id.uuidString) - Name: '\(existingAssignment.name)'")
            print("      Comparison: \(existingAssignment.id.uuidString) == \(assignmentId.uuidString) ? \(existingAssignment.id == assignmentId)")
        }

        // Check if assignment exists locally
        if let assignment = courses[courseIndex].assignments.first(where: { $0.id == assignmentId }) {
            // Assignment found locally - delete from local array
            print("🗑️ UnifiedCourseManager: Found assignment to delete locally: '\(assignment.name)'")

            courses[courseIndex].assignments.removeAll { $0.id == assignmentId }
            print("🗑️ UnifiedCourseManager: Assignments after delete: \(courses[courseIndex].assignments.count)")

            // CRITICAL FIX: Ensure UI updates with new grade calculations
            courses[courseIndex].objectWillChange.send()
            courses[courseIndex].refreshObservationsAndSignalChange()

            saveCoursesLocally()
            print("🗑️ UnifiedCourseManager: Saved courses locally")

            // Delete corresponding event
            deleteEventForAssignment(assignmentId)

            // Sync delete to database
            Task {
                print("🗑️ UnifiedCourseManager: Starting database sync for delete")
                await syncAssignmentDirectlyToDatabase(assignment, courseId: courseId, action: .delete)
            }
        } else {
            // Assignment NOT found locally - might exist in database but not loaded in memory
            print("⚠️ UnifiedCourseManager: Assignment not found locally, attempting direct database delete")

            // Delete corresponding event
            deleteEventForAssignment(assignmentId)

            // Delete directly from database
            Task {
                await deleteAssignmentDirectlyFromDatabase(assignmentId: assignmentId)

                // Reload assignments to sync local state with database
                print("🔄 UnifiedCourseManager: Reloading assignments after database delete")
                await reloadAssignmentsForCourse(courseId)
            }
        }
    }
    
    func addMeeting(_ meeting: CourseMeeting) {
        // ROBUST FIX: Check for duplicate before adding locally
        if let idx = self.courses.firstIndex(where: { $0.id == meeting.courseId }) {
            // Check if meeting already exists (by ID)
            if let existingIdx = self.courses[idx].meetings.firstIndex(where: { $0.id == meeting.id }) {
                // Meeting already exists - update instead of append
                self.courses[idx].meetings[existingIdx] = meeting
                print("🔄 UnifiedCourseManager: Updated existing meeting locally: \(meeting.displayName)")
            } else {
                // New meeting - append
                self.courses[idx].meetings.append(meeting)
                print("🔄 UnifiedCourseManager: Added new meeting locally: \(meeting.displayName)")
            }
            self.courses = self.courses
            self.saveCoursesLocally()

            // Schedule notifications for the meeting
            let courseName = self.courses[idx].name
            NotificationManager.shared.scheduleCourseMeetingNotifications(
                for: meeting,
                courseName: courseName
            )
        }

        // Sync to backend if authenticated
        guard SupabaseService.shared.isAuthenticated else { return }
        Task {
            do {
                let repo = CourseMeetingRepository()
                let userId = SupabaseService.shared.currentUser?.id.uuidString ?? ""

                // Try update first, then create if update fails
                var saved: CourseMeeting
                do {
                    saved = try await repo.update(meeting, userId: userId)
                    print("✅ UnifiedCourseManager: Updated meeting in database: \(meeting.displayName)")
                } catch {
                    // Update failed, try create
                    saved = try await repo.create(meeting, userId: userId)
                    print("✅ UnifiedCourseManager: Created meeting in database: \(meeting.displayName)")
                }

                // Update local state with server response
                await MainActor.run {
                    if let cidx = self.courses.firstIndex(where: { $0.id == saved.courseId }) {
                        if let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == saved.id }) {
                            self.courses[cidx].meetings[midx] = saved
                        } else if let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == meeting.id }) {
                            // ID might have changed, find by original ID
                            self.courses[cidx].meetings[midx] = saved
                        }
                        self.courses = self.courses
                        self.saveCoursesLocally()
                    }
                }

                await CacheSystem.shared.courseMeetingCache.store(saved)
            } catch {
                print("❌ UnifiedCourseManager: Failed to sync meeting: \(error)")
            }
        }
    }

    func updateMeeting(_ meeting: CourseMeeting) {
        // ROBUST FIX: Mark meeting as pending to prevent sync overwrites
        pendingMeetingUpdates.insert(meeting.id)

        // Cancel old notifications before updating
        NotificationManager.shared.removeAllCourseMeetingNotifications(for: meeting)

        // Update local state FIRST for immediate UI feedback
        var originalMeeting: CourseMeeting?

        if let cidx = self.courses.firstIndex(where: { $0.id == meeting.courseId }),
           let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == meeting.id }) {
            originalMeeting = self.courses[cidx].meetings[midx]
            self.courses[cidx].meetings[midx] = meeting
            self.courses = self.courses // Force UI update
            self.saveCoursesLocally()
            print("🔄 UnifiedCourseManager: Updated meeting locally: \(meeting.displayName)")

            // Schedule new notifications for the updated meeting
            let courseName = self.courses[cidx].name
            NotificationManager.shared.scheduleCourseMeetingNotifications(
                for: meeting,
                courseName: courseName
            )
        } else {
            print("⚠️ UnifiedCourseManager: Meeting not found locally for update: \(meeting.id)")
            // Try to add it if it doesn't exist
            if let cidx = self.courses.firstIndex(where: { $0.id == meeting.courseId }) {
                self.courses[cidx].meetings.append(meeting)
                self.courses = self.courses
                self.saveCoursesLocally()
                print("🔄 UnifiedCourseManager: Added missing meeting locally: \(meeting.displayName)")

                // Schedule notifications for the newly added meeting
                let courseName = self.courses[cidx].name
                NotificationManager.shared.scheduleCourseMeetingNotifications(
                    for: meeting,
                    courseName: courseName
                )
            }
        }

        // Sync to backend if authenticated
        guard SupabaseService.shared.isAuthenticated else {
            // Remove from pending since we're not syncing
            pendingMeetingUpdates.remove(meeting.id)
            return
        }

        Task {
            do {
                let repo = CourseMeetingRepository()
                let userId = SupabaseService.shared.currentUser?.id.uuidString ?? ""
                let saved = try await repo.update(meeting, userId: userId)

                // Update local state with server response
                await MainActor.run {
                    // Remove from pending BEFORE updating local state
                    self.pendingMeetingUpdates.remove(meeting.id)

                    if let cidx = self.courses.firstIndex(where: { $0.id == saved.courseId }),
                       let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == saved.id }) {
                        self.courses[cidx].meetings[midx] = saved
                        self.courses = self.courses
                        self.saveCoursesLocally()
                    }
                }

                await CacheSystem.shared.courseMeetingCache.update(saved)
                print("✅ UnifiedCourseManager: Meeting synced to database: \(saved.displayName)")
            } catch {
                print("❌ UnifiedCourseManager: Failed to sync meeting update to database: \(error)")
                // Remove from pending but keep local changes
                await MainActor.run {
                    self.pendingMeetingUpdates.remove(meeting.id)
                }
                // Keep local changes - don't revert to avoid confusing the user
                // The next sync will attempt to reconcile
            }
        }
    }

    func deleteMeeting(_ meetingId: UUID, courseId: UUID) {
        // ROBUST FIX: Delete from local state FIRST for immediate UI feedback
        var deletedMeeting: CourseMeeting?

        if let cidx = self.courses.firstIndex(where: { $0.id == courseId }) {
            if let midx = self.courses[cidx].meetings.firstIndex(where: { $0.id == meetingId }) {
                deletedMeeting = self.courses[cidx].meetings.remove(at: midx)
                self.courses = self.courses // Force UI update
                self.saveCoursesLocally()
                print("🔄 UnifiedCourseManager: Deleted meeting locally: \(deletedMeeting?.displayName ?? "unknown")")

                // Cancel notifications for the deleted meeting
                if let meeting = deletedMeeting {
                    NotificationManager.shared.removeAllCourseMeetingNotifications(for: meeting)
                }
            }
        }

        // Sync to backend if authenticated
        guard SupabaseService.shared.isAuthenticated else { return }

        Task {
            do {
                let repo = CourseMeetingRepository()
                try await repo.delete(id: meetingId.uuidString)
                await CacheSystem.shared.courseMeetingCache.delete(id: meetingId.uuidString)
                print("✅ UnifiedCourseManager: Meeting deleted from database: \(meetingId)")
            } catch {
                print("❌ UnifiedCourseManager: Failed to delete meeting from database: \(error)")
                // Re-add the meeting locally if database delete failed (to maintain consistency)
                if let meeting = deletedMeeting {
                    await MainActor.run {
                        if let cidx = self.courses.firstIndex(where: { $0.id == courseId }) {
                            // Only re-add if not already present
                            if !self.courses[cidx].meetings.contains(where: { $0.id == meetingId }) {
                                self.courses[cidx].meetings.append(meeting)
                                self.courses = self.courses
                                self.saveCoursesLocally()
                                print("🔄 UnifiedCourseManager: Restored meeting after failed delete: \(meeting.displayName)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Direct Database Sync Operations (NEW)
    
    private func syncAssignmentDirectlyToDatabase(_ assignment: Assignment, courseId: UUID, action: SyncAction) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { 
            print("❌ UnifiedCourseManager: No user ID for assignment sync")
            return 
        }
        
        do {
            let assignmentRepo = AssignmentRepository()
            
            switch action {
            case .create:
                print("📝 UnifiedCourseManager: Creating assignment '\(assignment.name)' in database")
                let createdAssignment = try await assignmentRepo.create(assignment, userId: userId)
                
                // Update local copy with server data
                await MainActor.run {
                    if let courseIndex = self.courses.firstIndex(where: { $0.id == courseId }),
                       let assignmentIndex = self.courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) {
                        self.courses[courseIndex].assignments[assignmentIndex] = createdAssignment
                        self.saveCoursesLocally()
                    }
                }
                
                // Store in cache
                await CacheSystem.shared.assignmentCache.store(createdAssignment)
                print("✅ UnifiedCourseManager: Assignment '\(assignment.name)' created successfully")
                
            case .update:
                print("📝 UnifiedCourseManager: Upserting assignment '\(assignment.name)' in database")
                let updatedAssignment = try await assignmentRepo.upsert(assignment, userId: userId)

                // Update local copy with server data
                await MainActor.run {
                    if let courseIndex = self.courses.firstIndex(where: { $0.id == courseId }),
                       let assignmentIndex = self.courses[courseIndex].assignments.firstIndex(where: { $0.id == assignment.id }) {
                        self.courses[courseIndex].assignments[assignmentIndex] = updatedAssignment
                        self.saveCoursesLocally()
                    }
                }

                // Update cache
                await CacheSystem.shared.assignmentCache.update(updatedAssignment)
                print("✅ UnifiedCourseManager: Assignment '\(assignment.name)' upserted successfully")
                
            case .delete:
                print("📝 UnifiedCourseManager: Deleting assignment '\(assignment.name)' from database")
                try await assignmentRepo.delete(id: assignment.id.uuidString)
                
                // Remove from cache
                await CacheSystem.shared.assignmentCache.delete(id: assignment.id.uuidString)
                print("✅ UnifiedCourseManager: Assignment '\(assignment.name)' deleted successfully")
            }
            
        } catch {
            print("❌ UnifiedCourseManager: Failed to sync assignment '\(assignment.name)' to database: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // On error, reload assignments from server to ensure consistency
            await reloadAssignmentsForCourse(courseId)
        }
    }

    private func deleteAssignmentDirectlyFromDatabase(assignmentId: UUID) async {
        print("🗑️ UnifiedCourseManager: Deleting assignment directly from database - ID: \(assignmentId.uuidString)")

        do {
            let assignmentRepo = AssignmentRepository()
            try await assignmentRepo.delete(id: assignmentId.uuidString)

            // Remove from cache
            await CacheSystem.shared.assignmentCache.delete(id: assignmentId.uuidString)

            print("✅ UnifiedCourseManager: Assignment deleted successfully from database")
        } catch {
            print("❌ UnifiedCourseManager: Failed to delete assignment from database: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }

    // MARK: - Assignment Event Integration

    private func createOrUpdateEventForAssignment(_ assignment: Assignment, courseId: UUID) {
        if let dueDate = assignment.dueDate {
            // Has due date - create or update event
            print("CourseManager: Creating/updating event for assignment '\(assignment.name)'")

            // Check if event already exists for this assignment
            let existingEvent = eventManager.events.first { event in
                event.eventType == Event.EventType.assignment &&
                event.externalIdentifier == assignment.id.uuidString
            }

            if let existing = existingEvent {
                // Update existing event
                let categoryId = findOrCreateCategoryForCourse(courseId)

                var updatedEvent = existing
                updatedEvent.title = assignment.name
                updatedEvent.date = dueDate
                updatedEvent.courseId = courseId
                updatedEvent.categoryId = categoryId
                updatedEvent.description = assignment.notes.isEmpty ? nil : assignment.notes

                eventManager.updateEvent(updatedEvent)
            } else {
                // Create new event
                let categoryId = findOrCreateCategoryForCourse(courseId)

                var newEvent = Event(
                    title: assignment.name,
                    date: dueDate,
                    courseId: courseId,
                    categoryId: categoryId,
                    reminderTime: .oneDay
                )
                newEvent.eventType = Event.EventType.assignment
                newEvent.externalIdentifier = assignment.id.uuidString
                newEvent.description = assignment.notes.isEmpty ? nil : assignment.notes

                eventManager.addEvent(newEvent)
            }
        } else {
            // No due date - delete any existing event
            deleteEventForAssignment(assignment.id)
        }
    }

    private func deleteEventForAssignment(_ assignmentId: UUID) {
        // Find and delete the event associated with this assignment
        if let event = eventManager.events.first(where: {
            $0.eventType == Event.EventType.assignment && $0.externalIdentifier == assignmentId.uuidString
        }) {
            print("CourseManager: Deleting event for assignment ID: \(assignmentId.uuidString.prefix(8))")
            eventManager.deleteEvent(event)
        }
    }

    // MARK: - Category Integration

    private func findOrCreateCategoryForCourse(_ courseId: UUID) -> UUID? {
        guard let course = courses.first(where: { $0.id == courseId }) else {
            print("CourseManager: Course not found for category creation")
            return nil
        }

        // Use course code as category name, fallback to course name
        let categoryName = course.courseCode.isEmpty ? course.name : course.courseCode

        // Check if category already exists with link to this course
        if let existingCategory = eventManager.categories.first(where: { $0.courseId == courseId }) {
            // Update category if needed
            var needsUpdate = false
            var updatedCategory = existingCategory

            if existingCategory.color != course.color {
                updatedCategory.color = course.color
                needsUpdate = true
            }
            if existingCategory.name != categoryName {
                updatedCategory.name = categoryName
                needsUpdate = true
            }
            if existingCategory.scheduleId != course.scheduleId {
                updatedCategory.scheduleId = course.scheduleId
                needsUpdate = true
            }

            if needsUpdate {
                eventManager.updateCategory(updatedCategory)
            }

            return updatedCategory.id
        }

        // Check if there's an unlinked category with the same name that we can link
        if let unmatchedCategory = eventManager.categories.first(where: {
            $0.name == categoryName && $0.courseId == nil
        }) {
            var linkedCategory = unmatchedCategory
            linkedCategory.courseId = course.id
            linkedCategory.scheduleId = course.scheduleId
            linkedCategory.color = course.color
            eventManager.updateCategory(linkedCategory)
            return linkedCategory.id
        }

        // Create new category with proper linking
        let newCategory = Category(
            name: categoryName,
            color: course.color,
            scheduleId: course.scheduleId,
            courseId: course.id
        )
        print("CourseManager: Creating category '\(categoryName)' for course '\(course.name)'")
        eventManager.addCategory(newCategory)

        return newCategory.id
    }

    // MARK: - Category Naming Strategy

    /// Updates all linked category names based on the current naming format setting
    func updateAllCategoryNamesFromSetting() async {
        let format = UserDefaults.standard.string(forKey: "categoryTitleFormat") ?? "code"
        print("CourseManager: Updating category names (format: '\(format)')...")

        // Find all categories that are linked to courses
        let linkedCategories = eventManager.categories.filter { $0.courseId != nil }

        for category in linkedCategories {
            guard let courseId = category.courseId,
                  let course = courses.first(where: { $0.id == courseId }) else {
                continue
            }

            let expectedName = getCategoryNameForCourse(course)

            if category.name != expectedName {
                var updatedCategory = category
                updatedCategory.name = expectedName

                do {
                    try await eventManager.updateCategoryAsync(updatedCategory)
                } catch {
                    print("CourseManager: Failed to update category '\(category.name)': \(error)")
                }
            }
        }

        print("CourseManager: Category name update complete")
    }

    private func getCategoryNameForCourse(_ course: Course) -> String {
        let format = UserDefaults.standard.string(forKey: "categoryTitleFormat") ?? "code"

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📝 DEBUG: getCategoryNameForCourse()")
        print("   Course: '\(course.name)'")
        print("   Course Code: '\(course.courseCode)'")
        print("   UserDefaults format: '\(format)'")
        print("   Course code isEmpty: \(course.courseCode.isEmpty)")

        let result: String
        switch format {
        case "code":
            result = course.courseCode.isEmpty ? course.name : course.courseCode
            print("   Format is 'code', returning: '\(result)'")
        case "name":
            result = course.name
            print("   Format is 'name', returning: '\(result)'")
        default:
            result = course.courseCode.isEmpty ? course.name : course.courseCode
            print("   Format is default, returning: '\(result)'")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        return result
    }

    // MARK: - Enhanced Category Auto-Creation

    private func createLinkedCategoryForCourse(_ course: Course) async {
        // Check if category already exists for this course
        if let existingCategory = eventManager.categories.first(where: { $0.courseId == course.id }) {
            let expectedName = getCategoryNameForCourse(course)
            var needsUpdate = false
            var updatedCategory = existingCategory

            if existingCategory.color != course.color {
                updatedCategory.color = course.color
                needsUpdate = true
            }

            if existingCategory.name != expectedName {
                updatedCategory.name = expectedName
                needsUpdate = true
            }

            if existingCategory.scheduleId != course.scheduleId {
                updatedCategory.scheduleId = course.scheduleId
                needsUpdate = true
            }

            if needsUpdate {
                do {
                    try await eventManager.updateCategoryAsync(updatedCategory)
                } catch {
                    print("CourseManager: Failed to update category: \(error)")
                }
            }
            return
        }

        // Check if unlinked category with same name exists
        let categoryName = getCategoryNameForCourse(course)

        if let unmatchedCategory = eventManager.categories.first(where: {
            $0.name == categoryName && $0.courseId == nil
        }) {
            var linkedCategory = unmatchedCategory
            linkedCategory.courseId = course.id
            linkedCategory.scheduleId = course.scheduleId
            linkedCategory.color = course.color
            do {
                try await eventManager.updateCategoryAsync(linkedCategory)
            } catch {
                print("CourseManager: Failed to link category: \(error)")
            }
            return
        }

        // Create new category
        let newCategory = Category(
            name: categoryName,
            color: course.color,
            scheduleId: course.scheduleId,
            courseId: course.id
        )

        do {
            try await eventManager.addCategoryAsync(newCategory)
            print("CourseManager: Created category '\(categoryName)' for course '\(course.name)'")
        } catch {
            print("CourseManager: Failed to create category: \(error)")
        }
    }

    // MARK: - Bidirectional Sync: Category → Course

    func syncCourseFromCategory(courseId: UUID, newColor: Color, newName: String?) async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔄 DEBUG: syncCourseFromCategory() called")
        print("   Course ID: \(courseId.uuidString)")
        print("   New Color: \(newColor.toHex() ?? "nil")")
        print("   New Name: \(newName ?? "nil")")

        guard let courseIndex = courses.firstIndex(where: { $0.id == courseId }) else {
            print("⚠️ DEBUG: Course not found in local array")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            return
        }

        var course = courses[courseIndex]
        print("   Found course: '\(course.name)'")
        print("   Current course color: \(course.colorHex)")
        print("   Current course name: '\(course.name)'")

        var needsUpdate = false
        let newColorHex = newColor.toHex() ?? "007AFF"

        // Always sync color changes
        if course.colorHex != newColorHex {
            print("   ➜ Will update course color: \(course.colorHex) → \(newColorHex)")
            course.colorHex = newColorHex
            needsUpdate = true
        } else {
            print("   Color already matches, no update needed")
        }

        // Only sync name if provided (based on category naming format)
        if let newName = newName, course.name != newName {
            print("   ➜ Will update course name: '\(course.name)' → '\(newName)'")
            course.name = newName
            needsUpdate = true
        } else if let newName = newName {
            print("   Name already matches '\(newName)', no update needed")
        }

        if needsUpdate {
            print("✅ DEBUG: Updating course '\(course.name)' from category sync")

            // IMPORTANT: Update locally and save to database WITHOUT triggering category sync
            // (to avoid circular updates)
            courses[courseIndex] = course
            saveCoursesLocally()
            print("✅ DEBUG: Local update completed, saved to UserDefaults")

            // Sync to database
            if SupabaseService.shared.isAuthenticated {
                print("📤 DEBUG: Saving to database...")
                syncCourseToDatabase(course, action: .update)
                print("✅ DEBUG: Database save triggered")
            } else {
                print("⚠️ DEBUG: Not authenticated, skipping database sync")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        } else {
            print("⏭️ DEBUG: No changes needed for course")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }

    func reloadAssignmentsForCourse(_ courseId: UUID) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        
        do {
            let assignmentRepo = AssignmentRepository()
            let serverAssignments = try await assignmentRepo.findByCourse(courseId.uuidString)
            
            await MainActor.run {
                if let courseIndex = self.courses.firstIndex(where: { $0.id == courseId }) {
                    self.courses[courseIndex].assignments = serverAssignments
                    self.saveCoursesLocally()
                    print("🔄 UnifiedCourseManager: Reloaded \(serverAssignments.count) assignments for course from server")

                    // Create events for assignments with due dates
                    for assignment in serverAssignments {
                        self.createOrUpdateEventForAssignment(assignment, courseId: courseId)
                    }
                }
            }
        } catch {
            print("❌ UnifiedCourseManager: Failed to reload assignments for course: \(error)")
        }
    }

    // MARK: - Database Sync Operations
    
    private func syncCourseToDatabase(_ course: Course, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            return
        }
        
        let dbCourse = DatabaseCourse(from: course, userId: userId)
        
        do {
            let data = try JSONEncoder().encode(dbCourse)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .courses,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
        }
    }
    
    private func syncAssignmentToDatabase(_ assignment: Assignment, courseId: UUID, action: SyncAction) {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { return }
        let dbAssignment = DatabaseAssignment(
            from: assignment,
            userId: userId
        )
        
        do {
            let data = try JSONEncoder().encode(dbAssignment)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            let operation = SyncOperation(
                type: .assignments,
                action: action,
                data: dict
            )
            
            realtimeSyncManager.queueSyncOperation(operation)
        } catch {
        }
    }
    
    // MARK: - Enhanced Refresh with Sync
    
    func refreshCourseData() async {
        print("🔄 DEBUG: refreshCourseData started")
        isSyncing = true

        // Load current courses from storage first - this preserves meetings
        loadCourses()
        print("🔄 DEBUG: Loaded \(courses.count) courses from local storage")

        // If authenticated, load fresh course and meeting data from database
        var didLoadFromDatabase = false
        if SupabaseService.shared.isAuthenticated {
            await loadCoursesWithMeetingsFromDatabase()
            didLoadFromDatabase = true
        }

        // Refresh real-time sync data (this might override some data, but we've already loaded meetings)
        await realtimeSyncManager.refreshAllData()

        // Only backfill if we didn't load from database
        // (backfill checks individual courses, redundant after full database load)
        if !didLoadFromDatabase {
            await backfillUnsyncedCourses()
        }

        isInitialLoad = false
        lastSyncTime = Date()
        isSyncing = false
        print("🔄 UnifiedCourseManager: Course data refresh completed. Loaded \(courses.count) courses.")
    }
    
    // MARK: - New method to load courses with meetings from database
    private func loadCoursesWithMeetingsFromDatabase() async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else { 
            print("🔄 UnifiedCourseManager: Cannot load from database - no user ID")
            return 
        }
        
        do {
            print("🔄 UnifiedCourseManager: Loading courses with meetings from database...")
            #if DEBUG
            print("🔄 UnifiedCourseManager: User ID: \(userId)")
            #endif
            
            // Load courses from database
            let courseRepo = CourseRepository()
            let dbCourses = try await courseRepo.readAll(userId: userId)
            print("🔄 UnifiedCourseManager: Loaded \(dbCourses.count) courses from database")
            
            // Load all course meetings from database in one go
            let meetingRepo = CourseMeetingRepository()
            let allMeetings = try await meetingRepo.readAll(userId: userId)
            let meetingsByCode = Dictionary(grouping: allMeetings) { $0.courseId }
            print("🔄 UnifiedCourseManager: Loaded \(allMeetings.count) total meetings from database")

            // Debug: Print all meetings
            for meeting in allMeetings {
                print("  - Meeting ID: \(meeting.id), Course: \(meeting.courseId), Type: \(meeting.meetingType.displayName), Days: \(meeting.daysOfWeek)")
            }

            // Load all assignments from database
            let assignmentRepo = AssignmentRepository()
            var allAssignments: [Assignment] = []
            for course in dbCourses {
                do {
                    let courseAssignments = try await assignmentRepo.findByCourse(course.id.uuidString)
                    print("🔄 UnifiedCourseManager: Loaded \(courseAssignments.count) assignments for course '\(course.name)'")
                    for assignment in courseAssignments {
                        print("  📝 Assignment: '\(assignment.name)' (ID: \(assignment.id.uuidString.prefix(8)))")
                    }
                    allAssignments.append(contentsOf: courseAssignments)
                } catch {
                    print("⚠️ UnifiedCourseManager: Failed to load assignments for course '\(course.name)': \(error)")
                }
            }
            let assignmentsByCourse = Dictionary(grouping: allAssignments) { $0.courseId }
            print("🔄 UnifiedCourseManager: Loaded \(allAssignments.count) total assignments from database")

            var coursesWithMeetings: [Course] = []
            let existingCourses = self.courses // Preserve current local state

            for course in dbCourses {
                var enrichedCourse = course

                // ROBUST FIX: MERGE meetings with existing local state to preserve pending edits
                let remoteMeetings = meetingsByCode[course.id] ?? []
                let existingLocalCourse = existingCourses.first(where: { $0.id == course.id })
                let existingMeetings = existingLocalCourse?.meetings ?? []

                var mergedMeetings: [CourseMeeting] = []

                // For each remote meeting, prefer local version if pending
                for remoteMeeting in remoteMeetings {
                    if let localMeeting = existingMeetings.first(where: { $0.id == remoteMeeting.id }) {
                        if pendingMeetingUpdates.contains(localMeeting.id) {
                            mergedMeetings.append(localMeeting)
                        } else {
                            mergedMeetings.append(remoteMeeting)
                        }
                    } else {
                        mergedMeetings.append(remoteMeeting)
                    }
                }

                // Keep local-only meetings (pending creation)
                for localMeeting in existingMeetings {
                    if !remoteMeetings.contains(where: { $0.id == localMeeting.id }) {
                        mergedMeetings.append(localMeeting)
                    }
                }

                enrichedCourse.meetings = mergedMeetings
                print("🔄 UnifiedCourseManager: Course '\(course.name)' (ID: \(course.id)) has \(mergedMeetings.count) merged meetings (remote: \(remoteMeetings.count), local: \(existingMeetings.count))")

                // ROBUST FIX: Preserve gradeCurve from local state (NOT stored in database)
                // The gradeCurve field is only stored locally in UserDefaults, not synced to Supabase
                if let localCourse = existingLocalCourse {
                    enrichedCourse.gradeCurve = localCourse.gradeCurve
                    if localCourse.gradeCurve != 0.0 {
                        print("🔄 UnifiedCourseManager: Preserved gradeCurve \(localCourse.gradeCurve) for course '\(course.name)'")
                    }
                }

                // Assign assignments from database
                let courseAssignments = assignmentsByCourse[course.id] ?? []
                enrichedCourse.assignments = courseAssignments
                print("🔄 UnifiedCourseManager: Course '\(course.name)' (ID: \(course.id)) has \(courseAssignments.count) assignments from database")

                coursesWithMeetings.append(enrichedCourse)
            }

            // Update courses with database data - this should make meetings appear immediately
            self.courses = coursesWithMeetings

            // Batch event creation to prevent task explosion
            print("📅 UnifiedCourseManager: Batching event creation for assignments with due dates...")

            // Collect all assignments first to avoid triggering events while looping
            var assignmentsToSync: [(Assignment, UUID)] = []
            for course in coursesWithMeetings {
                for assignment in course.assignments where assignment.dueDate != nil {
                    assignmentsToSync.append((assignment, course.id))
                }
            }

            print("📅 UnifiedCourseManager: Found \(assignmentsToSync.count) assignments with due dates to sync")

            // Batch process (max 10 at a time) to prevent overwhelming the system
            Task { @MainActor in
                for chunk in assignmentsToSync.chunked(into: 10) {
                    for (assignment, courseId) in chunk {
                        self.createOrUpdateEventForAssignment(assignment, courseId: courseId)
                    }
                    // Small delay between chunks to prevent task explosion
                    try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                }
                print("✅ UnifiedCourseManager: Completed batched event creation for \(assignmentsToSync.count) assignments")
            }

            // Save to local storage so meetings persist across app restarts
            saveCoursesLocally()

            print("✅ UnifiedCourseManager: Successfully loaded \(coursesWithMeetings.count) courses with meetings from database")
            
        } catch {
            print("❌ UnifiedCourseManager: Failed to load courses with meetings from database: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error details: \(error.localizedDescription)")
        }
    }

    // MARK: - Sync Status Observation
    
    private func setupSyncStatusObservation() {
        realtimeSyncManager.$syncStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.syncStatus = status.displayName
                self?.isSyncing = status.isActive
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Save locally for offline support
    
    private func saveCoursesLocally() {
        CourseStorage.save(courses)
    }
    
    func loadCourses() {
        let storedCourses = CourseStorage.load()
        
        // CRITICAL FIX: Don't overwrite courses if they already have meetings and we're loading from storage
        // This prevents the sync process from wiping out meetings that were just loaded
        if courses.isEmpty {
            // Only load from storage if we have no courses yet
            self.courses = storedCourses
            print("🔄 UnifiedCourseManager: Loaded \(storedCourses.count) courses from storage (initial load)")
        } else if !storedCourses.isEmpty {
            // Merge stored courses with existing courses, preserving meetings
            print("🔄 UnifiedCourseManager: Merging \(storedCourses.count) stored courses with \(courses.count) existing courses")
            
            var mergedCourses = courses
            
            for storedCourse in storedCourses {
                if let existingIndex = mergedCourses.firstIndex(where: { $0.id == storedCourse.id }) {
                    // Preserve meetings from existing course if stored course doesn't have them
                    if !mergedCourses[existingIndex].meetings.isEmpty && storedCourse.meetings.isEmpty {
                        print("🔄 UnifiedCourseManager: Preserving \(mergedCourses[existingIndex].meetings.count) meetings for course '\(storedCourse.name)'")
                        var updatedCourse = storedCourse
                        updatedCourse.meetings = mergedCourses[existingIndex].meetings
                        mergedCourses[existingIndex] = updatedCourse
                    } else {
                        // Use stored version (it has more recent data or meetings)
                        mergedCourses[existingIndex] = storedCourse
                    }
                } else {
                    // Add new course from storage
                    mergedCourses.append(storedCourse)
                }
            }
            
            self.courses = mergedCourses
            print("🔄 UnifiedCourseManager: Merged courses - total: \(mergedCourses.count)")
        } else {
            print("🔄 UnifiedCourseManager: No stored courses to load, keeping existing \(courses.count) courses")
        }
        
        // Debug: Print course and meeting counts
        for course in courses {
            if !course.meetings.isEmpty {
                print("🔄 Course: \(course.name) has \(course.meetings.count) meetings")
            }
        }
    }

    func createCourseWithMeetings(_ course: Course, meetings: [CourseMeeting]) async throws {
        print("🔍 DEBUG: createCourseWithMeetings called")
        print("🔍 DEBUG: Course: '\(course.name)' with \(meetings.count) meetings")
        print("🔍 DEBUG: Authentication status: \(SupabaseService.shared.isAuthenticated)")
        print("🔍 DEBUG: User authenticated: \(SupabaseService.shared.currentUser != nil)")
        
        // Check authentication first
        guard SupabaseService.shared.isAuthenticated else {
            print("❌ DEBUG: User not authenticated")
            throw NSError(domain: "CourseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            #if DEBUG
            print("❌ DEBUG: No user ID available")
            #endif
            throw NSError(domain: "CourseManager", code: 402, userInfo: [NSLocalizedDescriptionKey: "No user ID available"])
        }

        // Validate course data
        guard !course.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            #if DEBUG
            print("❌ DEBUG: Course name is empty")
            #endif
            throw NSError(domain: "CourseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Course name cannot be empty"])
        }

        #if DEBUG
        print("🔍 DEBUG: User ID: \(userId)")
        print("🔍 DEBUG: Schedule ID: \(course.scheduleId)")
        #endif

        do {
            let courseRepo = CourseRepository()
            let meetingRepo = CourseMeetingRepository()

            #if DEBUG
            print("🔍 DEBUG: Creating course '\(course.name)' in database...")
            #endif

            // 1) Create the course in DB first
            let createdCourse = try await courseRepo.create(course, userId: userId)
            #if DEBUG
            print("🔍 DEBUG: ✅ Course created in database with ID: \(createdCourse.id)")
            #endif

            // 2) Create ALL meetings in database
            var savedMeetings: [CourseMeeting] = []
            #if DEBUG
            print("🔍 DEBUG: Creating \(meetings.count) meetings in database...")
            #endif

            for (idx, var meeting) in meetings.enumerated() {
                #if DEBUG
                print("🔍 DEBUG: Creating meeting \(idx + 1)/\(meetings.count): \(meeting.meetingType.displayName)")
                #endif
                
                // Ensure proper IDs are set - FIXED: userId is already a string, don't convert to UUID
                meeting.userId = UUID(uuidString: userId) // This should work if userId is valid UUID string
                meeting.courseId = createdCourse.id
                meeting.scheduleId = meeting.scheduleId ?? createdCourse.scheduleId
                
                // Validate that all required fields are set
                guard let meetingUserId = meeting.userId else {
                    #if DEBUG
                    print("❌ DEBUG: Failed to set userId for meeting")
                    #endif
                    throw NSError(domain: "CourseManager", code: 403, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
                }
                
                #if DEBUG
                print("🔍 DEBUG: Meeting details before save:")
                print("  - ID: \(meeting.id)")
                print("  - CourseId: \(meeting.courseId)")
                print("  - ScheduleId: \(String(describing: meeting.scheduleId))")
                print("  - UserId: \(String(describing: meeting.userId))")
                print("  - Days: \(meeting.daysOfWeek)")
                print("  - Start: \(meeting.startTime)")
                print("  - End: \(meeting.endTime)")
                #endif
                
                // Actually save to database
                let savedMeeting = try await meetingRepo.create(meeting, userId: userId)
                savedMeetings.append(savedMeeting)

                #if DEBUG
                print("🔍 DEBUG: ✅ Meeting '\(savedMeeting.displayName)' saved to database with ID: \(savedMeeting.id)")
                #endif
            }

            // 3) Update local store with database-saved data
            var courseWithMeetings = createdCourse
            courseWithMeetings.meetings = savedMeetings
            
            // Add to local courses array
            self.courses.append(courseWithMeetings)
            
            // Force UI update
            await MainActor.run {
                self.courses = self.courses
            }
            
            // Save to local storage
            self.saveCoursesLocally()

            // Auto-create linked category for the course
            await createLinkedCategoryForCourse(courseWithMeetings)

            // IMPORTANT: Store meetings in cache for realtime sync
            for meeting in savedMeetings {
                await CacheSystem.shared.courseMeetingCache.store(meeting)
            }

            // Schedule notifications for all meetings
            for meeting in savedMeetings {
                NotificationManager.shared.scheduleCourseMeetingNotifications(
                    for: meeting,
                    courseName: courseWithMeetings.name
                )
            }

            #if DEBUG
            print("🔍 DEBUG: ✅ Successfully created course with \(savedMeetings.count) meetings")
            print("🔍 DEBUG: Local courses count: \(self.courses.count)")
            #endif
            print("🔍 DEBUG: Course '\(courseWithMeetings.name)' has \(courseWithMeetings.meetings.count) meetings")

            // Debug: Print each meeting
            for meeting in courseWithMeetings.meetings {
                print("🔍 DEBUG: Meeting '\(meeting.displayName)' on days \(meeting.daysOfWeek) at \(meeting.timeRange)")
            }
        } catch {
            print("🛑 createCourseWithMeetings FAILED: \(error)")
            print("🛑 Error type: \(type(of: error))")
            print("🛑 Error details: \(error.localizedDescription)")
            
            // Check specific error types
            if let urlError = error as? URLError {
                print("🛑 URLError: \(urlError)")
                print("🛑 URLError code: \(urlError.code)")
            }
            
            // Check if it's a Supabase-related error
            if error.localizedDescription.contains("PGRST") {
                print("🛑 Database error detected: \(error.localizedDescription)")
            }
            
            // Re-throw the error so caller knows it failed
            throw error
        }
    }
}

extension UnifiedCourseManager {
    private func backfillUnsyncedCourses() async {
        guard SupabaseService.shared.isAuthenticated,
              let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            return
        }
        
        let courseRepo = CourseRepository()
        
        for (index, course) in courses.enumerated() {
            do {
                let remote = try await courseRepo.read(id: course.id.uuidString)
                if remote == nil {
                    print("☁️ Backfill: Creating course remotely: \(course.name)")
                    let createdCourse = try await courseRepo.create(course, userId: userId)
                    
                    var updated = createdCourse
                    updated.assignments = course.assignments
                    
                    if index < courses.count, courses[index].id == course.id {
                        courses[index] = updated
                    } else if let idx = courses.firstIndex(where: { $0.id == course.id }) {
                        courses[idx] = updated
                    }
                    
                    await CacheSystem.shared.courseCache.update(updated)
                    print("☁️ Backfill: ✅ Created course '\(updated.name)'")
                }
            } catch {
                print("⚠️ Backfill: Failed to backfill course \(course.name): \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Array Helpers
extension Array {
    /// Splits array into chunks of specified size
    /// Used to batch process large operations and prevent overwhelming the system
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}