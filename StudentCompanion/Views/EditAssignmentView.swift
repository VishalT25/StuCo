import SwiftUI
import Combine

struct EditAssignmentView: View {
    @ObservedObject var assignment: Assignment
    let course: Course
    let courseManager: UnifiedCourseManager?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showValidationErrors = false
    @State private var isLoading = false
    @State private var saveSuccess = false
    @State private var showDeleteAlert = false // NEW: For delete confirmation
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false

    // Due date states
    @State private var hasDueDate: Bool = false
    @State private var tempDueDate: Date = Date()
    
    // Focus states
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case name, grade, weight, notes, dueDate
    }
    
    // Validation computed properties
    private var isNameValid: Bool { !assignment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isGradeValid: Bool { assignment.grade.isEmpty || (Double(assignment.grade) != nil && (0...100).contains(Double(assignment.grade) ?? -1)) }
    private var isWeightValid: Bool { assignment.weight.isEmpty || (Double(assignment.weight) != nil && (0...100).contains(Double(assignment.weight) ?? -1)) }
    private var isFormValid: Bool { isNameValid && isGradeValid && isWeightValid }
    
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
                        
                        // Assignment details form
                        assignmentFormSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                        
                        // Additional details section
                        additionalDetailsSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.225), value: showContent)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 30)
                    .padding(.bottom, 30)
                }
                
                // Floating action buttons
                floatingActionButtons
            }
        }
        .navigationBarHidden(true)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(false)
        .onAppear {
            // Initialize due date state
            if let existingDueDate = assignment.dueDate {
                hasDueDate = true
                tempDueDate = existingDueDate
            } else {
                hasDueDate = false
                tempDueDate = Date()
            }

            startAnimations()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
            }
        }
        .onChange(of: saveSuccess) { _, newValue in
            if newValue {
                withAnimation(.spring(response: 0.375, dampingFraction: 0.8)) {
                    bounceAnimation = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.125) {
                    dismiss()
                }
            }
        }
        .alert("Delete Assignment?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAssignment()
            }
        } message: {
            Text("This will permanently delete '\(assignment.name.isEmpty ? "this assignment" : assignment.name)'.")
        }
    }
    
    // MARK: - Floating Action Buttons (Save and Delete)
    private var floatingActionButtons: some View {
        VStack {
            Spacer()
            
            HStack {
                // Delete Button
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.red, .red.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: .red.opacity(0.4), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(BounceButtonStyle())
                
                Spacer()
                
                // Save Button
                Button(action: {
                    saveAssignment()
                }) {
                    HStack(spacing: 12) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else if saveSuccess {
                            Image(systemName: "checkmark")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .scaleEffect(bounceAnimation * 0.2 + 0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isLoading {
                            Text(saveSuccess ? "Saved!" : "Save Changes")
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
                                               isFormValid ? [course.color, course.color.opacity(0.8)] :
                                               [.secondary.opacity(0.6), .secondary.opacity(0.4)],
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
                                   isFormValid ? course.color.opacity(0.4) : .clear,
                            radius: 6, // PERF FIX
                            x: 0,
                            y: 8
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .disabled(!isFormValid || isLoading)
                .buttonStyle(BounceButtonStyle())
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: saveSuccess)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFormValid)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    // Removed continuous animations for performance - they were causing text input lag
    private func startAnimations() {
        // No continuous animations - keeps text input smooth
    }
    
    private func saveAssignment() {
        // Validate form
        guard isFormValid else {
            showValidationErrors = true
            return
        }
        
        // Start loading state
        isLoading = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // Clean up assignment data
        assignment.name = assignment.name.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.grade = assignment.grade.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.weight = assignment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.notes = assignment.notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update due date based on toggle
        if hasDueDate {
            assignment.dueDate = tempDueDate
        } else {
            assignment.dueDate = nil
        }

        // Simulate saving delay for smooth UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Update via course manager if available
            courseManager?.updateAssignment(assignment, in: course.id)
            
            // Update states
            isLoading = false
            saveSuccess = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
    
    private func deleteAssignment() {
        // Remove from course
        course.assignments.removeAll { $0.id == assignment.id }
        
        // Delete via course manager if available
        courseManager?.deleteAssignment(assignment.id, from: course.id)
        
        // Provide feedback
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
        
        // Dismiss view
        dismiss()
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
            LinearGradient(
                colors: [
                    course.color.opacity(colorScheme == .dark ? 0.15 : 0.05),
                    course.color.opacity(colorScheme == .dark ? 0.08 : 0.02),
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
                                course.color.opacity(0.1 - Double(index) * 0.015),
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
    
    // MARK: - Hero Section (improved layout)
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Main title with animation
            VStack(spacing: 9) {
                Text("Edit Assignment")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                course.color,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(bounceAnimation * 0.1 + 0.9)
                
                // Better positioned course info
                HStack(spacing: 8) {
                    Text("Editing in")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: course.iconName)
                            .font(.forma(.caption))
                            .foregroundColor(course.color)
                        
                        Text(course.name)
                            .font(.forma(.subheadline, weight: .medium))
                            .foregroundColor(course.color)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(course.color.opacity(0.1))
                            .overlay(
                                Capsule()
                                    .stroke(course.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                Text("Update assignment details and track your academic progress")
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
                                    course.color.opacity(0.3),
                                    course.color.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: course.color.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15),
                    radius: 6, // PERF FIX
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Assignment Form Section
    private var assignmentFormSection: some View {
        VStack(spacing: 24) {
            Text("Assignment Details")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 20) {
                // Assignment Name
                StunningFormField(
                    title: "Assignment Name",
                    icon: "doc.text.fill",
                    placeholder: "e.g., Midterm Exam, Lab Report 3",
                    text: $assignment.name,
                    courseColor: course.color,
                    themeManager: themeManager,
                    isValid: isNameValid || !showValidationErrors,
                    errorMessage: "Please enter an assignment name",
                    isFocused: focusedField == .name
                )
                .focused($focusedField, equals: .name)
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .grade
                }
                
                // Grade and Weight Row
                HStack(spacing: 16) {
                    // Grade Input
                    StunningFormField(
                        title: "Grade",
                        icon: "percent",
                        placeholder: "e.g., 95, 87.5",
                        text: $assignment.grade,
                        courseColor: course.color,
                        themeManager: themeManager,
                        isValid: isGradeValid || !showValidationErrors,
                        errorMessage: "Enter 0-100",
                        isFocused: focusedField == .grade
                    )
                    .focused($focusedField, equals: .grade)
                    .keyboardType(.decimalPad)
                    
                    // Weight Input  
                    StunningFormField(
                        title: "Weight",
                        icon: "scalemass.fill",
                        placeholder: "e.g., 20",
                        text: $assignment.weight,
                        courseColor: course.color,
                        themeManager: themeManager,
                        isValid: isWeightValid || !showValidationErrors,
                        errorMessage: "Enter 0-100",
                        isFocused: focusedField == .weight
                    )
                    .focused($focusedField, equals: .weight)
                    .keyboardType(.decimalPad)
                }

                // Due Date Picker
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.forma(.subheadline))
                                .foregroundColor(course.color)
                                .frame(width: 20)

                            Text("Due Date")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Toggle("", isOn: $hasDueDate)
                            .labelsHidden()
                            .tint(course.color)
                    }

                    if hasDueDate {
                        DatePicker(
                            "Select Due Date",
                            selection: $tempDueDate,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                        .accentColor(course.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(course.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .scale.combined(with: .opacity)
                        ))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: hasDueDate)
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
                        .stroke(course.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Additional Details Section
    private var additionalDetailsSection: some View {
        VStack(spacing: 24) {
            HStack {
                Text("Additional Details")
                    .font(.forma(.title2, weight: .bold))
                
                Spacer()
                
                Text("Optional")
                    .font(.forma(.caption))
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
            
            // Notes Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "note.text")
                        .font(.forma(.subheadline))
                        .foregroundColor(course.color)
                        .frame(width: 20)
                    
                    Text("Notes")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.primary)
                }
                
                TextEditor(text: $assignment.notes)
                    .font(.forma(.body))
                    .foregroundColor(.primary)
                    .focused($focusedField, equals: .notes)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .overlay(
                        VStack {
                            HStack {
                                if assignment.notes.isEmpty && focusedField != .notes {
                                    Text("Add any notes about this assignment...")
                                        .font(.forma(.body))
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .padding(.top, 8)
                                        .padding(.leading, 4)
                                }
                                Spacer()
                            }
                            Spacer()
                        },
                        alignment: .topLeading
                    )
                    .frame(minHeight: 100)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        focusedField == .notes ? course.color.opacity(0.5) : Color.secondary.opacity(0.3),
                                        lineWidth: focusedField == .notes ? 2 : 1
                                    )
                            )
                    )
                    .animation(.easeInOut(duration: 0.2), value: focusedField == .notes)
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
                        .stroke(course.color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

//// MARK: - Button Style
//struct BounceButtonStyle: ButtonStyle {
//    func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
//            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: configuration.isPressed)
//    }
//}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var sampleCourse = Course(
            scheduleId: UUID(),
            name: "Advanced Mathematics", 
            iconName: "function",
            colorHex: Color.purple.toHex() ?? "FF0000"
        )
        
        @StateObject var sampleAssignment = Assignment(
            id: UUID(),
            courseId: UUID(),
            name: "Midterm Exam",
            grade: "95", 
            weight: "25",
            notes: "Well prepared exam"
        )
        
        var body: some View {
            EditAssignmentView(assignment: sampleAssignment, course: sampleCourse, courseManager: nil)
                .environmentObject(ThemeManager())
        }
    }
    return PreviewWrapper()
}