import SwiftUI
import Combine

struct AddAssignmentView: View {
    let course: Course
    let courseManager: UnifiedCourseManager?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @StateObject private var assignment: Assignment
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
        case name, grade, weight, notes
    }
    
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var showAuthAlert = false
    
    init(course: Course, courseManager: UnifiedCourseManager?) {
        self.course = course
        self.courseManager = courseManager
        // Create assignment with unique ID immediately
        self._assignment = StateObject(wrappedValue: Assignment(
            id: UUID(), // Always generate new UUID
            courseId: course.id,
            name: "",
            grade: "",
            weight: "",
            notes: ""
        ))
    }
    
    // Validation computed properties
    private var isNameValid: Bool { !assignment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isGradeValid: Bool { assignment.grade.isEmpty || (Double(assignment.grade) != nil && (0...100).contains(Double(assignment.grade) ?? -1)) }
    private var isWeightValid: Bool { assignment.weight.isEmpty || (Double(assignment.weight) != nil && (0...100).contains(Double(assignment.weight) ?? -1)) }
    private var isFormValid: Bool { isNameValid && isGradeValid && isWeightValid }
    
    private var gradePlaceholder: String {
        "e.g., 95, 87.5"
    }
    
    private var weightPlaceholder: String {
        "e.g., 20"
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.225) {
                showContent = true
                focusedField = .name
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
        .alert("Sign in required", isPresented: $showAuthAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please sign in to add assignments.")
        }
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
    
    // MARK: - Hero Section (simplified)
    private var heroSection: some View {
        VStack(spacing: 16) {
            // Main title with animation
            VStack(spacing: 9) {
                Text("New Assignment")
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
                
                HStack(spacing: 8) {
                    Text("Adding to")
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
                
                Text("Create a detailed assignment to track your academic progress")
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
                AssignmentStunningFormField(
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
                    AssignmentStunningFormField(
                        title: "Grade",
                        icon: "percent",
                        placeholder: gradePlaceholder,
                        text: $assignment.grade,
                        courseColor: course.color,
                        themeManager: themeManager,
                        isValid: isGradeValid || !showValidationErrors,
                        errorMessage: "Enter 0-100",
                        isFocused: focusedField == .grade,
                        keyboardType: .decimalPad
                    )
                    .focused($focusedField, equals: .grade)
                    
                    // Weight Input
                    AssignmentStunningFormField(
                        title: "Weight",
                        icon: "scalemass.fill",
                        placeholder: weightPlaceholder,
                        text: $assignment.weight,
                        courseColor: course.color,
                        themeManager: themeManager,
                        isValid: isWeightValid || !showValidationErrors,
                        errorMessage: "Enter 0-100",
                        isFocused: focusedField == .weight,
                        keyboardType: .decimalPad
                    )
                    .focused($focusedField, equals: .weight)
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

            // Due Date Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.forma(.subheadline))
                        .foregroundColor(course.color)
                        .frame(width: 20)

                    Text("Due Date")
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    if assignment.dueDate != nil {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                assignment.dueDate = nil
                            }
                        }) {
                            Text("Clear")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(course.color)
                        }
                    }
                }

                DatePicker(
                    "",
                    selection: Binding(
                        get: { assignment.dueDate ?? Date() },
                        set: { assignment.dueDate = $0 }
                    ),
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
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
    
    // MARK: - Floating Action Button
    private var floatingActionButton: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
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
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isLoading {
                            Text(saveSuccess ? "Added!" : "Add Assignment")
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
            .padding(.trailing, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Helper Methods
    // Removed continuous animations for performance - they were causing text input lag
    private func startAnimations() {
        // No continuous animations - keeps text input smooth
    }
    
    private func saveAssignment() {
        guard isFormValid else {
            showValidationErrors = true
            return
        }
        guard supabaseService.isAuthenticated else {
            showAuthAlert = true
            return
        }
        
        isLoading = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        assignment.name = assignment.name.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.grade = assignment.grade.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.weight = assignment.weight.trimmingCharacters(in: .whitespacesAndNewlines)
        assignment.notes = assignment.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        assignment.courseId = course.id
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if !course.assignments.contains(where: { $0.id == assignment.id }) {
                course.assignments.append(assignment)
                courseManager?.addAssignment(assignment, to: course.id)
            }
            
            isLoading = false
            saveSuccess = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
}

// MARK: - Stunning Form Field Component
struct AssignmentStunningFormField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    let courseColor: Color
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
                    .foregroundColor(isFocused ? courseColor : .secondary)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(isFocused ? courseColor : .primary)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            TextField(placeholder, text: $text)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(.primary)
                .keyboardType(keyboardType)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isFocused ? courseColor.opacity(0.6) :
                                    !isValid ? .red.opacity(0.6) :
                                    Color.secondary.opacity(0.3),
                                    lineWidth: isFocused ? 2 : 1
                                )
                        )
                        .shadow(
                            color: isFocused ? courseColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0.1) : .clear,
                            radius: isFocused ? 8 : 0,
                            x: 0,
                            y: isFocused ? 4 : 0
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

#Preview {
    struct PreviewWrapper: View {
        @StateObject var sampleCourse = Course(
            scheduleId: UUID(),
            name: "Advanced Mathematics",
            iconName: "function",
            colorHex: Color.purple.toHex() ?? "FF0000"
        )
        
        var body: some View {
            AddAssignmentView(course: sampleCourse, courseManager: nil)
                .environmentObject(ThemeManager())
        }
    }
    return PreviewWrapper()
}