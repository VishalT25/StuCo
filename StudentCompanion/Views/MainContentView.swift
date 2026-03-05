import SwiftUI

enum AppRoute: Hashable {
    case schedule
    case events
    case gpa
    case settings
    case resources
    case islandSmasherGame
}

struct MainContentView: View {
    @EnvironmentObject private var viewModel: EventViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var supabaseService: SupabaseService
    @EnvironmentObject private var realtimeSyncManager: RealtimeSyncManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @StateObject private var calendarSyncManager = CalendarSyncManager.shared
    @EnvironmentObject private var scheduleManager: ScheduleManager

    @State private var showMenu = false
    @State private var selectedRoute: AppRoute?
    @State private var path = NavigationPath()
    @State private var showOnboarding = false
    @AppStorage("d2lLink") private var d2lLink: String = "https://d2l.youruniversity.edu"
    @AppStorage("showCurrentGPA") private var showCurrentGPA: Bool = true
    @AppStorage("usePercentageGrades") private var usePercentageGrades: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @Environment(\.scenePhase) var scenePhase
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("lastGradeUpdate") private var lastGradeUpdate: Double = 0
    @State private var displayGrade: String = "View"

    // Debounce task for grade updates to prevent multiple simultaneous calculations
    @State private var gradeUpdateTask: Task<Void, Never>?

    var body: some View {
        mainNavigationView
            .background(
                // Better background separation in dark mode
                Group {
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.05, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refreshLiveData()
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .toolbar {
                toolbarContent
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .onChange(of: selectedRoute) { newRoute in
                handleRouteChange(newRoute)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleSceneChange(newPhase)
            }
            .onAppear {
                print("🎓 ONBOARDING DEBUG: MainContentView.onAppear called")
                print("🎓 ONBOARDING DEBUG: hasCompletedOnboarding = \(hasCompletedOnboarding)")
                print("🎓 ONBOARDING DEBUG: isNewlyCreatedAccount = \(supabaseService.isNewlyCreatedAccount)")

                setupServices()
                configureNavigationBarAppearance()
                updateDisplayGrade()

                // Check if tutorial should be shown on first launch or for newly created account
                if !hasCompletedOnboarding || supabaseService.isNewlyCreatedAccount {
                    print("🎓 ONBOARDING DEBUG: Condition met to show tutorial")
                    // Delay slightly to let main view load
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🎓 ONBOARDING DEBUG: Setting showOnboarding = true")
                        showOnboarding = true
                        // Reset the flag so tutorial doesn't show again
                        supabaseService.isNewlyCreatedAccount = false
                    }
                } else {
                    print("🎓 ONBOARDING DEBUG: Condition NOT met - tutorial will not show")
                }
            }
            .onChange(of: lastGradeUpdate) { _, _ in debouncedUpdateDisplayGrade() }
            .onChange(of: showCurrentGPA) { _, _ in debouncedUpdateDisplayGrade() }
            .onChange(of: usePercentageGrades) { _, _ in debouncedUpdateDisplayGrade() }
            .onChange(of: supabaseService.isNewlyCreatedAccount) { oldValue, newValue in
                print("🎓 ONBOARDING DEBUG: onChange fired! oldValue=\(oldValue), newValue=\(newValue)")
                print("🎓 ONBOARDING DEBUG: hasCompletedOnboarding = \(hasCompletedOnboarding)")

                // Show tutorial when a new account is created
                if newValue && !hasCompletedOnboarding {
                    print("🎓 ONBOARDING DEBUG: Condition met in onChange - will show tutorial")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        print("🎓 ONBOARDING DEBUG: Setting showOnboarding = true from onChange")
                        showOnboarding = true
                        // Reset the flag so tutorial doesn't show again
                        supabaseService.isNewlyCreatedAccount = false
                    }
                } else {
                    print("🎓 ONBOARDING DEBUG: Condition NOT met in onChange (newValue=\(newValue), hasCompleted=\(hasCompletedOnboarding))")
                }
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingTutorialView(isPresented: $showOnboarding)
                    .environmentObject(themeManager)
                    .onAppear {
                        print("🎓 ONBOARDING DEBUG: ✅ OnboardingTutorialView appeared!")
                    }
                    .onDisappear {
                        print("🎓 ONBOARDING DEBUG: OnboardingTutorialView dismissed")
                        hasCompletedOnboarding = true
                        // Ensure flag is cleared when tutorial is dismissed
                        supabaseService.isNewlyCreatedAccount = false
                    }
            }
    }
    
    private var mainNavigationView: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(spacing: 0) { // Changed to 0 to control spacing manually
                    // Add visible spacing at the top
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 60) // Explicit spacer
                    
                    // Make header section more visible
                    homeHeaderSection
                    
                    // Add spacing before schedule
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 30)
                    
