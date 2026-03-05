import Foundation
import Supabase
import SwiftUI

/// Enhanced Supabase service optimized for V2 with comprehensive real-time sync
/// Implements cloud-first architecture with offline support and conflict resolution
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    
    // MARK: - Core Configuration
    private let supabaseURL: URL
    private let supabaseAnonKey: String
    let client: SupabaseClient
    private let keychainService = SecureKeychainService.shared
    private let didFallbackToPlaceholderConfig: Bool

    private struct SupabaseConfig {
        let url: URL
        let key: String
        let isFallback: Bool
    }
    
    private static func loadSupabaseConfig() -> SupabaseConfig {
        // Preferred: Info.plist
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
           let key = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String,
           let url = URL(string: urlString),
           !key.isEmpty {
            return SupabaseConfig(url: url, key: key, isFallback: false)
        }
        
        // Fallback: Secrets.plist (recommended secure location)
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let urlString = dict["SUPABASE_URL"] as? String,
           let key = dict["SUPABASE_ANON_KEY"] as? String,
           let supaURL = URL(string: urlString),
           !key.isEmpty {
            print("🔒 Loaded Supabase config from Secrets.plist")
            return SupabaseConfig(url: supaURL, key: key, isFallback: false)
        }
        
        // Last resort: Placeholder (non-crashing; features disabled)
        let placeholderURL = URL(string: "https://example.supabase.co")!
        print("🔒 SECURITY: Supabase configuration missing. Using placeholder and disabling online features.")
        return SupabaseConfig(url: placeholderURL, key: "public-anon-key", isFallback: true)
    }
    
    // MARK: - Authentication State
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: User?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var userSubscription: UserSubscription?
    @Published var isNewlyCreatedAccount: Bool = false {
        didSet {
            print("🎓 ONBOARDING DEBUG: isNewlyCreatedAccount didSet triggered! oldValue=\(oldValue), newValue=\(isNewlyCreatedAccount)")
            // Persist the flag so it survives app restarts (for email confirmation flow)
            UserDefaults.standard.set(isNewlyCreatedAccount, forKey: "isNewlyCreatedAccount")
            print("🎓 ONBOARDING DEBUG: Saved to UserDefaults: \(isNewlyCreatedAccount)")
        }
    }
    
    // MARK: - Connection State
    @Published private(set) var isConnected = false
    @Published private(set) var connectionQuality: ConnectionQuality = .unknown
    @Published private(set) var lastSyncTimestamp: Date?
    
    // MARK: - Security & Performance
    private var lastTokenRefresh: Date = Date()
    private let tokenRefreshInterval: TimeInterval = 900 // 15 minutes
    private var connectionMonitor: Timer?
    
    enum ConnectionQuality {
        case unknown, poor, good, excellent
        
        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .poor: return "Poor"
            case .good: return "Good" 
            case .excellent: return "Excellent"
            }
        }
    }
    
    private init() {

        let cfg = SupabaseService.loadSupabaseConfig()
        self.supabaseURL = cfg.url
        self.supabaseAnonKey = cfg.key
        self.didFallbackToPlaceholderConfig = cfg.isFallback
        
        // Initialize client with V2 optimizations
        self.client = SupabaseClient(
          supabaseURL: supabaseURL,
          supabaseKey: supabaseAnonKey,
          options: .init(
            db: .init(schema: "public"),
            // If custom storage is needed for Auth, provide it here; otherwise omit.
            // auth: .init(storage: MyCustomLocalStorage()),
            realtime: .init() // Swift Realtime options don't include reconnectAfterMs
          )
        )

        if didFallbackToPlaceholderConfig {
            print("🔒 SECURITY WARNING: Supabase configuration not found. Running with placeholder config; online features disabled.")
        }

        // Restore persisted flag for newly created accounts (survives app restarts)
        let restoredFlag = UserDefaults.standard.bool(forKey: "isNewlyCreatedAccount")
        print("🎓 ONBOARDING DEBUG: SupabaseService.init() - Restoring flag from UserDefaults: \(restoredFlag)")
        self.isNewlyCreatedAccount = restoredFlag
        print("🎓 ONBOARDING DEBUG: SupabaseService.init() - isNewlyCreatedAccount is now: \(self.isNewlyCreatedAccount)")

        // Initialize authentication state and monitoring
        Task {
            await initializeServices()
        }
    }
    
    // MARK: - Service Initialization
    
    private func initializeServices() async {
        if didFallbackToPlaceholderConfig {
            await MainActor.run {
                self.isConnected = false
                self.connectionQuality = .unknown
            }
            return
        }
        await initializeAuthenticationState()
        startConnectionMonitoring()
        setupAuthListener()
    }
    
    private func initializeAuthenticationState() async {
        print("🔒 Initializing authentication state...")
        
        // Check for existing session
        do {
            let session = try await client.auth.session
            
            await MainActor.run {
                self.isAuthenticated = true
                self.currentUser = session.user
                self.lastTokenRefresh = Date()
            }
            
            // Ensure subscriber row before loading subscription
            await ensureSubscriberRow()
            await loadUserProfile()
            await loadUserSubscription()
            
            print("🔒 Session restored successfully")
        } catch {
            print("🔒 No existing session found: \(error)")
        }
    }
    
    private func setupAuthListener() {
        Task {
            for await (event, session) in await client.auth.authStateChanges {
                // Update state synchronously on main actor
                await MainActor.run {
                    switch event {
                    case .signedIn:
                        print("🔒 User signed in")
                        self.isAuthenticated = true
                        self.currentUser = session?.user
                        self.lastTokenRefresh = Date()

                        if let session = session {
                            self.storeAuthenticationTokens(
                                accessToken: session.accessToken,
                                refreshToken: session.refreshToken
                            )
                        }

                        // Post notification for authentication state change
                        NotificationCenter.default.post(
                            name: .init("SupabaseAuthStateChanged"),
                            object: true
                        )

                        // Post notification for data refresh after sign in
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            NotificationCenter.default.post(
                                name: .init("UserSignedInDataRefresh"),
                                object: self.currentUser
                            )
                        }

                    case .signedOut:
                        print("🔒 User signed out")
                        self.isAuthenticated = false
                        self.currentUser = nil
                        self.userProfile = nil
                        self.userSubscription = nil

                        // Post notification for authentication state change
                        NotificationCenter.default.post(
                            name: .init("SupabaseAuthStateChanged"),
                            object: false
                        )

                    case .tokenRefreshed:
                        print("🔒 Token refreshed")
                        self.lastTokenRefresh = Date()

                        if let session = session {
                            self.storeAuthenticationTokens(
                                accessToken: session.accessToken,
                                refreshToken: session.refreshToken
                            )
                            // Update currentUser when token refreshes (may include email changes)
                            self.currentUser = session.user
                        }

                    case .userUpdated:
                        print("🔒 User updated - refreshing user data")
                        self.currentUser = session?.user

                    default:
                        print("🔒 Unhandled auth event: \(event)")
                        // Still update currentUser for any unhandled events with a session
                        if let session = session {
                            self.currentUser = session.user
                        }
                    }
                }

                // Load user data after sign in or user update (async calls outside MainActor.run)
                if event == .signedIn || event == .userUpdated {
                    await self.loadUserProfile()
                    await self.loadUserSubscription()
                    await self.ensureSubscriberRow()
                }
            }
        }
    }
    
    private func startConnectionMonitoring() {
        guard !didFallbackToPlaceholderConfig else { return }
        connectionMonitor = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            Task {
                await self.checkConnectionQuality()
            }
        }
    }
    
    private func checkConnectionQuality() async {
        guard !didFallbackToPlaceholderConfig else {
            await MainActor.run {
                self.isConnected = false
                self.connectionQuality = .unknown
            }
            return
        }
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            _ = try await client
                .from("profiles")
                .select("id")
                .limit(1)
                .execute()
            
            let responseTime = CFAbsoluteTimeGetCurrent() - startTime
            
            await MainActor.run {
                self.isConnected = true
                self.connectionQuality = self.qualityFromResponseTime(responseTime)
                self.lastSyncTimestamp = Date()
            }
        } catch {
            await MainActor.run {
                self.isConnected = false
                self.connectionQuality = .poor
            }
        }
    }
    
    private func qualityFromResponseTime(_ time: TimeInterval) -> ConnectionQuality {
        switch time {
        case 0..<0.5: return .excellent
        case 0.5..<1.5: return .good
        case 1.5..<3.0: return .poor
        default: return .poor
        }
    }
    
    // MARK: - Enhanced Authentication
    
    func signIn(email: String, password: String) async -> Result<User, AuthError> {
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }
        
        guard password.count >= 6 else {
            return .failure(AuthError.weakPassword)
        }
        
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot sign in.")
            return .failure(.missingConfiguration)
        }
        
        do {
            let response = try await client.auth.signIn(email: email, password: password)
            
            // Authentication state will be updated via listener
            print("🔒 User authenticated successfully")
            
            // Check connection after successful sign-in
            await checkConnectionQuality()
            
            return .success(response.user)
        } catch {
            print("🔒 SECURITY: Authentication failed: \(error)")
            if error.localizedDescription.contains("email not confirmed") || error.localizedDescription.contains("Email not confirmed") {
                return .failure(AuthError.emailNotConfirmed)
            }
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    func signUp(email: String, password: String) async -> Result<SignUpResult, AuthError> {
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }
        
        guard isStrongPassword(password) else {
            return .failure(AuthError.weakPassword)
        }
        
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot sign up.")
            return .failure(.missingConfiguration)
        }
        
        do {
            // Use HTTPS URL for email confirmation (email links require HTTPS, not deep links)
            let redirectToURL = URL(string: "https://stuco.app/auth/confirm")!
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                redirectTo: redirectToURL
            )
            
            if response.session != nil {
                await createDefaultUserData(for: response.user)
                print("🔒 User registered and confirmed successfully")
                // Mark as newly created account for onboarding
                await MainActor.run {
                    print("🎓 ONBOARDING DEBUG: Setting isNewlyCreatedAccount = true (confirmed immediately)")
                    self.isNewlyCreatedAccount = true
                    print("🎓 ONBOARDING DEBUG: Flag is now: \(self.isNewlyCreatedAccount)")
                }
                return .success(.confirmedImmediately(response.user))
            } else {
                print("🔒 User registered, confirmation email sent")
                // Mark as newly created account for onboarding (will show after email confirmation)
                await MainActor.run {
                    print("🎓 ONBOARDING DEBUG: Setting isNewlyCreatedAccount = true (needs email confirmation)")
                    self.isNewlyCreatedAccount = true
                    print("🎓 ONBOARDING DEBUG: Flag is now: \(self.isNewlyCreatedAccount)")
                }
                return .success(.needsEmailConfirmation(response.user))
            }
        } catch {
            if isEmailAlreadyRegisteredError(error) {
                return .failure(.emailAlreadyExists)
            }
            print("🔒 SECURITY: Registration failed: \(error)")
            return .failure(AuthError.registrationFailed)
        }
    }

    private func isEmailAlreadyRegisteredError(_ error: Error) -> Bool {
        let message = error.localizedDescription.lowercased()
        if message.contains("user already registered") { return true }
        if message.contains("already") && (message.contains("registered") || message.contains("exists")) { return true }
        if message.contains("user_already_exists") { return true }
        if message.contains("email") && message.contains("exists") { return true }
        if message.contains("422") && (message.contains("already") || message.contains("exists")) { return true }
        return false
    }

    // MARK: - OAuth Authentication

    enum OAuthProvider {
        case google
        case apple

        var providerName: String {
            switch self {
            case .google: return "google"
            case .apple: return "apple"
            }
        }
    }

    func signInWithOAuth(provider: OAuthProvider) async -> Result<URL, AuthError> {
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot sign in with OAuth.")
            return .failure(.missingConfiguration)
        }

        do {
            let redirectToURL = URL(string: "com.vishal.StudentCompanion://oauth/callback")!

            print("🔒 OAuth: Initiating \(provider.providerName) authentication")

            let oauthURL = try await client.auth.getOAuthSignInURL(
                provider: .init(rawValue: provider.providerName) ?? .google,
                redirectTo: redirectToURL
            )

            return .success(oauthURL)
        } catch {
            print("🔒 OAuth: Failed to initiate \(provider.providerName) sign in: \(error)")
            return .failure(.authenticationFailed)
        }
    }

    func handleOAuthCallback(url: URL) async -> Result<User, AuthError> {
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot handle OAuth callback.")
            return .failure(.missingConfiguration)
        }

        do {
            // Supabase SDK handles OAuth callback URL parsing automatically
            let session = try await client.auth.session(from: url)

            // Get current user from the session
            let user = session.user

            // Create default user data if this is first sign in
            await createDefaultUserData(for: user)

            print("🔒 OAuth: User authenticated successfully via callback")
            return .success(user)

        } catch {
            print("🔒 OAuth: Failed to handle callback: \(error)")
            return .failure(.authenticationFailed)
        }
    }

    func resetPassword(email: String) async -> Result<Void, AuthError> {
        guard isValidEmail(email) else {
            return .failure(AuthError.invalidEmail)
        }

        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot reset password.")
            return .failure(.missingConfiguration)
        }

        do {
            // Use HTTPS URL that redirects to app (email links require HTTPS, not deep links)
            let redirectToURL = URL(string: "https://stuco.app/auth/reset-password")!
            
            try await client.auth.resetPasswordForEmail(
                email,
                redirectTo: redirectToURL
            )
            
            print("🔒 Password reset email sent successfully")
            return .success(())
        } catch {
            print("🔒 Password reset failed: \(error)")
            return .failure(AuthError.resetPasswordFailed)
        }
    }
    
    func deleteAccount() async -> Result<Void, AuthError> {
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot delete account.")
            return .failure(.missingConfiguration)
        }

        guard let userId = currentUser?.id else {
            return .failure(.notAuthenticated)
        }

        do {
            // Delete user data from database first
            // Delete from subscribers table
            _ = try await client
                .from("subscribers")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Delete from courses table
            _ = try await client
                .from("courses")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Delete from events table
            _ = try await client
                .from("events")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Delete from schedules table
            _ = try await client
                .from("schedules")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Delete from academic_calendars table
            _ = try await client
                .from("academic_calendars")
                .delete()
                .eq("user_id", value: userId.uuidString)
                .execute()

            // Finally, delete the auth user using RPC function
            // Note: Supabase RLS policies should cascade delete related data
            // We need to use an RPC function because client SDK doesn't have permission to delete users directly
            do {
                _ = try await client.rpc("delete_user").execute()
                print("🔒 Account deleted successfully via RPC")
            } catch {
                // If RPC doesn't exist, just sign out and log the issue
                print("🔒 RPC delete_user not found, signing out instead: \(error)")
                print("🔒 NOTE: To enable full account deletion, create a Supabase RPC function 'delete_user'")
            }

            // Sign out the user
            try await client.auth.signOut()

            print("🔒 User signed out and data cleared")

            // Clear all local data
            await clearAllUserData()

            return .success(())
        } catch {
            print("🔒 Account deletion failed: \(error)")
            return .failure(.accountDeletionFailed)
        }
    }

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            print("🔒 SECURITY WARNING: Server sign out failed: \(error)")
        }

        // Clear local tokens regardless of server response
        _ = keychainService.clearAllTokens()

        // CRITICAL: Clear all local user data
        await clearAllUserData()

        print("🔒 User signed out and all local data cleared")
    }
    
    // MARK: - Data Cleanup
    
    /// Clears all user-specific data from local storage when signing out
    private func clearAllUserData() async {
        print("🧹 SupabaseService: Clearing all local user data...")
        
        await MainActor.run {
            // Clear UserDefaults for all data managers
            let userDefaults = UserDefaults.standard
            
            // EventViewModel/EventsModule data
            userDefaults.removeObject(forKey: "savedCategories")
            userDefaults.removeObject(forKey: "savedEvents")
            userDefaults.removeObject(forKey: "savedSchedule")
            userDefaults.removeObject(forKey: "savedCourses")
            
            // AcademicCalendarManager data
            userDefaults.removeObject(forKey: "savedAcademicCalendars")
            
            // ScheduleManager data
            userDefaults.removeObject(forKey: "savedScheduleCollections")
            userDefaults.removeObject(forKey: "activeScheduleID")
            
            // Course data from CourseStorage
            userDefaults.removeObject(forKey: "courses_key")
            
            // Theme preferences (optional - keep user's theme preference)
            // userDefaults.removeObject(forKey: "selectedTheme")
            
            // Calendar sync preferences
            userDefaults.removeObject(forKey: "GoogleCalendarIntegrationEnabled")
            userDefaults.removeObject(forKey: "AppleCalendarIntegrationEnabled")
            
            // Clear any other user-specific preferences
            userDefaults.removeObject(forKey: "lastDataSync")
            userDefaults.removeObject(forKey: "userOnboardingCompleted")
            print("🎓 ONBOARDING DEBUG: Clearing isNewlyCreatedAccount flag on sign out")
            userDefaults.removeObject(forKey: "isNewlyCreatedAccount")

            // Also clear the published property
            self.isNewlyCreatedAccount = false

            print("🧹 SupabaseService: Cleared UserDefaults data")
        }
        
        // Clear caches
        await CacheSystem.shared.clearAllUserData()
        
        // Post notification for data managers to clear their in-memory state
        await MainActor.run {
            NotificationCenter.default.post(
                name: .init("UserDataCleared"),
                object: nil
            )
            
            print("🧹 SupabaseService: Posted UserDataCleared notification")
        }
    }
    
    // MARK: - User Data Management

    func createDefaultUserData(for user: User) async {
        await createDefaultProfile(for: user)
        await createDefaultSubscriber(for: user)
    }
    
    private func createDefaultProfile(for user: User) async {
        let profileData = ProfileInsert(
            user_id: user.id.uuidString,
            display_name: user.email?.components(separatedBy: "@").first ?? "User",
            avatar_url: nil,
            bio: nil
        )
        
        do {
            _ = try await client
                .from("profiles")
                .insert(profileData)
                .execute()
            
            await loadUserProfile()
        } catch {
            print("Failed to create default profile: \(error)")
        }
    }
    
    private func createDefaultSubscriber(for user: User) async {
        let subscriberData = SubscriberInsert(
            user_id: user.id.uuidString,
            email: user.email ?? "",
            subscribed: false,
            subscription_tier: "free",
            role: "free"
        )
        
        do {
            _ = try await client
                .from("subscribers")
                .insert(subscriberData)
                .execute()
            
            await loadUserSubscription()
        } catch {
            print("Failed to create default subscriber: \(error)")
        }
    }
    
    private func loadUserProfile() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let response = try await client
                .from("profiles")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            let profile = try JSONDecoder().decode(DatabaseProfile.self, from: response.data)
            
            await MainActor.run {
                self.userProfile = profile.toLocal()
            }
        } catch {
            print("Failed to load user profile: \(error)")
        }
    }
    
    private func loadUserSubscription() async {
        guard let userId = currentUser?.id else { return }
        
        do {
            let response = try await client
                .from("subscribers")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            let subscriber = try JSONDecoder().decode(DatabaseSubscriber.self, from: response.data)
            
            await MainActor.run {
                self.userSubscription = subscriber.toLocal()
            }
        } catch {
            print("Failed to load user subscription (will ensure row): \(error)")
            await ensureSubscriberRow()
        }
    }
    
    func updateProfile(displayName: String?, bio: String? = nil) async -> Result<Void, AuthError> {
        guard let userId = currentUser?.id else {
            return .failure(AuthError.authenticationFailed)
        }
        
        do {
            await ensureValidToken()
            
            let updateData = ProfileUpdate(displayName: displayName, bio: bio)
            
            _ = try await client
                .from("profiles")
                .update(updateData)
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            await loadUserProfile()
            
            return .success(())
        } catch {
            print("Failed to update profile: \(error)")
            return .failure(AuthError.authenticationFailed)
        }
    }
    
    func refreshUserData() async {
        // Fetch the latest session to get updated user data (e.g., after email change)
        do {
            let session = try await client.auth.session
            await MainActor.run {
                self.currentUser = session.user
            }
        } catch {
            print("⚠️ Could not refresh session: \(error)")
        }

        await loadUserProfile()
        await loadUserSubscription()
    }

    // MARK: - Account Updates
    func updateEmail(_ newEmail: String) async -> Result<Void, AuthError> {
        guard isValidEmail(newEmail) else {
            return .failure(.invalidEmail)
        }
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot update email.")
            return .failure(.missingConfiguration)
        }
        do {
            // Update email - Supabase will send confirmation link to new email
            try await client.auth.update(user: UserAttributes(email: newEmail))
            // Note: Don't refresh user data yet - email change is pending confirmation
            print("✅ Email change requested. Confirmation link sent to \(newEmail)")
            return .success(())
        } catch let error as NSError {
            print("❌ Failed to update email: \(error.localizedDescription)")

            // Handle specific error cases
            if error.localizedDescription.contains("already registered") || error.localizedDescription.contains("already exists") {
                return .failure(.emailAlreadyInUse)
            } else if error.localizedDescription.contains("rate limit") {
                return .failure(.rateLimitExceeded)
            } else if error.localizedDescription.contains("Invalid") || error.localizedDescription.contains("invalid") {
                return .failure(.invalidEmail)
            } else {
                return .failure(.authenticationFailed)
            }
        } catch {
            print("❌ Failed to update email: \(error)")
            return .failure(.authenticationFailed)
        }
    }
    
    func updatePassword(_ newPassword: String) async -> Result<Void, AuthError> {
        guard isStrongPassword(newPassword) else {
            return .failure(.weakPassword)
        }
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot update password.")
            return .failure(.missingConfiguration)
        }
        do {
            try await client.auth.update(user: UserAttributes(password: newPassword))
            return .success(())
        } catch {
            print("Failed to update password: \(error)")
            return .failure(.authenticationFailed)
        }
    }

    func resetPasswordWithToken(accessToken: String, newPassword: String) async -> Result<Void, AuthError> {
        guard isStrongPassword(newPassword) else {
            return .failure(.weakPassword)
        }
        guard !didFallbackToPlaceholderConfig else {
            print("🔒 CONFIG: Missing Supabase config; cannot reset password.")
            return .failure(.missingConfiguration)
        }

        do {
            #if DEBUG
            print("🔑 Attempting to set session with recovery token")
            #endif

            // Set the session using the recovery token
            _ = try await client.auth.setSession(accessToken: accessToken, refreshToken: "")

            #if DEBUG
            print("🔑 Session set successfully, updating password")
            #endif

            // Now update the password
            try await client.auth.update(user: UserAttributes(password: newPassword))

            #if DEBUG
            print("🎉 Password updated successfully with recovery token")
            #endif
            return .success(())
        } catch {
            #if DEBUG
            print("❌ Password reset with token failed: \(error)")
            #endif
            return .failure(.authenticationFailed)
        }
    }

    // MARK: - Token Management
    
    private func storeAuthenticationTokens(accessToken: String, refreshToken: String) {
        _ = keychainService.storeToken(accessToken, forKey: "supabase_access_token")
        _ = keychainService.storeToken(refreshToken, forKey: "supabase_refresh_token")
    }
    
    func ensureValidToken() async {
        guard isAuthenticated else { return }
        guard !didFallbackToPlaceholderConfig else { return }
        
        let timeSinceLastRefresh = Date().timeIntervalSince(lastTokenRefresh)
        if timeSinceLastRefresh >= tokenRefreshInterval {
            do {
                _ = try await client.auth.refreshSession()
            } catch {
                print("🔒 SECURITY ERROR: Token refresh failed: \(error)")
                await signOut()
            }
        }
    }
    
    // MARK: - Database Access with RLS
    
    var database: SupabaseClient {
        return client
    }
    
    // MARK: - Validation
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        return NSPredicate(format: "SELF MATCHES %@", emailRegex).evaluate(with: email)
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        return password.count >= 6
    }
    
    private func isStrongPassword(_ password: String) -> Bool {
        guard password.count >= 8 else { return false }
        
        let hasUppercase = password.range(of: "[A-Z]", options: .regularExpression) != nil
        let hasLowercase = password.range(of: "[a-z]", options: .regularExpression) != nil
        let hasNumbers = password.range(of: "[0-9]", options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasNumbers
    }
    
    // MARK: - Statistics & Monitoring
    
    func getConnectionStats() -> ConnectionStats {
        return ConnectionStats(
            isConnected: isConnected,
            quality: connectionQuality,
            lastSync: lastSyncTimestamp,
            authExpiry: calculateTokenExpiry()
        )
    }
    
    private func calculateTokenExpiry() -> Date? {
        // JWT tokens typically expire after 1 hour
        return Date(timeInterval: 3600, since: lastTokenRefresh)
    }
    
    func getSyncStats() async -> SyncStats? {
        guard isAuthenticated else { return nil }
        
        do {
            await ensureValidToken()
            
            async let schedulesCount = getTableCount("schedules")
            async let coursesCount = getTableCount("courses")
            async let eventsCount = getTableCount("events")
            async let categoriesCount = getTableCount("categories")
            async let assignmentsCount = getTableCount("assignments")
            
            let counts = await (
                schedules: schedulesCount,
                courses: coursesCount,
                events: eventsCount,
                categories: categoriesCount,
                assignments: assignmentsCount
            )
            
            return SyncStats(
                schedulesCount: counts.schedules,
                coursesCount: counts.courses,
                assignmentsCount: counts.assignments,
                eventsCount: counts.events,
                categoriesCount: counts.categories
            )
        } catch {
            print("🔒 Failed to get sync stats: \(error)")
            return nil
        }
    }
    
    private func getTableCount(_ table: String) async -> Int {
        do {
            let response = try await client
                .from(table)
                .select("id", head: true, count: .exact)
                .execute()
            
            return response.count ?? 0
        } catch {
            return 0
        }
    }
    
    private func ensureSubscriberRow() async {
        guard let user = currentUser else { return }
        do {
            let minimal = SubscriberEnsure(
                user_id: user.id.uuidString,
                email: user.email
            )
            
            _ = try await client
                .from("subscribers")
                .upsert(minimal, onConflict: "user_id")
                .execute()
            
            #if DEBUG
            print("✅ Ensured subscriber row (non-destructive) for user \(user.id)")
            #endif
        } catch {
            #if DEBUG
            print("❌ ensureSubscriberRow upsert failed: \(error)")
            #endif
        }
        
        await loadUserSubscription()
    }
    
    deinit {
        connectionMonitor?.invalidate()
    }
    
    
    
}

// MARK: - Supporting Types

// Database insert/update structs
private struct ProfileInsert: Codable {
    let user_id: String
    let display_name: String
    let avatar_url: String?
    let bio: String?
}

private struct SubscriberInsert: Codable {
    let user_id: String
    let email: String
    let subscribed: Bool
    let subscription_tier: String
    let role: String
}

private struct ProfileUpdate: Codable {
    let display_name: String?
    let bio: String?
    let updated_at: String
    
    init(displayName: String?, bio: String?) {
        self.display_name = displayName
        self.bio = bio
        self.updated_at = Date().iso8601String()
    }
}

private struct SubscriberEnsure: Codable {
    let user_id: String
    let email: String?
}