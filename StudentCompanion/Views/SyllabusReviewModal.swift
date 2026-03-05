import SwiftUI

struct SyllabusReviewModal: View {
    let course: Course
    let importData: SyllabusImportData
    let onImport: ([Assignment]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var assignments: [AIAssignmentItem]
    @State private var searchText = ""
    @State private var showingEditSheet = false
    @State private var editingAssignment: AIAssignmentItem?
    @State private var editingIndex: Int?

    init(course: Course, importData: SyllabusImportData, onImport: @escaping ([Assignment]) -> Void) {
        self.course = course
        self.importData = importData
        self.onImport = onImport
        _assignments = State(initialValue: importData.parsedAssignments)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Stats
                    headerStatsView
                        .padding()
                        .background(Color(uiColor: .systemBackground))

                    // Search Bar
                    searchBar
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                    // Assignments List
                    if filteredAssignments.isEmpty {
                        emptyStateView
                    } else {
                        assignmentsList
                    }

                    // Import Button
                    importButtonView
                        .padding()
                        .background(Color(uiColor: .systemBackground))
                }
            }
            .navigationTitle("Review Assignments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        dismiss()
                    }
                    .font(.custom("FormaDJRDisplay-Regular", size: 16))
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                if let assignment = editingAssignment, let index = editingIndex {
                    AssignmentEditSheet(
                        assignment: assignment,
                        courseColor: course.color,
                        onSave: { updatedAssignment in
                            assignments[index] = updatedAssignment
                            showingEditSheet = false
                        },
                        onDelete: {
                            assignments.remove(at: index)
                            showingEditSheet = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Header Stats

    private var headerStatsView: some View {
        VStack(spacing: 16) {
            // Summary Cards
            HStack(spacing: 12) {
                statCard(
                    icon: "list.bullet",
                    title: "Total",
                    value: "\(assignments.count)",
                    color: course.color
                )

                statCard(
                    icon: "percent",
                    title: "Weight",
                    value: String(format: "%.0f%%", totalWeight),
                    color: totalWeightColor
                )

                statCard(
                    icon: "calendar",
                    title: "Dated",
                    value: "\(assignmentsWithDates)",
                    color: .blue
                )
            }

            // Warning if weight is not 100%
            if abs(totalWeight - 100) > 1 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Total weight is \(String(format: "%.0f%%", totalWeight)). Expected 100%.")
                        .font(.custom("FormaDJRDisplay-Regular", size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }

            // Confidence Indicator
            if importData.confidence < 0.8 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("AI confidence: \(String(format: "%.0f%%", importData.confidence * 100)). Please review carefully.")
                        .font(.custom("FormaDJRDisplay-Regular", size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    private func statCard(icon: String, title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)

            Text(value)
                .font(.custom("FormaDJRDisplay-Bold", size: 18))
                .foregroundColor(.primary)

            Text(title)
                .font(.custom("FormaDJRDisplay-Regular", size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search assignments...", text: $searchText)
                .font(.custom("FormaDJRDisplay-Regular", size: 15))

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Assignments List

    private var assignmentsList: some View {
        List {
            ForEach(Array(filteredAssignments.enumerated()), id: \.element.id) { index, assignment in
                assignmentRow(assignment, at: actualIndex(for: assignment))
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    private func assignmentRow(_ assignment: AIAssignmentItem, at index: Int) -> some View {
        Button(action: {
            editingAssignment = assignment
            editingIndex = index
            showingEditSheet = true

            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }) {
            HStack(spacing: 12) {
                // Category Icon
                ZStack {
                    Circle()
                        .fill(Color(hex: assignment.category.color)?.opacity(0.2) ?? course.color.opacity(0.2))
                        .frame(width: 44, height: 44)

                    Image(systemName: assignment.category.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: assignment.category.color) ?? course.color)
                }

                // Assignment Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(assignment.name)
                        .font(.custom("FormaDJRDisplay-Medium", size: 15))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 12) {
                        // Category
                        Label(assignment.category.displayName, systemImage: "tag")
                            .font(.custom("FormaDJRDisplay-Regular", size: 12))
                            .foregroundColor(.secondary)

                        // Weight
                        if let weight = assignment.weight {
                            Label("\(Int(weight * 100))%", systemImage: "chart.bar")
                                .font(.custom("FormaDJRDisplay-Regular", size: 12))
                                .foregroundColor(.secondary)
                        }

                        // Due Date
                        if let dueDate = assignment.dueDate {
                            Label(formatDate(dueDate), systemImage: "calendar")
                                .font(.custom("FormaDJRDisplay-Regular", size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    // Missing Fields Warning
                    if assignment.weight == nil || assignment.dueDate == nil {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Missing: \(missingFieldsText(for: assignment))")
                                .font(.custom("FormaDJRDisplay-Regular", size: 11))
                        }
                        .foregroundColor(.orange)
                    }
                }

                Spacer()

                // Edit Indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No assignments found")
                .font(.custom("FormaDJRDisplay-Medium", size: 18))
                .foregroundColor(.primary)

            Text("Try adjusting your search")
                .font(.custom("FormaDJRDisplay-Regular", size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Import Button

    private var importButtonView: some View {
        Button(action: {
            importAssignments()
        }) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                Text("Import \(assignments.count) Assignment\(assignments.count == 1 ? "" : "s")")
                    .font(.custom("FormaDJRDisplay-Medium", size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [course.color, course.color.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: course.color.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(assignments.isEmpty)
        .opacity(assignments.isEmpty ? 0.5 : 1.0)
    }

    // MARK: - Helper Properties

    private var filteredAssignments: [AIAssignmentItem] {
        if searchText.isEmpty {
            return assignments
        }
        return assignments.filter { assignment in
            assignment.name.localizedCaseInsensitiveContains(searchText) ||
            assignment.category.displayName.localizedCaseInsensitiveContains(searchText) ||
            assignment.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var totalWeight: Double {
        assignments.compactMap { $0.weight }.reduce(0, +) * 100
    }

    private var totalWeightColor: Color {
        let diff = abs(totalWeight - 100)
        if diff < 1 {
            return .green
        } else if diff < 10 {
            return .orange
        } else {
            return .red
        }
    }

    private var assignmentsWithDates: Int {
        assignments.filter { $0.dueDate != nil }.count
    }

    private func actualIndex(for assignment: AIAssignmentItem) -> Int {
        assignments.firstIndex(where: { $0.id == assignment.id }) ?? 0
    }

    private func missingFieldsText(for assignment: AIAssignmentItem) -> String {
        var missing: [String] = []
        if assignment.weight == nil { missing.append("weight") }
        if assignment.dueDate == nil { missing.append("date") }
        return missing.joined(separator: ", ")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: - Import Logic

    private func importAssignments() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Convert AIAssignmentItems to Assignments
        let convertedAssignments = assignments.map { aiItem -> Assignment in
            Assignment(
                courseId: course.id,
                name: aiItem.name,
                grade: "",
                weight: aiItem.weight != nil ? String(format: "%.1f", aiItem.weight! * 100) : "",
                notes: aiItem.notes,
                dueDate: aiItem.dueDate
            )
        }

        onImport(convertedAssignments)

        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)

        dismiss()
    }
}

// MARK: - Assignment Edit Sheet

struct AssignmentEditSheet: View {
    @State var assignment: AIAssignmentItem
    let courseColor: Color
    let onSave: (AIAssignmentItem) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Assignment Details") {
                    TextField("Name", text: $assignment.name)
                        .font(.custom("FormaDJRDisplay-Regular", size: 15))

                    Picker("Category", selection: $assignment.category) {
                        ForEach(AssignmentCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .font(.custom("FormaDJRDisplay-Regular", size: 15))
                }

                Section("Grading") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0", value: Binding(
                            get: { assignment.weight != nil ? assignment.weight! * 100 : 0 },
                            set: { assignment.weight = $0 > 0 ? $0 / 100 : nil }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .font(.custom("FormaDJRDisplay-Regular", size: 15))
                        Text("%")
                            .foregroundColor(.secondary)
                    }
                }

                Section("Due Date") {
                    Toggle("Has due date", isOn: Binding(
                        get: { assignment.dueDate != nil },
                        set: { if $0 { assignment.dueDate = Date() } else { assignment.dueDate = nil } }
                    ))

                    if assignment.dueDate != nil {
                        DatePicker(
                            "Date",
                            selection: Binding(
                                get: { assignment.dueDate ?? Date() },
                                set: { assignment.dueDate = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                }

                Section("Notes") {
                    TextEditor(text: $assignment.notes)
                        .font(.custom("FormaDJRDisplay-Regular", size: 15))
                        .frame(height: 100)
                }

                Section {
                    Button(role: .destructive, action: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        onDelete()
                    }) {
                        HStack {
                            Spacer()
                            Label("Delete Assignment", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.custom("FormaDJRDisplay-Regular", size: 16))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        onSave(assignment)
                    }
                    .font(.custom("FormaDJRDisplay-Medium", size: 16))
                    .disabled(assignment.name.isEmpty)
                }
            }
        }
    }
}
