import SwiftUI

struct AddEventView: View {
    @Binding var isPresented: Bool
    let preselectedDate: Date? // NEW: Optional preselected date
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var categoryId: UUID?
    @State private var reminderTime: ReminderTime = .none
    @State private var syncToApple = false
    @State private var syncToGoogle = false
    @State private var showValidationErrors = false
    @State private var isLoading = false
    @State private var saveSuccess = false
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    // Focus states
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case title
    }
    
    // NEW: Initialize with default date parameter
    init(isPresented: Binding<Bool>, preselectedDate: Date? = nil) {
        self._isPresented = isPresented
        self.preselectedDate = preselectedDate
    }
    
    // Validation computed properties
    private var isTitleValid: Bool { !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var hasValidCategory: Bool { categoryId != nil || viewModel.categories.first != nil }
    private var isFormValid: Bool { isTitleValid && hasValidCategory }
    
    private var currentCategory: Category? {
        if let categoryId = categoryId {
            return viewModel.categories.first { $0.id == categoryId }
        }
        return viewModel.categories.first
    }
    
    private var primaryColor: Color {
        currentCategory?.color ?? themeManager.currentTheme.primaryColor
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Stunning animated background
                spectacularBackground
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 21) {
                        // Hero header section
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        // Reminder details form
                        reminderFormSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                        
                        // Category selection section
                        categorySection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                        
                        // Settings section
                        settingsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: showContent)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                }
                
                // Floating action button
                floatingActionButton
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .onAppear {
            startAnimations()
            setupInitialCategory()
            // NEW: Set preselected date if provided
            if let preselectedDate = preselectedDate {
                date = preselectedDate
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
                focusedField = .title
            }
        }
        .onChange(of: saveSuccess) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.375, dampingFraction: 0.8)) {
                    bounceAnimation = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.125) {
                    isPresented = false
                }
            }
        }
        .navigationTitle("New Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { 
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveReminder()
                    isPresented = false
                }
                .disabled(!isFormValid || isLoading)
                .foregroundColor(!isFormValid || isLoading ? .gray : .blue)
            }
        }
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    primaryColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                primaryColor.opacity(0.1 - Double(index) * 0.015),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40 + CGFloat(index * 10)
                        )
                    )
                    .frame(width: 80 + CGFloat(index * 20), height: 80 + CGFloat(index * 20))
                    .offset(
                        x: sin(animationOffset * 0.01 + Double(index)) * 50,
                        y: cos(animationOffset * 0.008 + Double(index)) * 30
                    )
                    .opacity(0.3)
                    // PERF FIX: Removed blur
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 9) {
                Text("New Reminder")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Never miss an important task or deadline")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    primaryColor.opacity(0.3),
                                    primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: primaryColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 6, // PERF FIX
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Reminder Form Section
    private var reminderFormSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Reminder Details")
                .font(.forma(.title2, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 20) {
                // Title Field
                StunningReminderFormField(
                    title: "Reminder Title",
                    icon: "star.fill",
                    placeholder: "e.g., Study for exam, Submit report",
                    text: $title,
                    primaryColor: primaryColor,
                    themeManager: themeManager,
                    isValid: isTitleValid || !showValidationErrors,
                    errorMessage: "Please enter a reminder title",
                    isFocused: focusedField == .title
                )
                .focused($focusedField, equals: .title)
                .submitLabel(.done)
                
                // Date & Time Picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                        Text("Date & Time")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        DatePicker("Select date and time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(primaryColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Category Section
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Category")
                .font(.forma(.title2, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if viewModel.categories.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tag")
                        .font(.forma(.title2))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("No categories yet")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Categories help organize your reminders")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(viewModel.categories) { category in
                        CategorySelectionCard(
                            category: category,
                            isSelected: (categoryId ?? viewModel.categories.first?.id).map { $0 == category.id } ?? false,
                            onTap: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    categoryId = category.id
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Settings")
                    .font(.forma(.title2, weight: .semibold))
                
                Spacer()
                
                Text("Optional")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                Capsule()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
            
            VStack(alignment: .leading, spacing: 20) {
                // Notification Setting
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.forma(.subheadline))
                            .foregroundColor(primaryColor)
                        Text("Notification")
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Picker("Notification", selection: $reminderTime) {
                            ForEach(ReminderTime.allCases, id: \.self) { rt in
                                Text(rt.displayName)
                                    .font(.forma(.body))
                                    .tag(rt)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(primaryColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Calendar Sync Settings
                VStack(alignment: .leading, spacing: 16) {
                    StunningToggleField(
                        title: "Sync to Apple Calendar",
                        icon: "calendar",
                        isOn: $syncToApple,
                        primaryColor: primaryColor,
                        themeManager: themeManager
                    )
                    
                    StunningToggleField(
                        title: "Sync to Google Calendar",
                        icon: "globe",
                        isOn: $syncToGoogle,
                        primaryColor: primaryColor,
                        themeManager: themeManager
                    )
                }
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    saveReminder()
                }) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else if saveSuccess {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .scaleEffect(bounceAnimation * 0.2 + 0.8)
                        } else {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        if !isLoading {
                            Text(saveSuccess ? "Added!" : "Add Reminder")
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, saveSuccess ? 24 : 28)
                    .padding(.vertical, 16)
                    .background(
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: saveSuccess ? [.green, .green.opacity(0.8)] :
                                               isFormValid ? [primaryColor, primaryColor.opacity(0.8)] :
                                               [Color.Color_secondary.opacity(0.6), Color.Color_secondary.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isLoading && !saveSuccess {
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
                            color: saveSuccess ? .green.opacity(0.4) : 
                                   isFormValid ? primaryColor.opacity(0.4) : .clear,
                            radius: 6, // PERF FIX
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .disabled(!isFormValid || isLoading)
                .buttonStyle(EventsBounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: saveSuccess)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFormValid)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    // Removed continuous animations for performance - they were causing text input lag
    private func startAnimations() {
        // No continuous animations - keeps text input smooth
    }
    
    private func setupInitialCategory() {
        if categoryId == nil {
            categoryId = viewModel.categories.first?.id
        }
    }
    
    private func saveReminder() {
        guard isFormValid, !isLoading else {
            showValidationErrors = !isFormValid
            return
        }

        isLoading = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let finalCategoryId = categoryId ?? viewModel.categories.first?.id
            
            guard let catId = finalCategoryId else {
                isLoading = false
                return
            }
            
            let newEvent = Event(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                date: date,
                categoryId: catId,
                reminderTime: reminderTime,
                isCompleted: false,
                externalIdentifier: nil,
                sourceName: nil,
                syncToAppleCalendar: syncToApple,
                syncToGoogleCalendar: syncToGoogle
            )
            
            viewModel.addEvent(newEvent)
            
            isLoading = false
            saveSuccess = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
}

// MARK: - Stunning Reminder Form Field Component
struct StunningReminderFormField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    let primaryColor: Color
    let themeManager: ThemeManager
    let isValid: Bool
    let errorMessage: String
    let isFocused: Bool
    var keyboardType: UIKeyboardType = .default
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.subheadline))
                    .foregroundColor(isFocused ? primaryColor : .secondary)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(isFocused ? primaryColor : .primary)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            HStack {
                TextField(placeholder, text: $text)
                    .font(.forma(.body))
                    .foregroundColor(.primary)
                    .keyboardType(keyboardType)
                    .textFieldStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isFocused ? primaryColor.opacity(0.6) :
                                !isValid ? .red.opacity(0.6) :
                                    Color.secondary.opacity(0.3),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .animation(.easeInOut(duration: 0.2), value: isValid)
            
            if !isValid {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.forma(.caption))
                        .foregroundColor(.red)
                    
                    Text(errorMessage)
                        .font(.forma(.caption))
                        .foregroundColor(.red)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isValid)
    }
}

// MARK: - Stunning Toggle Field Component
struct StunningToggleField: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    let primaryColor: Color
    let themeManager: ThemeManager
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.subheadline))
                    .foregroundColor(isOn ? primaryColor : .secondary)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isOn)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(isOn ? primaryColor : .primary)
                    .animation(.easeInOut(duration: 0.2), value: isOn)
                
                Spacer()
                
                Toggle("", isOn: $isOn)
                    .tint(primaryColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isOn ? primaryColor.opacity(0.6) : Color.secondary.opacity(0.3),
                                lineWidth: isOn ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isOn ? primaryColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0.1) : .clear,
                        radius: isOn ? 8 : 0,
                        x: 0,
                        y: isOn ? 4 : 0
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: isOn)
        }
    }
}