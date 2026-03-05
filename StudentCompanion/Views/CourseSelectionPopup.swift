import SwiftUI

struct CourseSelectionPopup: View {
    let originalInput: String
    let suggestedAlias: String
    let availableCourses: [Course]
    let onCourseSelected: (Course) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedCourse: Course?
    @State private var searchText = ""
    @State private var showAnimation = false
    @EnvironmentObject var themeManager: ThemeManager
    
    var filteredCourses: [Course] {
        if searchText.isEmpty {
            return availableCourses
        } else {
            return availableCourses.filter { course in
                course.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAnimation = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss()
                    }
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main popup card
                VStack(spacing: 0) {
                    // Header
                    VStack(spacing: 16) {
                        // Icon and title
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Course Not Found")
                                    .font(.headline.bold())
                                    .foregroundColor(.primary)
                                
                                Text("Select the correct course")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showAnimation = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onDismiss()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Context message
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("You mentioned:")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            Text("\(suggestedAlias)")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 20)
                    
                    Divider()
                        .opacity(0.3)
                    
                    // Search bar
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .font(.system(size: 16))
                            
                            TextField("Search courses...", text: $searchText)
                                .font(.subheadline)
                                .textFieldStyle(.plain)
                            
                            if !searchText.isEmpty {
                                Button {
                                    searchText = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(UIColor.tertiarySystemBackground))
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // Course list
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredCourses.prefix(6), id: \.id) { course in
                                CourseRowView(
                                    course: course,
                                    isSelected: selectedCourse?.id == course.id,
                                    themeManager: themeManager
                                ) {
                                    selectedCourse = course
                                    
                                    // Haptic feedback
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    
                                    // Animate selection and then call completion
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showAnimation = false
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        onCourseSelected(course)
                                    }
                                }
                            }
                            
                            if filteredCourses.count > 6 {
                                let remainingCount = filteredCourses.count - 6
                                Text("+ \(remainingCount) more courses")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }
                            
                            if filteredCourses.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "magnifyingglass")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                    
                                    Text("No courses found")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("Try adjusting your search")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 24)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 280)
                    
                    // Footer
                    HStack {
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showAnimation = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDismiss()
                            }
                        } label: {
                            Text("Cancel")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                )
                        }
                        
                        Spacer()
                        
                        let courseCount = filteredCourses.count
                        Text("\(courseCount) course\(courseCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.quaternary, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .padding(.horizontal, 20)
                .scaleEffect(showAnimation ? 1.0 : 0.8)
                .opacity(showAnimation ? 1.0 : 0.0)
                
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showAnimation = true
            }
        }
    }
}

struct CourseRowView: View {
    let course: Course
    let isSelected: Bool
    let themeManager: ThemeManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Course icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(course.color.opacity(0.2))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: course.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(course.color)
                }
                
                // Course details
                VStack(alignment: .leading, spacing: 4) {
                    Text(course.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    let assignmentCount = course.assignments.count
                    Text("\(assignmentCount) assignment\(assignmentCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected ? 
                        themeManager.currentTheme.primaryColor.opacity(0.08) :
                        Color(UIColor.secondarySystemBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? 
                                themeManager.currentTheme.primaryColor.opacity(0.3) :
                                Color.clear,
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// Preview
#if DEBUG
class PreviewThemeManagerForCourse: ObservableObject {
    struct Theme {
        var primaryColor: Color = .blue
        var secondaryColor: Color = .green
        var tertiaryColor: Color = .orange
    }
    @Published var currentTheme: Theme = Theme()
}

#endif