                    schedulePreview
                    
                    // Spacing between sections
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 24)
                    
                    eventsPreview
                    
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 24)
                    
                    quickActionsView
                    
                    // Bottom spacing
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 40)
                }
                .padding(.horizontal, 20)
            }
            .background(
                // Better background separation in dark mode
                Group {
                    if UITraitCollection.current.userInterfaceStyle == .dark {
                        LinearGradient(
                            colors: [
                                Color.black,
                                Color(red: 0.05, green: 0.05, blue: 0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        Color.white
                    }
                }
            )
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await viewModel.refreshLiveData()
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .toolbar {
                toolbarContent
            }
        }
    }
    
    private var enhancedDateDisplay: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Today")
                .font(.forma(.footnote)) // Increased by ~10%
                .foregroundColor(.white.opacity(0.8))
                .shadow(color: .black.opacity(0.3), radius: 1)
            Text(Date(), style: .date)
                .font(.forma(.subheadline, weight: .semibold)) // Increased by ~10%
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.4), radius: 2)
        }
    }

    // Removed continuous animations for performance - they were causing frame drops and freezing

    private var homeHeaderSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dashboard")
                        .font(.forma(.title2, weight: .bold))
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
                    
                    Text("Welcome back")
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.bottom, 8)
        .background(Color.red.opacity(0.1)) // Temporary background to see if it's visible
    }
    
    private var schedulePreview: some View {
        TodayScheduleView(onNavigateToSchedule: {
            selectedRoute = .schedule
        })
            .environmentObject(viewModel)
            .environmentObject(themeManager)
    }
    
    private var eventsPreview: some View {
        NavigationLink(value: AppRoute.events) {
            EventsListView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
        }
        .buttonStyle(.plain)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showMenu.toggle()
                    showMenu = true
                }
            } label: {
                Image(systemName: "line.horizontal.3")
                    .font(.forma(.title3))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 12) {
                if viewModel.isRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                }

                dateDisplay
            }
        }
    }
    
    private var dateDisplay: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("Today")
                .font(.forma(.caption2))
                .foregroundColor(.secondary)
            Text(Date(), style: .date)
                .font(.forma(.caption, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private var menuOverlay: some View {
        if showMenu {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showMenu = false
                        }
                    }
                
                HStack {
                    MenuContentView(isShowing: $showMenu, selectedRoute: $selectedRoute)
                        .environmentObject(themeManager)
                        .transition(.move(edge: .leading))
                    
                    Spacer()
                }
            }
            .zIndex(100)
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func configureNavigationBarAppearance() {
        // Configure navigation bar to be hidden since we're using custom spectacular nav
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
    
    private func handleRouteChange(_ newRoute: AppRoute?) {
        if let route = newRoute {
            path.removeLast(path.count)
            path.append(route)
            selectedRoute = nil
        }
    }
    
    private func handleSceneChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            Task { @MainActor in
                // Handle live activities when app becomes active
                 ("🔄 MainContentView: App became active")
            }
        }
    }
    
    private func setupServices() {
        // Setup services when view appears
         ("🔄 MainContentView: Setting up services")
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .schedule:
            ScheduleView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .environmentObject(scheduleManager) // Pass shared ScheduleManager
                .background(Color.white)
        case .events:
            EventsListView()
                .environmentObject(viewModel)
                .environmentObject(themeManager)
                .background(Color.white)
        case .gpa:
            GPAView()
                .environmentObject(themeManager)
                .environmentObject(scheduleManager) // Pass shared ScheduleManager
                .background(Color.white)
        case .settings:
            SettingsView()
                .environmentObject(themeManager)
                .environmentObject(calendarSyncManager)
                .environmentObject(supabaseService)
                .environmentObject(realtimeSyncManager)
                .environmentObject(courseManager)
                .environmentObject(purchaseManager)
                .background(Color.white)
                .navigationBarBackButtonHidden(false)
        case .resources:
            ResourcesView()
                .environmentObject(themeManager)
                .background(Color.white)
        case .islandSmasherGame:
            IslandSmasherGameView()
                .background(Color.white)
        }
    }
    
    private var quickActionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.forma(.title3, weight: .bold))
                .foregroundColor(.primary)
            
            HStack(spacing: 16) {
                NavigationLink(value: AppRoute.gpa) {
                    QuickActionCard(
                        title: "Courses",
                        subtitle: displayGrade,
                        icon: "graduationcap.fill",
                        color: themeManager.currentTheme.secondaryColor
                    )
                }
                
                Button(action: { openCustomD2LLink() }) {
                    QuickActionCard(
                        title: "D2L",
                        subtitle: "Portal",
                        icon: "link",
                        color: themeManager.currentTheme.tertiaryColor
                    )
                }
                
                NavigationLink(value: AppRoute.resources) {
                    QuickActionCard(
                        title: "Resources",
                        subtitle: "Library",
                        icon: "book.fill",
                        color: themeManager.currentTheme.quaternaryColor
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .adaptiveCardDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 16)
    }
    
    // Debounced grade update to prevent multiple simultaneous calculations (performance optimization)
    private func debouncedUpdateDisplayGrade() {
        // Cancel any pending grade update task
        gradeUpdateTask?.cancel()

        // Schedule a new update after 150ms delay
        gradeUpdateTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce

            // Check if task was cancelled
            guard !Task.isCancelled else { return }

            // Perform the update
            await MainActor.run {
                updateDisplayGrade()
            }
        }
    }

    private func updateDisplayGrade() {
        guard showCurrentGPA else {
            displayGrade = "View"
            return
        }
        Task.detached(priority: .utility) {
            let defaults = UserDefaults.standard
            guard let savedCoursesData = defaults.data(forKey: "gpaCourses"),
                  let courses = try? JSONDecoder().decode([Course].self, from: savedCoursesData),
                  !courses.isEmpty else {
                await MainActor.run { displayGrade = "No Data" }
                return
            }
            
            var totalGrade = 0.0
            var courseCount = 0
            
            for course in courses {
                var totalWeightedGrade = 0.0
                var totalWeight = 0.0
                
                for assignment in course.assignments {
                    if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                        totalWeightedGrade += grade * weight
                        totalWeight += weight
                    }
                }
                
                if totalWeight > 0 {
                    let courseGrade = totalWeightedGrade / totalWeight
                    totalGrade += courseGrade
                    courseCount += 1
                }
            }
            
            guard courseCount > 0 else {
                await MainActor.run { displayGrade = "No Grades" }
                return
            }
            
            let averageGrade = totalGrade / Double(courseCount)
            let result: String
            if usePercentageGrades {
                result = String(format: "%.1f%%", averageGrade)
            } else {
                let gpa = (averageGrade / 100.0) * 4.0
                result = String(format: "%.2f", gpa)
            }
            await MainActor.run { displayGrade = result }
        }
    }
    
    private func openCustomD2LLink() {
        guard let url = URL(string: d2lLink) else {
             ("Invalid D2L URL: \(d2lLink)")
            return
        }
        UIApplication.shared.open(url)
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var textColor: Color = .primary
    
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.sizeCategory) private var sizeCategory
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.forma(.title2))
                .foregroundColor(adaptiveIconColor)
                .minimumScaleFactor(0.8)
            
            VStack(spacing: 2) {
                Text(title)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(adaptiveTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(adaptiveTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: sizeCategory.isAccessibilityCategory ? 80 : 90)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    color.opacity(colorScheme == .dark ? 0.6 : 0.8), 
                    color.opacity(colorScheme == .dark ? 0.8 : 1.0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(12)
        .adaptiveWidgetDarkModeHue(using: themeManager.currentTheme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
    
    private var adaptiveTextColor: Color {
        if colorScheme == .dark {
            return .white
        } else {
            // For light mode, check if the background color is light or dark
            return isDarkColor(color) ? .white : .black
        }
    }
    
    private var adaptiveIconColor: Color {
        if colorScheme == .dark {
            return themeManager.currentTheme.darkModeAccentHue
        } else {
            return isDarkColor(color) ? .white : color.opacity(0.7)
        }
    }
    
    private func isDarkColor(_ color: Color) -> Bool {
        // Convert SwiftUI Color to UIColor to get RGB values
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Calculate luminance using standard formula
        let luminance = 0.299 * red + 0.587 * green + 0.114 * blue
        return luminance < 0.5
    }
}