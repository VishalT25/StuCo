import SwiftUI

struct EditBreakView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var calendar: AcademicCalendar
    let academicBreak: AcademicBreak
    
    @State private var name: String = ""
    @State private var type: BreakType = .custom
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var description: String = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    // Performance optimization
    @State private var isViewActive = true
    @State private var shouldRenderAnimations = true
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate >= startDate
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
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 20)
                        .padding(.bottom, 120)
                    }
                }
                
                // Floating action button
                floatingActionButton
            } else {
                // Placeholder view when inactive
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
            }
        }
        .navigationTitle("Edit Break")
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
        .alert("Delete Break", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteBreak()
            }
        } message: {
            Text("Are you sure you want to delete this break? This action cannot be undone.")
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
            setupFromBreak()
            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .onDisappear {
            stopAnimations()
            shouldRenderAnimations = false
            // Delay deactivation to allow for smooth dismissal animation
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
            VStack(alignment: .center, spacing: 9) {
                Text("Edit Academic Break")
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                
                Text("Update break information and dates to keep your academic calendar accurate.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
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
            // Break Details Section
            VStack(spacing: 20) {
                Text("Break Details")
                    .font(.forma(.title2, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 16) {
                    StunningFormField(
                        title: "Break Name",
                        icon: "text.alignleft",
                        placeholder: "Break Name",
                        text: $name,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        errorMessage: "Please enter a break name",
                        isFocused: false
                    )
                    
                    breakTypeSelector
                    
                    StunningFormField(
                        title: "Description",
                        icon: "note.text",
                        placeholder: "Optional notes about this break",
                        text: $description,
                        courseColor: currentTheme.primaryColor,
                        themeManager: themeManager,
                        isValid: true,
                        errorMessage: "",
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
                Text("Break Period")
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
                
                // Duration indicator
                if startDate != endDate {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                        
                        Text(durationText)
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
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
    
    private var breakTypeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.forma(.subheadline))
                    .foregroundColor(currentTheme.primaryColor)
                
                Text("Break Type")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.primary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(BreakType.allCases, id: \.self) { breakType in
                    breakTypeButton(for: breakType)
                }
            }
        }
    }
    
    private func breakTypeButton(for breakType: BreakType) -> some View {
        Button(action: { 
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                type = breakType
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: breakType.icon)
                    .font(.forma(.title3))
                    .foregroundColor(type == breakType ? .white : breakType.color)
                    .frame(width: 24, alignment: .leading)
                
                Text(breakType.displayName)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(type == breakType ? .white : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(type == breakType
                          ? AnyShapeStyle(breakType.color)
                          : AnyShapeStyle(.ultraThinMaterial))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                type == breakType ? breakType.color.opacity(0.3) : Color.secondary.opacity(0.2),
                                lineWidth: type == breakType ? 2 : 1
                            )
                    )
                    .shadow(
                        color: type == breakType ? breakType.color.opacity(0.3) : .clear,
                        radius: type == breakType ? 6 : 0,
                        x: 0,
                        y: type == breakType ? 3 : 0
                    )
            )
        }
        .buttonStyle(SpringButtonStyle())
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
    
    // MARK: - Delete Section
    private var deleteSection: some View {
        VStack(spacing: 20) {
            Text("Danger Zone")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.red)
            
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "trash")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Delete Break")
                            .font(.forma(.headline, weight: .semibold))
                            .foregroundColor(.red)
                        
                        Text("Permanently remove this break from the calendar")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.forma(.subheadline, weight: .semibold))
                        .foregroundColor(.red)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        )
                )
            }
            .buttonStyle(SpringButtonStyle())
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var durationText: String {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        if days == 0 {
            return "Single day break"
        } else if days == 1 {
            return "1 day break"
        } else {
            return "\(days) day break"
        }
    }
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                // Delete button on the left
                Button(action: {
                    showingDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(16)
                        .background(
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.red, Color.red.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Circle()
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
                            .shadow(
                                color: Color.red.opacity(0.4),
                                radius: 16,
                                x: 0,
                                y: 8
                            )
                        )
                }
                .buttonStyle(BounceButtonStyle())
                
                Spacer()
                
                // Save button on the right
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
    
    private func setupFromBreak() {
        name = academicBreak.name
        type = academicBreak.type
        startDate = academicBreak.startDate
        endDate = academicBreak.endDate
        description = academicBreak.description
    }
    
    private func saveChanges() async {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isUpdating = true
        }
        
        errorMessage = nil
        
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let index = calendar.breaks.firstIndex(where: { $0.id == academicBreak.id }) {
                calendar.breaks[index].name = trimmedName
                calendar.breaks[index].type = type
                calendar.breaks[index].startDate = startDate
                calendar.breaks[index].endDate = endDate
                calendar.breaks[index].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
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
    
    private func deleteBreak() {
        calendar.breaks.removeAll { $0.id == academicBreak.id }
        dismiss()
    }
}

#Preview {
    EditBreakView(
        calendar: .constant(AcademicCalendar.sampleCalendar),
        academicBreak: AcademicBreak(name: "Spring Break", type: .springBreak, startDate: Date(), endDate: Date())
    )
    .environmentObject(ThemeManager())
}