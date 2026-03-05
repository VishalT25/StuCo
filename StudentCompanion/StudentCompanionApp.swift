import SwiftUI
import WidgetKit
import RevenueCat
import Combine

@main
struct StudentCompanionApp: SwiftUI.App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var realtimeSyncManager = RealtimeSyncManager.shared
    @StateObject private var scheduleManager = ScheduleManager()
    @StateObject private var academicCalendarManager = AcademicCalendarManager()
    @StateObject private var unifiedCourseManager = UnifiedCourseManager()
    @StateObject private var eventManager = EventManager.shared
    @StateObject private var eventViewModel = EventViewModel()
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var guidedOnboardingManager = GuidedOnboardingManager.shared

    @State private var showPasswordReset = false
    @State private var passwordResetToken: String?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(supabaseService)
                .environmentObject(realtimeSyncManager)
                .environmentObject(eventViewModel)
                .environmentObject(scheduleManager)
                .environmentObject(academicCalendarManager)
                .environmentObject(unifiedCourseManager)
                .environmentObject(eventManager)
                .environmentObject(purchaseManager)
                .environmentObject(guidedOnboardingManager)
                .onAppear {
                    // Configure RevenueCat
                    configureRevenueCat()

                    // Setup authentication listener for RevenueCat user sync
                    setupAuthenticationListener()

                    // Request notification permissions early
                    Task {
                        print("📱 App: Requesting notification permissions")
                        await NotificationManager.shared.requestAuthorization()
                    }

                    // Initialize real-time sync when app starts
                    Task {
                        print("📱 App: Starting RealtimeSyncManager initialization")
                        await realtimeSyncManager.initialize()
                        print("📱 App: RealtimeSyncManager initialization completed")
                    }

                    // Set up cross-manager relationships
                    setupManagerRelationships()

                    print("App: Managers initialized:")
                    print("   - scheduleManager: \(scheduleManager.scheduleCollections.count) schedules")
                    print("   - academicCalendarManager: \(academicCalendarManager.academicCalendars.count) calendars")
                    print("   - unifiedCourseManager: \(unifiedCourseManager.courses.count) courses")
                    print("   - eventManager: \(eventManager.eventCount) events")
                    print("   - eventViewModel: \(eventViewModel.events.count) events")

                    // Run category-course migration if needed
                    Task {
                        let migrationKey = "categoryCourseMigrationCompleted_v1"
                        let hasRunMigration = UserDefaults.standard.bool(forKey: migrationKey)

                        if !hasRunMigration && SupabaseService.shared.isAuthenticated {
                            let migration = CategoryCourseMigration(
                                courseManager: unifiedCourseManager,
                                eventManager: eventManager
                            )
                            await migration.executeMigration()
                            UserDefaults.standard.set(true, forKey: migrationKey)
                        }
                    }

                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }

                .onChange(
                    of: scheduleManager.scheduleCollections.map {
                        "\($0.id.uuidString)|\($0.lastModified.timeIntervalSince1970)|\($0.scheduleItems.count)|\($0.enhancedScheduleItems.count)"
                    }
                ) { _, _ in
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }

                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    ScheduleWidgetBridge.pushTodaySnapshot(scheduleManager: scheduleManager)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    // Cleanup real-time connections when app terminates
                    Task {
                        await realtimeSyncManager.cleanup()
                    }
                }
                .onOpenURL { url in
                    // Handle OAuth callbacks
                    handleOAuthCallback(url: url)
                }
                .fullScreenCover(isPresented: $showPasswordReset) {
                    if let token = passwordResetToken {
                        PasswordResetView(
                            isPresented: $showPasswordReset,
                            accessToken: token
                        )
                        .environmentObject(supabaseService)
                        .environmentObject(themeManager)
                        .onDisappear {
                            // Clear token after dismissal
                            passwordResetToken = nil
                        }
                    }
                }
        }
    }
    
    private func setupManagerRelationships() {
        print("App: Setting up manager relationships...")

        // Connect course manager to schedule manager for schedule item synchronization
        unifiedCourseManager.setScheduleManager(scheduleManager)
        scheduleManager.setCourseManager(unifiedCourseManager)

        // BIDIRECTIONAL: Connect EventManager ↔ CourseManager
        // EventManager is a singleton, CourseManager accesses it via EventManager.shared
        // Category → Course sync (for bidirectional updates)
        eventManager.setCourseManager(unifiedCourseManager)

        // Connect event view model to schedule manager for category grouping
        eventViewModel.scheduleManager = scheduleManager

        print("App: Manager relationships setup completed")
    }

    private func configureRevenueCat() {
        print("💰 App: Configuring RevenueCat...")

        // Get user ID from Supabase if authenticated
        let userID = supabaseService.currentUser?.id.uuidString

        purchaseManager.configure(appUserID: userID)

        print("💰 App: RevenueCat configured with user ID: \(userID ?? "anonymous")")

        // Sync entitlements on launch
        Task {
            await purchaseManager.fetchCustomerInfo()
            // Tier sync happens automatically in fetchCustomerInfo
        }
    }

    private func setupAuthenticationListener() {
        // Listen for auth state changes
        NotificationCenter.default.addObserver(
            forName: .init("SupabaseAuthStateChanged"),
            object: nil,
            queue: .main
        ) { [purchaseManager, supabaseService] notification in
            guard let isSignedIn = notification.object as? Bool else { return }

            if isSignedIn {
                // User signed in - sync RevenueCat user ID
                Task {
                    if let userId = supabaseService.currentUser?.id.uuidString {
                        await purchaseManager.syncUserID(userId)
                    }
                }
            } else {
                // User signed out - log out from RevenueCat
                Task {
                    await purchaseManager.logOut()
                }
            }
        }
    }

    private func handleOAuthCallback(url: URL) {
        print("📱 App: Received callback URL: \(url)")

        // Handle stuco:// deep links
        if url.scheme == "stuco" {
            if url.host == "auth" {
                // Handle email confirmation callback
                if url.path.contains("/callback") || url.path.contains("callback") {
                    print("📱 App: Email verification callback received")
                    // User verified their email, they can now sign in
                    // The verification is already complete, just show a success message
                    return
                }

                // Handle password reset callback
                if url.path.contains("/reset-password") || url.path.contains("reset-password") {
                    print("📱 App: Password reset callback received")

                    // Extract tokens from URL
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                       let queryItems = components.queryItems {

                        let accessToken = queryItems.first(where: { $0.name == "access_token" })?.value
                        let type = queryItems.first(where: { $0.name == "type" })?.value

                        if let accessToken = accessToken, type == "recovery" {
                            #if DEBUG
                            print("🔑 App: Password reset token received, showing reset screen")
                            #endif

                            // Store token and present password reset view
                            DispatchQueue.main.async {
                                passwordResetToken = accessToken
                                showPasswordReset = true
                            }
                        }
                    }
                    return
                }
            }
        }

        // Check if this is an OAuth callback
        if url.scheme == "com.vishal.StudentCompanion" && url.host == "oauth" {
            Task {
                let result = await supabaseService.handleOAuthCallback(url: url)
                switch result {
                case .success(let user):
                    #if DEBUG
                    print("📱 App: OAuth callback successful, user authenticated: \(user.id)")
                    #endif
                    // Authentication state will be updated via listener
                case .failure(let error):
                    #if DEBUG
                    print("📱 App: OAuth callback failed: \(error)")
                    #endif
                }
            }
        }
    }
}