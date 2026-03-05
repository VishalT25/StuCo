import SwiftUI

struct CreateAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var purchaseManager: PurchaseManager
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var name: String = ""
    @State private var academicYear: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCreating = false
    @State private var errorMessage: String?

    // AI Import states
    @State private var showingAIImport = false
    @State private var aiImportData: AIAcademicCalendarImportData?
    @State private var showAIImportSection = false

    // Google Calendar sync states
    @State private var showingGoogleCalendarPrompt = false
    @State private var createdCalendar: AcademicCalendar?
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endDate > startDate
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }
    
    private var hasAIAccess: Bool {
        return purchaseManager.hasProAccess
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Spectacular animated background
                spectacularBackground
                
                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Hero header section
                            heroSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : -30)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                            
                            // Form content
                            formContent
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                            
                            // AI Import Section (appears below form fields with smooth fade)
                            if showAIImportSection {
                                aiImportInlineSection
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                    .animation(.easeInOut(duration: 0.5), value: showAIImportSection)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 140)
                    }
                }
                
                // Floating buttons (bottom corners)
                VStack {
                    Spacer()
                    
                    HStack {
                        // AI Import Button (bottom-left)
                        if hasAIAccess {
                            aiFloatingButton
                        }
                        
                        Spacer()
                        
                        // Create Calendar Button (bottom-right)
                        createFloatingButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
                }
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .navigationTitle("New Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create") {
                    Task { await createCalendar() }
                }
                .disabled(!isValid)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
                .font(.forma(.body))
        }
        .alert("Sync to Google Calendar?", isPresented: $showingGoogleCalendarPrompt) {
            Button("Sync") {
                syncToGoogleCalendar()
            }
            Button("Not Now", role: .cancel) {
                dismiss()
            }
        } message: {
            if let calendar = createdCalendar {
                Text("Would you like to sync '\(calendar.name)' breaks to your Google Calendar?")
            }
        }
        .onAppear {
            setupDefaults()
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .onChange(of: aiImportData) { _, newData in
            if let data = newData {
                // Apply AI imported data to form fields with smooth animation
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    name = data.calendarName
                    academicYear = data.academicYear
                    startDate = data.startDate
                    endDate = data.endDate
                }
            }
        }
    }
    
    // MARK: - AI Import Inline Section
    private var aiImportInlineSection: some View {
        VStack(spacing: 20) {
            // AI Import content with premium styling (removed redundant header)
            VStack(spacing: 0) {
                AIAcademicCalendarImportStep(
                    importData: $aiImportData,
                    calendarName: name.isEmpty ? "Academic Calendar" : name,
                    academicYear: academicYear.isEmpty ? "2024-2025" : academicYear,
                    startDate: startDate,
                    endDate: endDate
                )
                .environmentObject(themeManager)
                .environmentObject(supabaseService)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.purple.opacity(0.4),
                                    Color.pink.opacity(0.2),
                                    Color.orange.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: Color.purple.opacity(colorScheme == .dark ? 0.3 : 0.15),
                    radius: 25,
                    x: 0,
                    y: 12
                )
                .overlay(
                    // Subtle animated shimmer effect
                    RoundedRectangle(cornerRadius: 24)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(pulseAnimation * 0.3 + 0.1)
                        .animation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true), value: pulseAnimation)
                )
        )
        .opacity(showAIImportSection ? 1.0 : 0)
        .animation(.easeInOut(duration: 0.5), value: showAIImportSection)
    }
    
    // MARK: - AI Floating Button (Bottom-Left)
    private var aiFloatingButton: some View {
        Button(action: {
            // Haptic feedback for premium feel
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showAIImportSection.toggle()
            }
        }) {
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.purple.opacity(0.6),
                                Color.pink.opacity(0.4),
                                Color.orange.opacity(0.2),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: showAIImportSection ? 35 : 25
                        )
                    )
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulseAnimation * 0.05 + 0.95)
                    .opacity(showAIImportSection ? 0.8 : 0.4)
                
                // Main button circle
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Color.purple,
                                Color.pink,
                                Color.orange,
                                Color.purple.opacity(0.8),
                                Color.purple
                            ],
                            center: .center,
                            angle: .degrees(animationOffset * 0.3)
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 30
                                )
                            )
                    )
                    .shadow(
                        color: Color.purple.opacity(0.6),
                        radius: showAIImportSection ? 20 : 15,
                        x: 0,
                        y: showAIImportSection ? 8 : 6
                    )
                
                // Icon with rotation animation
                Image(systemName: showAIImportSection ? "xmark" : "sparkles")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .rotationEffect(.degrees(showAIImportSection ? 180 : 0))
                    .scaleEffect(showAIImportSection ? 0.9 : 1.0)
                
                // Floating sparkles (only when not active)
                if !showAIImportSection {
                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.forma(.caption2, weight: .light))
                            .foregroundColor(.white)
                            .opacity(0.7)
                            .position(
                                x: CGFloat([48, 8, 40, 16][index]),
                                y: CGFloat([8, 48, 16, 40][index])
                            )
                            .scaleEffect(pulseAnimation * 0.4 + 0.6)
                            .rotationEffect(.degrees(animationOffset * 0.2 + Double(index * 90)))
                            .animation(
                                .easeInOut(duration: 2.0 + Double(index) * 0.3)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.2),
                                value: pulseAnimation
                            )
                    }
                }
            }
            .frame(width: 70, height: 70)
            .scaleEffect(showAIImportSection ? 1.05 : 1.0)
        }
        .buttonStyle(PremiumCircleButtonStyle())
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showAIImportSection)
    }
    
    // MARK: - Create Calendar Floating Button (Bottom-Right)
    private var createFloatingButton: some View {
        Button(action: {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            Task { await createCalendar() }
        }) {
            HStack(spacing: 12) {
                if isCreating {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.white)
                } else {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "plus")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                }
                
                if !isCreating {
                    Text("Create Calendar")
                        .font(.forma(.title3, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, isCreating ? 24 : 28)
            .padding(.vertical, 18)
            .background(
                ZStack {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: !isValid ? 
                                    [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                    [currentTheme.primaryColor, currentTheme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // Animated shimmer when valid
                    if !isCreating && isValid {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: animationOffset * 0.5 - 50)
                            .mask(Capsule())
                    }
                }
                .shadow(
                    color: !isValid ? .clear : currentTheme.primaryColor.opacity(0.5),
                    radius: isValid ? 20 : 0,
                    x: 0,
                    y: isValid ? 10 : 0
                )
                .overlay(
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.2),
                                    Color.clear
                                ],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                )
            )
            .scaleEffect(isValid ? 1.0 : 0.95)
        }
        .disabled(!isValid || isCreating)
        .buttonStyle(PremiumMainButtonStyle())
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isValid)
        .animation(.spring(response: 0.3, dampingFraction: 0.9), value: isCreating)
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    showAIImportSection 
                    ? Color.purple.opacity(colorScheme == .dark ? 0.12 : 0.04)
                    : currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.12 : 0.04),
                    showAIImportSection 
                    ? Color.pink.opacity(colorScheme == .dark ? 0.08 : 0.02)
                    : currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.2), value: showAIImportSection)
            
            // Enhanced floating shapes with AI-specific colors
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                (showAIImportSection ? 
                                 [Color.purple, Color.pink, Color.orange][index % 3] : 
                                 currentTheme.primaryColor
                                ).opacity(0.08 - Double(index) * 0.01),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60 + CGFloat(index * 15)
                        )
                    )
                    .frame(
                        width: 100 + CGFloat(index * 25), 
                        height: 100 + CGFloat(index * 25)
                    )
                    .offset(
                        x: sin(animationOffset * 0.008 + Double(index) * 0.5) * 60,
                        y: cos(animationOffset * 0.006 + Double(index) * 0.3) * 40
                    )
                    .opacity(showAIImportSection ? 0.4 : 0.2)
                    .blur(radius: CGFloat(index * 2 + 1))
                    .animation(.easeInOut(duration: 1.2), value: showAIImportSection)
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .center, spacing: 8) {
                HStack(spacing: 8) {
                    if showAIImportSection {
                        VStack(spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.forma(.caption))
                                    .foregroundColor(.purple)
                                
                                Text("AI Import Active")
                                    .font(.forma(.caption, weight: .semibold))
                                    .foregroundColor(.purple)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(Color.purple.opacity(0.1))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Text("AI Academic Calendar Import")
                                .font(.forma(.title, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            Color.purple,
                                            Color.pink
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Create Academic Calendar")
                            .font(.forma(.title, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                    }
                }
                
                Text(showAIImportSection 
                     ? "Upload or describe your academic calendar to automatically extract breaks, dates, and important periods."
                     : "Set up semester dates and manage breaks to keep your schedules perfectly organized.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.5), value: showAIImportSection)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    (showAIImportSection ? Color.purple : currentTheme.primaryColor).opacity(0.3),
                                    (showAIImportSection ? Color.pink : currentTheme.primaryColor).opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .animation(.easeInOut(duration: 0.5), value: showAIImportSection)
                )
                .shadow(
                    color: (showAIImportSection ? Color.purple : currentTheme.primaryColor).opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
                .animation(.easeInOut(duration: 0.5), value: showAIImportSection)
        )
    }
    
    // MARK: - Form Content
    private var formContent: some View {
        VStack(spacing: 24) {
            // Basic Details Section
            VStack(spacing: 20) {
                Text("Calendar Details")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    AcademicCalendarStunningFormField(
                        title: "Calendar Name",
                        icon: "text.alignleft",
                        placeholder: "Fall 2024 Semester",
                        text: $name,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Please enter a calendar name",
                        isFocused: false
                    )
                    
                    AcademicCalendarStunningFormField(
                        title: "Academic Year",
                        icon: "calendar",
                        placeholder: "2024-2025",
                        text: $academicYear,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Please enter an academic year",
                        isFocused: false
                    )
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // Date Range Section
            VStack(spacing: 20) {
                Text("Academic Period")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    datePickerField(
                        title: "Start Date",
                        icon: "calendar.badge.plus",
                        selection: $startDate
                    )
                    
                    datePickerField(
                        title: "End Date",
                        icon: "calendar.badge.minus",
                        selection: $endDate,
                        range: startDate...
                    )
                }
                
                // Academic year info
                VStack(spacing: 8) {
                    Divider()
                        .overlay(currentTheme.primaryColor.opacity(0.3))
                    
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .font(.forma(.caption))
                            .foregroundColor(currentTheme.primaryColor)
                        
                        Text("The academic year \(academicYear) will span from \(formatDate(startDate)) to \(formatDate(endDate))")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
            
            // AI Import Data Preview (if available)
            if let aiData = aiImportData, !aiData.breaks.isEmpty {
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.purple)
                        
                        Text("AI Imported Breaks")
                            .font(.forma(.title2, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(aiData.breaks.prefix(3), id: \.id) { academicBreak in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(.purple)
                                    .frame(width: 8, height: 8)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(academicBreak.name)
                                        .font(.forma(.subheadline, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text(formatDateRange(academicBreak.startDate, academicBreak.endDate))
                                        .font(.forma(.caption))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        
                        if aiData.breaks.count > 3 {
                            Text("+ \(aiData.breaks.count - 3) more breaks")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            }
        }
    }
    
    private func datePickerField(
        title: String,
        icon: String,
        selection: Binding<Date>,
        range: PartialRangeFrom<Date>? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.subheadline))
                    .foregroundColor(currentTheme.primaryColor)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            HStack {
                if let range = range {
                    DatePicker("", selection: selection, in: range, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    DatePicker("", selection: selection, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
    
    private func setupDefaults() {
        let currentYear = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        
        // Smart academic year detection
        let academicStartYear = currentMonth >= 8 ? currentYear : currentYear - 1
        academicYear = "\(academicStartYear)-\(academicStartYear + 1)"
        
        // Default dates
        startDate = Calendar.current.date(from: DateComponents(year: academicStartYear, month: 8, day: 15)) ?? Date()
        endDate = Calendar.current.date(from: DateComponents(year: academicStartYear + 1, month: 6, day: 15)) ?? Date()
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    private func createCalendar() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCreating = true
        }

        errorMessage = nil

        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedYear = academicYear.trimmingCharacters(in: .whitespacesAndNewlines)

            var calendar = AcademicCalendar(
                name: trimmedName,
                academicYear: trimmedYear,
                termType: .semester,
                startDate: startDate,
                endDate: endDate
            )

            // Add AI imported breaks if available
            if let aiData = aiImportData {
                calendar.breaks = aiData.breaks
            }

            academicCalendarManager.addCalendar(calendar)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isCreating = false
            }

            // Check if Google Calendar is connected and show prompt
            if calendarSyncManager.googleCalendarManager.isSignedIn {
                createdCalendar = calendar
                showingGoogleCalendarPrompt = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "Failed to create calendar: \(error.localizedDescription)"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isCreating = false
            }
        }
    }

    private func syncToGoogleCalendar() {
        guard let calendar = createdCalendar else { return }

        Task {
            // TODO: Implement Google Calendar sync for academic calendar breaks
            print("📅 Would sync academic calendar '\(calendar.name)' breaks to Google Calendar")
            // For now, just dismiss after showing the prompt
            await MainActor.run {
                dismiss()
            }
        }
    }
}

// MARK: - StunningFormField (if not already defined elsewhere)
struct StunningFormField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    let courseColor: Color
    let themeManager: ThemeManager
    let isValid: Bool
    let errorMessage: String
    let isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.subheadline))
                    .foregroundColor(courseColor)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            TextField(placeholder, text: $text)
                .font(.forma(.body))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isValid ? courseColor.opacity(0.2) : Color.red.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                )
            
            if !isValid && !text.isEmpty {
                Text(errorMessage)
                    .font(.forma(.caption))
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Academic Calendar Specific StunningFormField
struct AcademicCalendarStunningFormField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    let courseColor: Color
    let themeManager: ThemeManager
    let isValid: Bool
    let errorMessage: String
    let isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.subheadline))
                    .foregroundColor(courseColor)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            TextField(placeholder, text: $text)
                .font(.forma(.body))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isValid ? courseColor.opacity(0.2) : Color.red.opacity(0.4),
                                    lineWidth: 1
                                )
                        )
                )
            
            if !isValid && !text.isEmpty {
                Text(errorMessage)
                    .font(.forma(.caption))
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
    }
}

// MARK: - Premium Button Styles
struct PremiumCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? -0.1 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct PremiumMainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isPressed)
    }
}

#Preview {
    CreateAcademicCalendarView()
        .environmentObject(ThemeManager())
        .environmentObject(AcademicCalendarManager())
        .environmentObject(SupabaseService.shared)
}