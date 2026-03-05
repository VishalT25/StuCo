import SwiftUI
import MessageUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var realtimeSyncManager: RealtimeSyncManager
    @EnvironmentObject var courseManager: UnifiedCourseManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject var guidedOnboardingManager: GuidedOnboardingManager

    @State private var showingThemeSelector = false
    @State private var showingAcademicCalendarManagement = false
    @State private var showingAuthSheet = false
    @State private var showingAccountManagement = false
    @State private var showingSubscriptionManagement = false
    @State private var showingPaywall = false
    @State private var showingGoogleCalendarSettings = false
    @State private var showTutorial = false
    @State private var result: Result<MFMailComposeResult, Error>? = nil
    @State private var isShowingMailView = false
    @State private var showingFeedbackAlert = false
    @State private var showingSyncStats = false
    @State private var syncStats: SyncStats?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sizeCategory) private var sizeCategory
    
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("categoryTitleFormat") private var categoryTitleFormat: CategoryTitleFormat = .courseCode
    @AppStorage("gradeDecimalPrecision") private var gradeDecimalPrecision: Int = 1

    private var exampleGradeFormat: String {
        switch gradeDecimalPrecision {
        case 0: return "86%"
        case 1: return "85.5%"
        case 2: return "85.47%"
        default: return "85.5%"
        }
    }

    private let showSyncSections = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                SpectacularBackground(themeManager: themeManager)
                
                VStack(spacing: 0) {
                    headerView
                        .padding(.bottom, 12)

                    List {
                        // Account
                        Section(header: Text("Account").font(.forma(.footnote, weight: .medium))) {
                            if supabaseService.isAuthenticated {
                                Button {
                                    showingAccountManagement = true
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(subscriptionGradient)
                                                .frame(width: avatarSize, height: avatarSize)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            HStack(spacing: 8) {
                                                Text(displayName)
                                                    .font(.forma(.body, weight: .semibold))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.85)
                                                
                                                // Subscription Badge
                                                Text(subscriptionDisplayName)
                                                    .font(.forma(.caption, weight: .bold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(subscriptionColor.opacity(0.2))
                                                    .foregroundColor(subscriptionColor)
                                                    .clipShape(Capsule())
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                            }
                                            
                                            Text(supabaseService.currentUser?.email ?? "")
                                                .font(.forma(.subheadline))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.7)
                                            
                                            if let subscription = supabaseService.userSubscription,
                                               subscription.isActive && subscription.subscriptionTier != .free {
                                                if let endDate = subscription.subscriptionEndDate {
                                                    Text("Active until \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                                        .font(.forma(.caption))
                                                        .foregroundColor(.secondary)
                                                } else {
                                                    Text("Lifetime Access")
                                                        .font(.forma(.caption))
                                                        .foregroundColor(subscriptionColor)
                                                }
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.forma(.footnote, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            } else {
                                Button {
                                    showingAuthSheet = true
                                } label: {
                                    HStack(spacing: 12) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                                .frame(width: rowIconSize, height: rowIconSize)
                                        }
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Connect Your Account")
                                                .font(.forma(.body, weight: .semibold))
                                            Text("Sync your data across devices")
                                                .font(.forma(.subheadline))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.85)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.forma(.footnote, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        if showSyncSections {
                            Section {
                                // Real-time Sync Status
                                HStack {
                                    Image(systemName: "cloud.bolt")
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                        .frame(width: smallIconSize, height: smallIconSize)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Real-time Sync")
                                            .font(.forma(.body))
                                        
                                        Text(realtimeSyncManager.syncStatus.displayName)
                                            .font(.forma(.caption))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    SyncStatusIndicator()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    // Tapping opens sync status details
                                }
                                
                                // Manual Sync Button
                                Button(action: {
                                    Task {
                                        await realtimeSyncManager.refreshAllData()
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                            .foregroundColor(themeManager.currentTheme.primaryColor)
                                            .frame(width: smallIconSize, height: smallIconSize)
                                    
                                        Text("Refresh All Data")
                                            .font(.forma(.body))
                                            .foregroundColor(.primary)
                                    
                                        Spacer()
                                    
                                        if realtimeSyncManager.syncStatus.isActive {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        }
                                    }
                                }
                                .disabled(realtimeSyncManager.syncStatus.isActive)
                                
                                if let lastSync = realtimeSyncManager.lastSyncTime {
                                    HStack {
                                        Image(systemName: "clock")
                                            .foregroundColor(themeManager.currentTheme.primaryColor)
                                            .frame(width: smallIconSize, height: smallIconSize)
                                    
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Last Sync")
                                                .font(.forma(.body))
                                            
                                            Text(lastSync.formatted(.relative(presentation: .numeric)))
                                                .font(.forma(.caption))
                                                .foregroundColor(.secondary)
                                        }
                                    
                                        Spacer()
                                    }
                                }
                            } header: {
                                Text("Sync & Data")
                            } footer: {
                                Text("Real-time synchronization keeps your data updated across all devices. Pending operations: \(realtimeSyncManager.pendingSyncCount)")
                            }
                        }
                        
                        if showSyncSections && supabaseService.isAuthenticated {
                            Section(header: Text("Data Sync").font(.forma(.footnote, weight: .medium))) {
                                // Sync Status
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(syncStatusColor.opacity(0.15))
                                            .frame(width: rowIconSize, height: rowIconSize)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Sync Status")
                                            .font(.forma(.body, weight: .semibold))
                                        Text(syncStatusText)
                                            .font(.forma(.subheadline))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if realtimeSyncManager.syncStatus.isActive {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                // Manual Sync Button
                                Button {
                                    Task {
                                        await realtimeSyncManager.refreshAllData()
                                    }
                                } label: {
                                    SettingsRow(
                                        icon: "arrow.triangle.2.circlepath",
                                        iconColor: .blue,
                                        title: "Sync Now",
                                        subtitle: "Update data from cloud"
                                    )
                                }
                                .disabled(realtimeSyncManager.syncStatus.isActive)
                                
                                // Sync Statistics
                                Button {
                                    showingSyncStats = true
                                    Task {
                                        syncStats = await supabaseService.getSyncStats()
                                    }
                                } label: {
                                    SettingsRow(
                                        icon: "chart.bar.fill",
                                        iconColor: .green,
                                        title: "Sync Statistics",
                                        subtitle: "View cloud data summary"
                                    )
                                }
                            }
                        }
                        
                        // Appearance
                        Section(header: Text("Appearance").font(.forma(.footnote, weight: .medium))) {
                            Button {
                                showingThemeSelector = true
                            } label: {
                                SettingsRow(
                                    icon: "paintbrush.pointed",
                                    iconColor: themeManager.currentTheme.primaryColor,
                                    title: "Theme & Appearance",
                                    subtitle: "\(themeManager.currentTheme.rawValue) • \(themeManager.appearanceMode.displayName)"
                                )
                            }
                        }
                        
                        // Academic Settings
                        Section(header: Text("Academic Settings").font(.forma(.footnote, weight: .medium))) {
                            // Show GPA on Home Screen Toggle
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.blue.opacity(0.15))
                                        .frame(width: rowIconSize, height: rowIconSize)
                                    Image(systemName: "graduationcap.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: rowIconSize * 0.5, weight: .semibold))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Show GPA on Home Screen")
                                        .foregroundColor(.primary)
                                        .font(.forma(.body, weight: .semibold))
                                    Text("Display current average on quick actions")
                                        .foregroundColor(.secondary)
                                        .font(.forma(.subheadline))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                                Toggle("", isOn: $showCurrentGPA)
                                    .labelsHidden()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showCurrentGPA.toggle()
                            }
                            
                            // Grade Display Format Toggle
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.purple.opacity(0.15))
                                        .frame(width: rowIconSize, height: rowIconSize)
                                    Image(systemName: "percent")
                                        .foregroundColor(.purple)
                                        .font(.system(size: rowIconSize * 0.5, weight: .semibold))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Grade Display Format")
                                        .foregroundColor(.primary)
                                        .font(.forma(.body, weight: .semibold))
                                    Text(usePercentageGrades ? "Show as percentage (85.5%)" : "Show as GPA scale (3.42)")
                                        .foregroundColor(.secondary)
                                        .font(.forma(.subheadline))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                                Toggle("", isOn: $usePercentageGrades)
                                    .labelsHidden()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                usePercentageGrades.toggle()
                            }

                            // Decimal Precision Setting
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.cyan.opacity(0.15))
                                        .frame(width: rowIconSize, height: rowIconSize)
                                    Image(systemName: "number.circle")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: rowIconSize * 0.5, weight: .semibold))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Grade Decimals")
                                        .foregroundColor(.primary)
                                        .font(.forma(.body, weight: .semibold))
                                    Text("Show \(gradeDecimalPrecision) decimal place\(gradeDecimalPrecision == 1 ? "" : "s") (e.g., \(exampleGradeFormat))")
                                        .foregroundColor(.secondary)
                                        .font(.forma(.subheadline))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                                Picker("", selection: $gradeDecimalPrecision) {
                                    Text("0").tag(0)
                                    Text("1").tag(1)
                                    Text("2").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 100)
                            }
                        }

                        // Categories
                        Section(header: Text("Categories").font(.forma(.footnote, weight: .medium))) {
                            // Course Code Option
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.orange.opacity(0.15))
                                        .frame(width: rowIconSize, height: rowIconSize)
                                    Image(systemName: "number")
                                        .foregroundColor(.orange)
                                        .font(.system(size: rowIconSize * 0.5, weight: .semibold))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Category Display Format")
                                        .foregroundColor(.primary)
                                        .font(.forma(.body, weight: .semibold))
                                    Text(categoryTitleFormat == .courseCode ? "Course Code (e.g., CS 101)" : "Course Name (e.g., Intro to CS)")
                                        .foregroundColor(.secondary)
                                        .font(.forma(.subheadline))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                Spacer()
                                Button {
                                    // Toggle between formats with smooth animation
                                    let newFormat: CategoryTitleFormat = categoryTitleFormat == .courseCode ? .courseName : .courseCode

                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.68)) {
                                        categoryTitleFormat = newFormat
                                    }

                                    // Provide haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()

                                    print("🔄 SettingsView: Category format changed to \(newFormat.rawValue)")

                                    // Update all category names immediately
                                    Task { @MainActor in
                                        await courseManager.updateAllCategoryNamesFromSetting()

                                        // Force UI refresh by posting notification
                                        NotificationCenter.default.post(name: NSNotification.Name("CategoryNamesUpdated"), object: nil)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(categoryTitleFormat == .courseCode ? "Code" : "Name")
                                            .font(.forma(.subheadline, weight: .medium))
                                            .foregroundColor(.white)
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(Color.orange.gradient)
                                    )
                                }
                            }
                            .contentShape(Rectangle())

                            // Academic Calendar Management
                            Button {
                                showingAcademicCalendarManagement = true
                            } label: {
                                SettingsRow(icon: "graduationcap.fill", iconColor: .purple, title: "Academic Calendars", subtitle: "School schedule management")
                            }
                        }

                        // Integrations
                        Section(header: Text("Integrations").font(.forma(.footnote, weight: .medium))) {
                            Button {
                                showingGoogleCalendarSettings = true
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.blue.opacity(0.15))
                                            .frame(width: rowIconSize, height: rowIconSize)
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundColor(.blue)
                                            .font(.system(size: rowIconSize * 0.5, weight: .semibold))
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 8) {
                                            Text("Google Calendar")
                                                .foregroundColor(.primary)
                                                .font(.forma(.body, weight: .semibold))

                                            if calendarSyncManager.googleCalendarManager.isSignedIn {
                                                Text("Connected")
                                                    .font(.forma(.caption, weight: .bold))
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 2)
                                                    .background(Color.green.opacity(0.2))
                                                    .foregroundColor(.green)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        Text(calendarSyncManager.googleCalendarManager.isSignedIn ? "Manage calendar sync" : "Connect to sync events")
                                            .foregroundColor(.secondary)
                                            .font(.forma(.subheadline))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.forma(.footnote, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }

                        // Support & Feedback
                        Section(header: Text("Support & Feedback").font(.forma(.footnote, weight: .medium))) {
                            Button {
                                if MFMailComposeViewController.canSendMail() {
                                    isShowingMailView = true
                                } else {
                                    showingFeedbackAlert = true
                                }
                            } label: {
                                SettingsRow(icon: "envelope.fill", iconColor: .green, title: "Send Feedback", subtitle: "Help us improve the app")
                            }
                            
                            Button {
                                guard let url = URL(string: "https://apps.apple.com/app/id123456789") else { return }
                                UIApplication.shared.open(url)
                            } label: {
                                SettingsRow(icon: "star.fill", iconColor: .yellow, title: "Rate on App Store", subtitle: "Share your experience")
                            }
                        }

                        // Tutorial
                        Section(header: Text("Help").font(.forma(.footnote, weight: .medium))) {
                            Button {
                                showTutorial = true
                            } label: {
                                SettingsRow(
                                    icon: "book.fill",
                                    iconColor: themeManager.currentTheme.primaryColor,
                                    title: "App Tour",
                                    subtitle: "Review app features"
                                )
                            }

                            Button {
                                // Reset and start guided onboarding
                                guidedOnboardingManager.resetOnboarding()
                                dismiss()
                                // Small delay to let the view dismiss first
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    guidedOnboardingManager.startOnboarding()
                                }
                            } label: {
                                SettingsRow(
                                    icon: "hand.point.up.left.fill",
                                    iconColor: .orange,
                                    title: "Restart Guided Tour",
                                    subtitle: "Walk through key features again"
                                )
                            }
                        }

                        // Legal
                        Section(header: Text("Legal").font(.forma(.footnote, weight: .medium))) {
                            Link(destination: URL(string: "https://stuco.app/terms")!) {
                                SettingsRow(
                                    icon: "doc.text.fill",
                                    iconColor: themeManager.currentTheme.primaryColor,
                                    title: "Terms of Service",
                                    subtitle: "View our terms"
                                )
                            }

                            Link(destination: URL(string: "https://stuco.app/privacy")!) {
                                SettingsRow(
                                    icon: "lock.fill",
                                    iconColor: themeManager.currentTheme.primaryColor,
                                    title: "Privacy Policy",
                                    subtitle: "View our privacy policy"
                                )
                            }
                        }

                        // About
                        Section(header: Text("About").font(.forma(.footnote, weight: .medium))) {
                            HStack {
                                Text("StuCo")
                                    .font(.forma(.body, weight: .semibold))
                                Spacer()
                                Text("Version 1.0.0")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.secondary)
                            }
                            Text("Your intelligent student companion for academic success.")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .onAppear {
            Task {
                await supabaseService.refreshUserData()
            }
        }
        .sheet(isPresented: $showingThemeSelector) {
            ThemeSelectorView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAcademicCalendarManagement) {
            AcademicCalendarManagementView()
                .environmentObject(calendarSyncManager)
        }
        .sheet(isPresented: $showingGoogleCalendarSettings) {
            GoogleCalendarSettingsView()
                .environmentObject(calendarSyncManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthenticationSheet()
                .environmentObject(supabaseService)
        }
        .sheet(isPresented: $showingAccountManagement) {
            AccountManagementView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingSyncStats) {
            SyncStatsView(syncStats: $syncStats)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $isShowingMailView) {
            MailView(result: $result)
        }
        .sheet(isPresented: $showTutorial) {
            OnboardingTutorialView(isPresented: $showTutorial)
                .environmentObject(themeManager)
        }
        .alert("Cannot Send Email", isPresented: $showingFeedbackAlert) {
            Button("OK") { }
        } message: {
            Text("Please configure Mail app on your device to send feedback.")
        }
        .dynamicTypeSize(.small ... .large)
        .environment(\.sizeCategory, .large)
    }
    
    private var headerView: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .frame(width: 32, height: 32)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text("Settings")
                .font(.forma(.title2, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer()
            
            Rectangle()
                .fill(Color.clear)
                .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 20)
    }
    
    private var syncStatusColor: Color {
        if realtimeSyncManager.syncStatus.isActive {
            return .orange
        } else if case .error(_) = realtimeSyncManager.syncStatus {
            return .red
        } else if supabaseService.isAuthenticated {
            return .green
        } else {
            return .gray
        }
    }
    
    private var syncStatusText: String {
        if realtimeSyncManager.syncStatus.isActive {
            return "Syncing..."
        } else if case let .error(error) = realtimeSyncManager.syncStatus {
            return "Sync failed: \(error.localizedDescription)"
        } else if let lastSync = realtimeSyncManager.lastSyncTime {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Last sync \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else if supabaseService.isAuthenticated {
            return "Ready to sync"
        } else {
            return "Sign in to sync"
        }
    }
    
    private var displayName: String {
        supabaseService.userProfile?.displayName ?? "User"
    }
    
    private var subscriptionColor: Color {
        // Prefer RevenueCat tier if available (source of truth)
        if purchaseManager.isProUser {
            return purchaseManager.subscriptionTier.color
        }
        // Fallback to Supabase tier
        return supabaseService.userSubscription?.subscriptionTier.color ?? .gray
    }

    private var subscriptionDisplayName: String {
        // Prefer RevenueCat tier if available
        if purchaseManager.isProUser {
            return purchaseManager.subscriptionTier.displayName
        }
        // Fallback to Supabase tier
        return supabaseService.userSubscription?.subscriptionTier.displayName ?? "Free"
    }

    private var subscriptionGradient: LinearGradient {
        let tier = purchaseManager.isProUser
            ? purchaseManager.subscriptionTier
            : (supabaseService.userSubscription?.subscriptionTier ?? .free)

        switch tier {
        case .free:
            return LinearGradient(colors: [.gray.opacity(0.7), .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .premium, .pro:
            return LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .leading, endPoint: .trailing)
        case .founder:
            return LinearGradient(colors: [.purple.opacity(0.8), .purple, .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var isAccessibilityLarge: Bool {
        false
    }
    
    private var headerButtonSize: CGFloat {
        32
    }
    
    private var rowIconSize: CGFloat {
        28
    }
    
    private var smallIconSize: CGFloat {
        22
    }
    
    private var avatarSize: CGFloat {
        40
    }
}

struct SyncStatusIndicator: View {
    @EnvironmentObject var realtimeSyncManager: RealtimeSyncManager
    
    var body: some View {
        HStack {
            if realtimeSyncManager.syncStatus.isActive {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
    }
}

// MARK: - Category Title Format Enum

enum CategoryTitleFormat: String, CaseIterable {
    case courseCode = "code"
    case courseName = "name"

    var displayName: String {
        switch self {
        case .courseCode: return "Course Code (e.g., CS 101)"
        case .courseName: return "Course Name (e.g., Intro to CS)"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
        .environmentObject(SupabaseService.shared)
        .environmentObject(RealtimeSyncManager.shared)
}
