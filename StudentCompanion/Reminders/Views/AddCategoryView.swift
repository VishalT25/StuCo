import SwiftUI

struct AddCategoryView: View {
    @Binding var isPresented: Bool
    let existingCategory: Category?
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    
    @State private var categoryName: String = ""
    @State private var selectedColor: Color = .blue
    @State private var showValidationErrors = false
    @State private var isLoading = false
    @State private var saveSuccess = false
    @State private var showDeleteAlert = false
    
    // Animation states
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var bounceAnimation: Double = 0
    @State private var showContent = false
    
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField {
        case name
    }
    
    private let availableColors: [Color] = [
        .blue, .green, .orange, .red, .purple, .pink,
        .teal, .indigo, .mint, .cyan, .yellow, .brown
    ]
    
    init(isPresented: Binding<Bool>, existingCategory: Category? = nil) {
        self._isPresented = isPresented
        self.existingCategory = existingCategory
        
        if let category = existingCategory {
            _categoryName = State(initialValue: category.name)
            _selectedColor = State(initialValue: category.color)
        }
    }
    
    private var isFormValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var isEditing: Bool {
        existingCategory != nil
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Spectacular animated background
                spectacularBackground
                
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 21) {
                        // Hero header section
                        heroSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : -30)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.075), value: showContent)
                        
                        // Category details form
                        categoryFormSection
                            .opacity(showContent ? 1 : 0)
                            .offset(y: showContent ? 0 : 50)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.15), value: showContent)
                        
                        // Color selection section
                        colorSelectionSection
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
                    isPresented = false
                }
            }
        }
        .alert("Delete Category?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text("This will permanently delete this category and may affect existing reminders.")
        }
        .navigationTitle("New Category")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") { 
                    isPresented = false
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    saveCategory()
                    isPresented = false
                }
                .disabled(!isFormValid)
                .foregroundColor(!isFormValid ? .gray : .blue)
            }
        }
    }
    
    // MARK: - Spectacular Background
    private var spectacularBackground: some View {
        ZStack {
            // Base gradient background
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
            
            // Animated floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                selectedColor.opacity(0.1 - Double(index) * 0.015),
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
                Text(isEditing ? "Edit Category" : "New Category")
                    .font(.forma(.largeTitle, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                selectedColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(bounceAnimation * 0.1 + 0.9)
                
                Text(isEditing ? "Update your category details" : "Organize your reminders with custom categories")
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
                    radius: 6, // PERF FIX
                    x: 0,
                    y: 10
                )
        )
    }
    
    // MARK: - Category Form Section
    private var categoryFormSection: some View {
        VStack(spacing: 24) {
            Text("Category Details")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Category Name Field
            StunningCategoryFormField(
                title: "Category Name",
                icon: "tag.fill",
                placeholder: "e.g., Work, School, Personal",
                text: $categoryName,
                selectedColor: selectedColor,
                themeManager: themeManager,
                isValid: isFormValid || !showValidationErrors,
                errorMessage: "Please enter a category name",
                isFocused: focusedField == .name
            )
            .focused($focusedField, equals: .name)
            .submitLabel(.done)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                // PERF FIX: Solid color
                .fill(Color(.systemBackground).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Color Selection Section
    private var colorSelectionSection: some View {
        VStack(spacing: 24) {
            Text("Category Color")
                .font(.forma(.title2, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 6), spacing: 16) {
                ForEach(availableColors, id: \.self) { color in
                    ModernCategoryColorButton(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            selectedColor = color
                        }
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
                        .stroke(selectedColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Floating Action Buttons
    private var floatingActionButtons: some View {
        VStack {
            Spacer()
            
            HStack {
                // Delete Button (only for existing categories)
                if isEditing {
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.red, .red.opacity(0.8)],
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
                                                angle: .degrees(45)
                                            )
                                        )
                                }
                                .shadow(color: .red.opacity(0.4), radius: 6, x: 0, y: 4)
                                .shadow(color: .red.opacity(0.2), radius: 8, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(EventsBounceButtonStyle())
                }
                
                Spacer()
                
                // Save Button
                Button(action: saveCategory) {
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
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                        }
                        
                        if !isLoading {
                            Text(saveSuccess ? (isEditing ? "Saved!" : "Added!") : (isEditing ? "Save Changes" : "Create Category"))
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
                                               isFormValid ? [selectedColor, selectedColor.opacity(0.8)] :
                                               [.secondary.opacity(0.6), .secondary.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            if !isLoading && !saveSuccess && isFormValid {
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
                            
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.2),
                                            Color.clear
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                        .shadow(
                            color: saveSuccess ? .green.opacity(0.4) : 
                                   isFormValid ? selectedColor.opacity(0.4) : .clear,
                            radius: 6, // PERF FIX
                            x: 0,
                            y: 8
                        )
                        .shadow(
                            color: saveSuccess ? .green.opacity(0.2) : 
                                   isFormValid ? selectedColor.opacity(0.2) : .clear,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                        .scaleEffect(bounceAnimation * 0.1 + 0.9)
                    )
                }
                .disabled(!isFormValid || isLoading)
                .buttonStyle(EventsBounceButtonStyle())
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
    
    private func saveCategory() {
        guard isFormValid else {
            showValidationErrors = true
            return
        }
        
        isLoading = true
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if let existingCategory = existingCategory {
                // IMPORTANT: Preserve link fields when updating existing category
                var updatedCategory = existingCategory
                updatedCategory.name = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                updatedCategory.color = selectedColor
                // scheduleId and courseId are preserved from existingCategory
                viewModel.updateCategory(updatedCategory)
            } else {
                // New category - no link fields initially
                let categoryData = Category(
                    name: categoryName.trimmingCharacters(in: .whitespacesAndNewlines),
                    color: selectedColor
                )
                viewModel.addCategory(categoryData)
            }
            
            isLoading = false
            saveSuccess = true
            
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
    }
    
    private func deleteCategory() {
        if let existingCategory = existingCategory {
            viewModel.deleteCategory(existingCategory)
        }
        isPresented = false
    }
}

// MARK: - Stunning Category Form Field Component
struct StunningCategoryFormField: View {
    let title: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    let selectedColor: Color
    let themeManager: ThemeManager
    let isValid: Bool
    let errorMessage: String
    let isFocused: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.forma(.subheadline))
                    .foregroundColor(isFocused ? selectedColor : .secondary)
                    .frame(width: 20)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
                
                Text(title)
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(isFocused ? selectedColor : .primary)
                    .animation(.easeInOut(duration: 0.2), value: isFocused)
            }
            
            TextField(placeholder, text: $text)
                .font(.forma(.body, weight: .medium))
                .foregroundColor(.primary)
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
                                    isFocused ? selectedColor.opacity(0.6) :
                                    !isValid ? .red.opacity(0.6) :
                                    Color.secondary.opacity(0.3),
                                    lineWidth: isFocused ? 2 : 1
                                )
                        )
                        .shadow(
                            color: isFocused ? selectedColor.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.2 : 0.1) : .clear,
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

// MARK: - Modern Category Color Button
struct ModernCategoryColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 40, height: 40)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .shadow(color: isSelected ? color.opacity(0.4) : color.opacity(0.2), radius: isSelected ? 8 : 4, x: 0, y: isSelected ? 4 : 2)
        }
        .buttonStyle(SpringButtonStyle())
    }
}

#Preview {
    AddCategoryView(isPresented: .constant(true))
        .environmentObject(EventViewModel())
        .environmentObject(ThemeManager())
}