import SwiftUI

struct AddEditAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var calendar: AcademicCalendar?
    
    @State private var name: String = ""
    @State private var academicYear: String = ""
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var isCreating = false
    @State private var errorMessage: String?
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    // Performance optimization
    @State private var isViewActive = true
    @State private var shouldRenderAnimations = true
    
    private var isEditing: Bool {
        calendar != nil
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        endDate > startDate
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }
    
    var body: some View {
        ZStack {
            if isViewActive {
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
                            
                            // Breaks management section (only when editing)
                            if isEditing, let cal = calendar {
                                breaksManagementSection(cal)
                                    .opacity(showContent ? 1 : 0)
                                    .offset(y: showContent ? 0 : 50)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                            }
                            
                            // Bottom padding for floating button
                            Spacer()
                                .frame(height: 120)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 30)
                    }
                    
                    Spacer()
                }
                
                // Floating action button (simplified to avoid complex overlays)
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            Task { await saveCalendar() }
                        }) {
                            HStack(spacing: 12) {
                                if isCreating {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .tint(.white)
                                } else {
                                    Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)
                                }
                                
                                if !isCreating {
                                    Text(isEditing ? "Save Changes" : "Create Calendar")
                                        .font(.forma(.headline, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: !isValid ? [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                                   [currentTheme.primaryColor, currentTheme.primaryColor.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(
                                        color: !isValid ? .clear : currentTheme.primaryColor.opacity(0.4),
                                        radius: 16,
                                        x: 0,
                                        y: 8
                                    )
                            )
                        }
                        .disabled(!isValid)
                        .buttonStyle(BounceButtonStyle())
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            } else {
                // Placeholder view when inactive
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle(calendar == nil ? "New Calendar" : "Edit Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task { await saveCalendar() }
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
        .onAppear {
            isViewActive = true
            shouldRenderAnimations = true
            setup()
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .onDisappear {
            stopAnimations()
            shouldRenderAnimations = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isViewActive = false
            }
        }
        .onChange(of: isViewActive) { _, newValue in
            if newValue {
                shouldRenderAnimations = true
                startAnimations()
            } else {
                shouldRenderAnimations = false
                stopAnimations()
            }
        }
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Animated floating shapes - only render if active
            if shouldRenderAnimations {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.015),
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
                        .blur(radius: CGFloat(index * 2))
                }
            }
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Text(isEditing ? "Edit Academic Calendar" : "Create Academic Calendar")
                    .font(.forma(.largeTitle, weight: .bold))
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
                    .multilineTextAlignment(.center)
                
                Text("Manage semester dates, breaks, and holidays to keep all your schedules perfectly organized.")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.3),
                                    currentTheme.primaryColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: currentTheme.primaryColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 20,
                    x: 0,
                    y: 10
                )
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
                    StunningFormField(
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
                    
                    StunningFormField(
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
    
    // MARK: - Breaks Management Section
    private func breaksManagementSection(_ cal: AcademicCalendar) -> some View {
        VStack(spacing: 20) {
            Text("Breaks & Holidays")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(currentTheme.primaryColor.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "calendar.badge.checkmark")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(currentTheme.primaryColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage Breaks")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(cal.breaks.count) break\(cal.breaks.count == 1 ? "" : "s") configured")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    NavigationLink {
                        AcademicCalendarEditorView(academicCalendar: $calendar)
                            .environmentObject(academicCalendarManager)
                            .environmentObject(themeManager)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Configure")
                                .font(.forma(.caption, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.forma(.caption2, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(currentTheme.primaryColor)
                                .shadow(
                                    color: currentTheme.primaryColor.opacity(0.3),
                                    radius: 8,
                                    x: 0,
                                    y: 4
                                )
                        )
                    }
                    .buttonStyle(SpringButtonStyle())
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
                        .stroke(currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Helper Methods
    private func startAnimations() {
        guard shouldRenderAnimations else { return }
        
        withAnimation(.linear(duration: 22.5).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
        
        withAnimation(.easeInOut(duration: 2.25).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
    
    private func stopAnimations() {
        withAnimation(.linear(duration: 0)) {
            animationOffset = 0
        }
        
        withAnimation(.linear(duration: 0)) {
            pulseAnimation = 1.0
        }
        shouldRenderAnimations = false
    }
    
    private func setup() {
        if let cal = calendar {
            name = cal.name
            academicYear = cal.academicYear
            startDate = cal.startDate
            endDate = cal.endDate
        } else {
            // Set up defaults for new calendar
            let currentYear = Calendar.current.component(.year, from: Date())
            let currentMonth = Calendar.current.component(.month, from: Date())
            
            let academicStartYear = currentMonth >= 8 ? currentYear : currentYear - 1
            academicYear = "\(academicStartYear)-\(academicStartYear + 1)"
            name = ""
            startDate = Calendar.current.date(from: DateComponents(year: academicStartYear, month: 8, day: 15)) ?? Date()
            endDate = Calendar.current.date(from: DateComponents(year: academicStartYear + 1, month: 6, day: 15)) ?? Date()
        }
    }
    
    private func saveCalendar() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCreating = true
        }
        
        errorMessage = nil
        
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedYear = academicYear.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            if let existingCalendar = calendar {
                // Update existing calendar
                var updatedCalendar = existingCalendar
                updatedCalendar.name = trimmedName
                updatedCalendar.academicYear = trimmedYear
                updatedCalendar.startDate = startDate
                updatedCalendar.endDate = endDate
                
                academicCalendarManager.updateCalendar(updatedCalendar)
                calendar = updatedCalendar
            } else {
                // Create new calendar
                let newCalendar = AcademicCalendar(
                    name: trimmedName,
                    academicYear: trimmedYear,
                    termType: .semester,
                    startDate: startDate,
                    endDate: endDate
                )
                
                academicCalendarManager.addCalendar(newCalendar)
            }
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isCreating = false
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save calendar: \(error.localizedDescription)"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isCreating = false
            }
        }
    }
}

#Preview {
    AddEditAcademicCalendarView(calendar: .constant(nil))
        .environmentObject(ThemeManager())
        .environmentObject(AcademicCalendarManager())
}