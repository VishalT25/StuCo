import SwiftUI

struct EditAcademicCalendarView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let calendar: AcademicCalendar
    @State private var editedCalendar: AcademicCalendar
    @State private var showingBreakManager = false
    @State private var isUpdating = false
    @State private var errorMessage: String?
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    init(calendar: AcademicCalendar) {
        self.calendar = calendar
        self._editedCalendar = State(initialValue: calendar)
    }
    
    private var isValid: Bool {
        !editedCalendar.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !editedCalendar.academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        editedCalendar.endDate > editedCalendar.startDate
    }
    
    private var currentTheme: AppTheme {
        themeManager.currentTheme
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
                            
                            // Breaks management section
                            breaksManagementSection
                                .opacity(showContent ? 1 : 0)
                                .offset(y: showContent ? 0 : 50)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
                
                // Floating action button
                floatingActionButton
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .navigationTitle("Edit Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task { await saveChanges() }
                }
                .disabled(!isValid)
            }
        }
        .sheet(isPresented: $showingBreakManager) {
            AcademicCalendarEditorView(academicCalendar: Binding(
                get: { editedCalendar },
                set: { if let newValue = $0 { editedCalendar = newValue } }
            ))
            .environmentObject(themeManager)
            .environmentObject(academicCalendarManager)
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
            
            // Animated floating shapes
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
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 12) {
            VStack(alignment: .center, spacing: 8) {
                Text("Edit Academic Calendar")
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
                
                HStack(spacing: 6) {
                    Text("Updating")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    
                    Text(calendar.name)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(currentTheme.primaryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(currentTheme.primaryColor.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Text("Update calendar details and manage academic breaks to keep your schedules perfectly organized.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
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
                        placeholder: "Calendar Name",
                        text: $editedCalendar.name,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !editedCalendar.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Please enter a calendar name",
                        isFocused: false
                    )
                    
                    StunningFormField(
                        title: "Academic Year",
                        icon: "calendar",
                        placeholder: "2024-2025",
                        text: $editedCalendar.academicYear,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !editedCalendar.academicYear.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
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
                        selection: $editedCalendar.startDate
                    )
                    
                    datePickerField(
                        title: "End Date",
                        icon: "calendar.badge.minus",
                        selection: $editedCalendar.endDate,
                        range: editedCalendar.startDate...
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
                        
                        Text("The academic year \(editedCalendar.academicYear) will span from \(formatDate(editedCalendar.startDate)) to \(formatDate(editedCalendar.endDate))")
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
    private var breaksManagementSection: some View {
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
                            .font(.forma(.body, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("\(editedCalendar.breaks.count) break\(editedCalendar.breaks.count == 1 ? "" : "s") configured")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingBreakManager = true
                    } label: {
                        HStack(spacing: 6) {
                            Text("Configure")
                                .font(.forma(.caption, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.forma(.caption2, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
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
                
                // Preview of breaks
                if !editedCalendar.breaks.isEmpty {
                    let upcomingBreaks = editedCalendar.breaks
                        .filter { $0.endDate >= Date() }
                        .sorted { $0.startDate < $1.startDate }
                        .prefix(3)
                    
                    if !upcomingBreaks.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(Array(upcomingBreaks), id: \.id) { break_ in
                                HStack(spacing: 12) {
                                    Image(systemName: break_.type.icon)
                                        .font(.forma(.subheadline))
                                        .foregroundColor(break_.type.color)
                                        .frame(width: 16)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(break_.name)
                                            .font(.forma(.subheadline, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        Text(break_.startDate, format: .dateTime.day().month().year())
                                            .font(.forma(.caption))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(break_.type.displayName)
                                        .font(.forma(.caption, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(break_.type.color.opacity(0.15))
                                        )
                                        .foregroundColor(break_.type.color)
                                }
                            }
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
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
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                Button(action: {
                    Task { await saveChanges() }
                }) {
                    HStack(spacing: 12) {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isUpdating {
                            Text("Save Changes")
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
                                        colors: !isValid ? [.secondary.opacity(0.6), .secondary.opacity(0.4)] :
                                               [currentTheme.primaryColor, currentTheme.primaryColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isUpdating && isValid {
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
                            color: !isValid ? .clear : currentTheme.primaryColor.opacity(0.4),
                            radius: 16,
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .disabled(!isValid)
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isValid)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func saveChanges() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isUpdating = true
        }
        
        errorMessage = nil
        
        do {
            academicCalendarManager.updateCalendar(editedCalendar)
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isUpdating = false
            }
            
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isUpdating = false
            }
        }
    }
}

#Preview {
    EditAcademicCalendarView(calendar: AcademicCalendar.sampleCalendar)
        .environmentObject(ThemeManager())
        .environmentObject(AcademicCalendarManager())
}