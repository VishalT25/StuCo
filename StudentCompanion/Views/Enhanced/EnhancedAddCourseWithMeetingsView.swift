import SwiftUI
import Combine

struct EnhancedAddCourseWithMeetingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var scheduleManager: ScheduleManager
    @EnvironmentObject private var courseManager: UnifiedCourseManager
    @Environment(\.colorScheme) private var colorScheme
    
    let existingCourse: Course?
    
    // Course details
    @State private var courseName: String = ""
    @State private var courseCode: String = ""
    @State private var section: String = ""
    @State private var creditHours: Double = 3.0
    @State private var selectedIconName: String = "book.closed.fill"
    @State private var selectedEmoji: String? = nil
    @State private var selectedColor: Color = .blue
    
    // Meetings
    @State private var meetings: [CourseMeeting] = []
    @State private var showingAddMeeting = false
    @State private var editingMeeting: CourseMeeting?

    // Icon and Color Pickers
    @State private var showingExpandedIconPicker = false
    @State private var showingCustomColorPicker = false
    
    // UI State
    @State private var currentStep = 0
    @State private var isCreating = false
    @State private var errorMessage: String?
    @State private var progressOffset: CGFloat = 0
    @State private var stepAnimationOffset: CGFloat = 0
    @State private var showContent = false
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    
    private let steps = ["Details", "Meetings", "Review"]
    private let maxStep = 2
    
    private let sfSymbolNames: [String] = [
        "book.closed.fill", "studentdesk", "laptopcomputer", "function",
        "atom", "testtube.2", "flame.fill", "brain.head.profile",
        "paintbrush.fill", "music.mic", "sportscourt.fill", "globe.americas.fill",
        "hammer.fill", "briefcase.fill", "camera.fill"
    ]
    
    private let predefinedColors: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink
    ]
    
    @State private var selectedDays: Set<Int>
    @State private var location: String
    @State private var instructor: String
    
    @State private var selectedRotationDay: Int?
    @State private var rotationLabel: String
    
    @State private var animationOffsetForSheet: CGFloat = 0
    @State private var showContentForSheet = false
    
    private let days = Array(1...7)
    
    // MARK: - Schedule Type Detection
    private var isActiveScheduleRotating: Bool {
        guard let activeSchedule = scheduleManager.activeSchedule else { return false }
        return activeSchedule.scheduleType == .rotating
    }
    
    init(existingCourse: Course? = nil) {
        self.existingCourse = existingCourse
        
        _selectedDays = State(initialValue: Set([]))
        _location = State(initialValue: "")
        _instructor = State(initialValue: "")
        _selectedRotationDay = State(initialValue: nil)
        _rotationLabel = State(initialValue: "")
        
        if let course = existingCourse {
            _courseName = State(initialValue: course.name)
            _courseCode = State(initialValue: course.courseCode)
            _section = State(initialValue: course.section)
            _creditHours = State(initialValue: course.creditHours)
            _selectedIconName = State(initialValue: course.iconName)
            _selectedEmoji = State(initialValue: course.emoji)
            _selectedColor = State(initialValue: course.color)
            _meetings = State(initialValue: course.meetings)
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case 1: return !meetings.isEmpty
        case 2: return true
        default: return false
        }
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        NavigationView {
            ZStack {
                backgroundView
                
                ScrollView {
                    LazyVStack(spacing: 24) {
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)

                        progressSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)

                        contentArea
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
                .scrollDismissesKeyboard(.interactively)

                floatingActionButton
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingAddMeeting) {
            ModernAddMeetingSheet(
                courseName: courseName,
                courseColor: selectedColor,
                scheduleType: scheduleManager.activeSchedule?.scheduleType ?? .traditional,
                isRotatingSchedule: isActiveScheduleRotating,
                onSave: { meeting in
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        meetings.append(meeting)
                    }
                }
            )
        }
        .sheet(item: $editingMeeting) { meeting in
            ModernEditMeetingSheet(
                meeting: meeting,
                courseName: courseName,
                courseColor: selectedColor,
                isRotatingSchedule: isActiveScheduleRotating,
                onSave: { updatedMeeting in
                    if let index = meetings.firstIndex(where: { $0.id == updatedMeeting.id }) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            meetings[index] = updatedMeeting
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showingExpandedIconPicker) {
            ExpandedIconPicker(
                selectedIconName: $selectedIconName,
                selectedEmoji: $selectedEmoji,
                color: selectedColor
            )
            .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingCustomColorPicker) {
            CustomColorPicker(selectedColor: $selectedColor)
                .environmentObject(themeManager)
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
                .font(.forma(.body))
        }
        .onAppear {
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
    }

    // MARK: - Simplified Background
    private var backgroundView: some View {
        ZStack {
            LinearGradient(
                colors: [
                    selectedColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    selectedColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                selectedColor.opacity(0.05 - Double(index) * 0.01),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60 + CGFloat(index * 20)
                        )
                    )
                    .frame(width: 120 + CGFloat(index * 40), height: 120 + CGFloat(index * 40))
                    .offset(
                        x: sin(animationOffset * 0.005 + Double(index)) * 30,
                        y: cos(animationOffset * 0.004 + Double(index)) * 20
                    )
                    .opacity(0.2)
                    // PERF FIX: Removed blur effect
                    .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text(existingCourse != nil ? "Edit Course" : "Create Course")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                selectedColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Build your perfect academic schedule with detailed course information and meeting times.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    selectedColor.opacity(0.3),
                                    selectedColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: selectedColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    // PERF FIX: Reduced shadow
                    radius: 6,
                    x: 0,
                    y: 3
                )
        )
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        HStack {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.secondary.opacity(0.2),
                                Color.secondary.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 50, height: 50)
                
                Circle()
                    .trim(from: 0, to: CGFloat(currentStep + 1) / CGFloat(maxStep + 1))
                    .stroke(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.7), value: currentStep)
                
                Text("\(currentStep + 1)")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [selectedColor, selectedColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            
            Spacer()
            
            HStack(spacing: 32) {
                ForEach(0...maxStep, id: \.self) { step in
                    VStack(spacing: 6) {
                        Text(steps[step])
                            .font(.forma(.subheadline, weight: step <= currentStep ? .semibold : .medium))
                            .foregroundColor(step <= currentStep ? selectedColor : .secondary)
                            .scaleEffect(step == currentStep ? 1.05 : 1.0)
                            .fixedSize(horizontal: true, vertical: false)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(step <= currentStep ? selectedColor : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                            .scaleEffect(step == currentStep ? 1.3 : 1.0)
                            .overlay(
                                Circle()
                                    .stroke(
                                        step <= currentStep ? selectedColor.opacity(0.3) : Color.clear,
                                        lineWidth: step == currentStep ? 2 : 0
                                    )
                                    .scaleEffect(step == currentStep ? 2.0 : 1.0)
                                    .opacity(step == currentStep ? 0.6 : 0)
                            )
                    }
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: currentStep)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Content Area
    private var contentArea: some View {
        VStack(spacing: 0) {
            currentStepView
                .opacity(1.0 - stepAnimationOffset)
                .scaleEffect(1.0 - (stepAnimationOffset * 0.05))
                .animation(.easeInOut(duration: 0.3), value: stepAnimationOffset)
        }
        .clipped()
    }

    @ViewBuilder
    private var currentStepView: some View {
        switch currentStep {
        case 0: courseDetailsStep
        case 1: meetingsStep
        case 2: reviewStep
        default: courseDetailsStep
        }
    }

    // MARK: - Course Details Step
    private var courseDetailsStep: some View {
        VStack(spacing: 24) {
            Text("Course Details")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                coursePreviewSection
                
                courseNameSection
                courseCodeSection
                creditHoursSection
                iconSelectionSection
                colorSelectionSection
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var coursePreviewSection: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [selectedColor.opacity(0.8), selectedColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(selectedColor.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(
                        color: selectedColor.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
                
                Image(systemName: selectedIconName)
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(1.1)
            }
            .scaleEffect(courseName.isEmpty ? 0.8 : 1.0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: courseName)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedColor)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedIconName)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(courseName.isEmpty ? "Course Name" : courseName)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(courseName.isEmpty ? .secondary : .primary)
                
                Text(courseCode.isEmpty ? "Course Code" : courseCode)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(String(format: creditHours.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", creditHours)) credits")
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var courseNameSection: some View {
        TextField("Course Name", text: $courseName)
            .font(.forma(.body, weight: .medium))
            .foregroundColor(.primary)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(courseName.isEmpty ? Color.secondary.opacity(0.3) : selectedColor.opacity(0.6),
                                    lineWidth: courseName.isEmpty ? 1 : 2
                            )
                    )
            )
    }

    private var courseCodeSection: some View {
        HStack(spacing: 16) {
            TextField("Course Code", text: $courseCode)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
            
            TextField("Section", text: $section)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(.primary)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }

    private var creditHoursSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap")
                    .font(.forma(.subheadline))
                    .foregroundColor(selectedColor)
                
                Text("Credit Hours")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            ModernCreditStepper(
                value: $creditHours,
                range: 0.5...6.0,
                step: 0.5,
                courseColor: selectedColor
            )
        }
    }

    private var iconSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.forma(.subheadline))
                    .foregroundColor(selectedColor)
                    .frame(width: 20)

                Text("Course Icon")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 8), spacing: 16) {
                ForEach(sfSymbolNames, id: \.self) { symbolName in
                    ModernIconButton(
                        symbolName: symbolName,
                        isSelected: selectedIconName == symbolName && selectedEmoji == nil,
                        color: selectedColor
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedIconName = symbolName
                            selectedEmoji = nil
                        }
                    }
                }

                // More Icons button
                Button {
                    showingExpandedIconPicker = true
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.forma(.callout))
                            .foregroundColor(selectedColor)

                        Text("More")
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(selectedColor)
                    }
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedColor.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selectedColor.opacity(0.4), lineWidth: 1.5)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                            .foregroundColor(selectedColor.opacity(0.3))
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var colorSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "paintpalette")
                    .font(.forma(.subheadline))
                    .foregroundColor(selectedColor)

                Text("Course Color")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(predefinedColors, id: \.self) { color in
                    ModernColorButton(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
                    }
                }

                // Custom Color button
                Button {
                    showingCustomColorPicker = true
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "eyedropper.halffull")
                            .font(.forma(.caption))
                            .foregroundColor(currentTheme.primaryColor)

                        Text("Custom")
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(currentTheme.primaryColor)
                    }
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(currentTheme.primaryColor.opacity(0.1))
                            .overlay(
                                Circle()
                                    .stroke(currentTheme.primaryColor.opacity(0.4), lineWidth: 1.5)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                                            .foregroundColor(currentTheme.primaryColor.opacity(0.3))
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Meetings Step
    private var meetingsStep: some View {
        VStack(spacing: 24) {
            Text("Course Meetings")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                Button(action: { showingAddMeeting = true }) {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(selectedColor.opacity(0.2))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor.opacity(0.3), lineWidth: 1)
                                )
                            
                            Image(systemName: "plus")
                                .font(.forma(.title3, weight: .bold))
                                .foregroundColor(selectedColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add Meeting Time")
                                .font(.forma(.headline, weight: .semibold))
                            Text("Lecture, Lab, Tutorial, etc.")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedColor.opacity(0.3), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)
                
                if !meetings.isEmpty {
                    LazyVStack(spacing: 16) {
                        ForEach(meetings) { meeting in
                            ModernMeetingRow(
                                meeting: meeting,
                                courseColor: selectedColor,
                                onEdit: { editingMeeting = meeting },
                                onDelete: { 
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        meetings.removeAll { $0.id == meeting.id }
                                    }
                                }
                            )
                        }
                    }
                } else {
                    emptyMeetingsState
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var emptyMeetingsState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "calendar.badge.plus")
                    .font(.forma(.largeTitle))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("No meetings yet")
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("Add at least one meeting time to continue.\nThis helps organize your schedule perfectly.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Review Step
    private var reviewStep: some View {
        VStack(spacing: 24) {
            Text("Review & Create")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                ModernCoursePreviewCard(
                    courseName: courseName,
                    courseCode: courseCode,
                    section: section,
                    creditHours: creditHours,
                    iconName: selectedIconName,
                    emoji: selectedEmoji,
                    color: selectedColor,
                    meetings: meetings
                )
                
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.forma(.title3))
                            .foregroundColor(selectedColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ready to add to your schedule")
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("This course will be added to your active schedule and synced across all your devices.")
                                .font(.forma(.body))
                                .foregroundColor(.secondary)
                        }

                        
                        Spacer()
                    }
                    
                    Divider()
                        .overlay(selectedColor.opacity(0.3))
                    
                    Text("You can edit course details, add more meetings, or adjust schedules anytime from the course details page.")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                if currentStep > 0 {
                    Button(action: previousStep) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left")
                                .font(.title3.bold())
                                .foregroundColor(.secondary)
                            Text("Back")
                                .font(.forma(.subheadline, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                // PERF FIX: Solid color instead of material
                .fill(Color(.systemBackground).opacity(0.95))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(
                                    color: .black.opacity(0.1),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if currentStep == maxStep {
                        Task { await createCourse() }
                    } else {
                        if canProceed {
                            nextStep()
                        }
                    }
                }) {
                    HStack(spacing: 12) {
                        if isCreating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else if currentStep == maxStep {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: canProceed ? "arrow.right" : "exclamationmark.triangle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isCreating {
                            Text(currentStep == maxStep 
                                 ? (existingCourse != nil ? "Save Course" : "Create Course")
                                 : (canProceed ? "Next" : "Complete Required Fields"))
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: (currentStep != maxStep && !canProceed) ? [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                               [selectedColor, selectedColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isCreating && (currentStep == maxStep || canProceed) {
                                Capsule()
                                    .fill(
                                        AngularGradient(
                                            colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear,
                                                Color.clear
                                            ],
                                            center: .center,
                                            angle: .degrees(animationOffset * 0.5)
                                        )
                                    )
                            }
                        }
                        .shadow(
                            color: (currentStep != maxStep && !canProceed) ? .clear : selectedColor.opacity(0.4),
                            radius: 6, // PERF FIX: Reduced
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: canProceed)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentStep)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helper Methods
    private func calculateTotalWeeklyHours(for meetings: [CourseMeeting]) -> Double {
        let totalHours = meetings.reduce(0) { total, meeting in
            let duration = meeting.endTime.timeIntervalSince(meeting.startTime) / 3600.0 // Convert to hours
            
            // For rotating schedules, assume they occur once per week
            // For regular schedules, multiply by days per week
            let weeklyOccurrences: Double
            if meeting.isRotating {
                weeklyOccurrences = 0.5 // Rotating meetings typically occur every other day on average
            } else if meeting.daysOfWeek.isEmpty {
                weeklyOccurrences = 1.0 // Default to once per week if no days specified
            } else {
                weeklyOccurrences = Double(meeting.daysOfWeek.count)
            }
            
            let weeklyHours = duration * weeklyOccurrences
            print("Meeting: \(meeting.displayName), Duration: \(duration)h, Days: \(meeting.daysOfWeek.count), Weekly: \(weeklyHours)h")
            
            return total + weeklyHours
        }
        
        print("Total weekly hours calculated: \(totalHours)")
        return totalHours
    }

    private func calculateUniqueDays(for meetings: [CourseMeeting]) -> Int {
        // For rotating schedules, we can't easily count days, so just return the number of meetings
        let rotatingMeetings = meetings.filter { $0.isRotating }
        let regularMeetings = meetings.filter { !$0.isRotating }
        
        let regularDays = Set(regularMeetings.flatMap { $0.daysOfWeek }).count
        let rotatingCount = rotatingMeetings.count > 0 ? 2 : 0 // Assume rotating schedules span 2 days
        
        let totalDays = regularDays + rotatingCount
        print("Regular days: \(regularDays), Rotating days: \(rotatingCount), Total: \(totalDays)")
        
        return max(totalDays, 0)
    }
    
    // MARK: - Navigation Functions
    // Removed continuous animations for performance - they were causing text input lag
    private func startAnimations() {
        // No continuous animations - keeps text input smooth
    }

    private func nextStep() {
        withAnimation(.easeOut(duration: 0.3)) {
            stepAnimationOffset = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep += 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeIn(duration: 0.3)) {
                stepAnimationOffset = 0
            }
        }
    }

    private func previousStep() {
        withAnimation(.easeOut(duration: 0.3)) {
            stepAnimationOffset = 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentStep -= 1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeIn(duration: 0.3)) {
                stepAnimationOffset = 0
            }
        }
    }

    // MARK: - Create Course Action
    private func createCourse() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCreating = true
        }
        
        errorMessage = nil
        
        if let existingCourse = existingCourse {
            await updateExistingCourse(existingCourse)
        } else {
            await createNewCourse()
        }
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCreating = false
        }
        
        dismiss()
    }

    private func updateExistingCourse(_ course: Course) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            errorMessage = "No user ID available"
            return
        }

        // CRITICAL: Prepare all meetings with proper IDs before any database operations
        let updatedMeetings = meetings.map { meeting in
            var updatedMeeting = meeting
            updatedMeeting.courseId = course.id
            updatedMeeting.scheduleId = course.scheduleId
            if updatedMeeting.userId == nil, let userUUID = SupabaseService.shared.currentUser?.id {
                updatedMeeting.userId = userUUID
            }
            return updatedMeeting
        }

        let meetingRepo = CourseMeetingRepository()

        // STEP 1: Sync meetings to database FIRST (before updating local state)
        // This ensures database has the latest meeting data before any refresh can occur
        print("📤 Syncing \(updatedMeetings.count) meetings to database...")

        // Get existing meeting IDs from the original course to detect deletions
        let originalMeetingIds = Set(course.meetings.map { $0.id })
        let currentMeetingIds = Set(updatedMeetings.map { $0.id })
        let deletedMeetingIds = originalMeetingIds.subtracting(currentMeetingIds)

        // Delete removed meetings from database
        for deletedId in deletedMeetingIds {
            do {
                try await meetingRepo.delete(id: deletedId.uuidString)
                print("🗑️ Deleted meeting '\(deletedId)' from database")
            } catch {
                print("⚠️ Failed to delete meeting '\(deletedId)': \(error)")
            }
        }

        // Update or create each meeting in the database
        for meeting in updatedMeetings {
            do {
                // Try to update first
                _ = try await meetingRepo.update(meeting, userId: userId)
                print("✅ Updated meeting '\(meeting.displayName)' in database")
            } catch {
                // If update fails, try to create it (might be a new meeting)
                print("⚠️ Update failed for '\(meeting.displayName)', trying create...")
                do {
                    _ = try await meetingRepo.create(meeting, userId: userId)
                    print("✅ Created meeting '\(meeting.displayName)' in database")
                } catch {
                    print("❌ Failed to sync meeting '\(meeting.displayName)': \(error)")
                    // Continue with other meetings even if one fails
                }
            }
        }

        // STEP 2: Now update the course with the synced meetings
        let updatedCourse = Course(
            id: course.id,
            scheduleId: course.scheduleId,
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            emoji: selectedEmoji,
            colorHex: selectedColor.toHex() ?? "007AFF",
            assignments: course.assignments,
            finalGradeGoal: course.finalGradeGoal,
            weightOfRemainingTasks: course.weightOfRemainingTasks,
            creditHours: creditHours,
            courseCode: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: course.instructor,
            location: course.location,
            meetings: updatedMeetings
        )

        do {
            // Update the course metadata (this also saves locally)
            try await courseManager.updateCourse(updatedCourse)
            print("✅ Course and meetings updated successfully")
        } catch {
            errorMessage = "Failed to update course: \(error.localizedDescription)"
        }
    }

    private func createNewCourse() async {
        guard let activeScheduleId = scheduleManager.activeScheduleID else {
            errorMessage = "No active schedule found. Please create a schedule first."
            return
        }
        
        let course = Course(
            scheduleId: activeScheduleId,
            name: courseName.trimmingCharacters(in: .whitespacesAndNewlines),
            iconName: selectedIconName,
            emoji: selectedEmoji,
            colorHex: selectedColor.toHex() ?? "007AFF",
            creditHours: creditHours,
            courseCode: courseCode.trimmingCharacters(in: .whitespacesAndNewlines),
            section: section.trimmingCharacters(in: .whitespacesAndNewlines),
            instructor: "",
            location: ""
        )
        
        let meetingsWithIds = meetings.map { meeting in
            var updatedMeeting = meeting
            updatedMeeting.courseId = course.id
            updatedMeeting.scheduleId = activeScheduleId
            return updatedMeeting
        }
        
        do {
            try await courseManager.createCourseWithMeetings(course, meetings: meetingsWithIds)
        } catch {
            errorMessage = "Failed to create course: \(error.localizedDescription)"
        }
    }
}

struct EnhancedAddCourseWithMeetingsView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedAddCourseWithMeetingsView()
            .environmentObject(ThemeManager())
            .environmentObject(ScheduleManager())
            .environmentObject(UnifiedCourseManager())
    }
}
