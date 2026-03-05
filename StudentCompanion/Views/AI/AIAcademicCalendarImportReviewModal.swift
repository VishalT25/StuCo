import SwiftUI

struct AIAcademicCalendarImportReviewModal: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Binding var importData: AIAcademicCalendarImportData?
    let calendarName: String
    let academicYear: String
    let startDate: Date
    let endDate: Date

    @State private var searchText: String = ""
    @State private var showAddBreakSheet: Bool = false
    @State private var newBreakName: String = ""
    @State private var newBreakStartDate: Date = Date()
    @State private var newBreakEndDate: Date = Date()
    @State private var editingBreak: AcademicBreak?
    @State private var isEditingBreak: Bool = false

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    searchBar

                    summaryCard

                    breaksListSection
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.forma(.subheadline, weight: .semibold))
                            Text("Done")
                                .font(.forma(.subheadline, weight: .semibold))
                        }
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
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        newBreakName = ""
                        newBreakStartDate = Date()
                        newBreakEndDate = Date()
                        showAddBreakSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.forma(.subheadline, weight: .semibold))
                            Text("Add")
                                .font(.forma(.subheadline, weight: .semibold))
                        }
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
                    }
                }
            }
            .sheet(isPresented: $showAddBreakSheet) {
                addBreakSheet
                    .presentationDetents([.height(400)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isEditingBreak) {
                if let academicBreak = editingBreak {
                    EditBreakSheet(
                        break: academicBreak,
                        onSave: { updatedBreak in
                            if let index = importData?.breaks.firstIndex(where: { $0.id == updatedBreak.id }) {
                                importData?.breaks[index] = updatedBreak
                            }
                            editingBreak = nil
                            isEditingBreak = false
                        },
                        onCancel: {
                            editingBreak = nil
                            isEditingBreak = false
                        }
                    )
                    .environmentObject(themeManager)
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.secondary)

            TextField("Search breaks or dates", text: $searchText)
                .font(.forma(.body))
                .textInputAutocapitalization(.words)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                )
        )
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.forma(.title3, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("AI Import Summary")
                        .font(.forma(.headline, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Review and customize your calendar")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Divider()

            HStack(spacing: 16) {
                statPill(
                    value: academicYear,
                    label: "Academic Year",
                    icon: "graduationcap.fill",
                    color: currentTheme.primaryColor
                )

                statPill(
                    value: "\(importData?.breaks.count ?? 0)",
                    label: "Breaks",
                    icon: "minus.circle.fill",
                    color: currentTheme.secondaryColor
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.3),
                                    currentTheme.secondaryColor.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
        )
        .shadow(
            color: currentTheme.primaryColor.opacity(0.15),
            radius: 20, x: 0, y: 10
        )
    }

    private func statPill(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.forma(.caption, weight: .bold))
                    .foregroundColor(color)

                Text(value)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(label)
                .font(.forma(.caption2, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Breaks List Section

    private var breaksListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Academic Breaks")
                    .font(.forma(.headline, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(filteredBreaks.count) breaks")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
            }

            LazyVStack(spacing: 12) {
                ForEach(filteredBreaks, id: \.id) { academicBreak in
                    breakRow(academicBreak)
                }
            }
        }
    }

    private func breakRow(_ academicBreak: AcademicBreak) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(academicBreak.name)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formatDateRange(academicBreak.startDate, academicBreak.endDate))
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("• \(dayCount(from: academicBreak.startDate, to: academicBreak.endDate)) days")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    editingBreak = academicBreak
                    isEditingBreak = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.forma(.caption, weight: .bold))
                        .foregroundColor(currentTheme.primaryColor)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(currentTheme.primaryColor.opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    deleteBreak(academicBreak)
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.forma(.caption, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.red)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(currentTheme.primaryColor.opacity(0.1), lineWidth: 1)
                )
        )
    }

    // MARK: - Add Break Sheet

    private var addBreakSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "minus.circle.fill")
                                .font(.forma(.subheadline))
                                .foregroundColor(currentTheme.primaryColor)

                            Text("Break Name")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        TextField("e.g., Winter Break", text: $newBreakName)
                            .textInputAutocapitalization(.words)
                            .font(.forma(.body))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(currentTheme.primaryColor)

                                Text("Start Date")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }

                            DatePicker("", selection: $newBreakStartDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(currentTheme.secondaryColor)

                                Text("End Date")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }

                            DatePicker("", selection: $newBreakEndDate, in: newBreakStartDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }
                }

                Spacer()

                Button {
                    createNewBreak()
                    showAddBreakSheet = false
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.body, weight: .semibold))

                        Text("Create Break")
                            .font(.forma(.headline, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(
                        color: currentTheme.primaryColor.opacity(0.4),
                        radius: 12, x: 0, y: 6
                    )
                }
                .disabled(newBreakName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(newBreakName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                .buttonStyle(PremiumMainButtonStyle())
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showAddBreakSheet = false
                    }
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helper Properties & Functions

    private var filteredBreaks: [AcademicBreak] {
        guard let breaks = importData?.breaks else { return [] }
        if searchText.isEmpty {
            return breaks.sorted { $0.startDate < $1.startDate }
        } else {
            let query = searchText.lowercased()
            return breaks.filter { academicBreak in
                academicBreak.name.lowercased().contains(query)
            }.sorted { $0.startDate < $1.startDate }
        }
    }

    private func deleteBreak(_ academicBreak: AcademicBreak) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            importData?.breaks.removeAll { $0.id == academicBreak.id }
        }
    }

    private func createNewBreak() {
        guard var data = importData else { return }
        let name = newBreakName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let newBreak = AcademicBreak(
            name: name,
            type: .custom,
            startDate: newBreakStartDate,
            endDate: newBreakEndDate
        )

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            data.breaks.append(newBreak)
            importData = data
        }
    }

    private func formatDateRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private func dayCount(from start: Date, to end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }
}

// MARK: - Edit Break Sheet

struct EditBreakSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let originalBreak: AcademicBreak
    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date

    let onSave: (AcademicBreak) -> Void
    let onCancel: () -> Void

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    init(break: AcademicBreak, onSave: @escaping (AcademicBreak) -> Void, onCancel: @escaping () -> Void) {
        self.originalBreak = `break`
        self._name = State(initialValue: `break`.name)
        self._startDate = State(initialValue: `break`.startDate)
        self._endDate = State(initialValue: `break`.endDate)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.forma(.subheadline))
                                .foregroundColor(currentTheme.primaryColor)

                            Text("Break Name")
                                .font(.forma(.subheadline, weight: .medium))
                                .foregroundColor(.primary)
                        }

                        TextField("Break Name", text: $name)
                            .textInputAutocapitalization(.words)
                            .font(.forma(.body))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(currentTheme.primaryColor)

                                Text("Start Date")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }

                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(currentTheme.secondaryColor)

                                Text("End Date")
                                    .font(.forma(.subheadline, weight: .medium))
                                    .foregroundColor(.primary)
                            }

                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                        }
                    }
                }

                Spacer()

                Button {
                    let updatedBreak = AcademicBreak(
                        name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: originalBreak.type,
                        startDate: startDate,
                        endDate: endDate
                    )
                    onSave(updatedBreak)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.forma(.body, weight: .semibold))

                        Text("Save Changes")
                            .font(.forma(.headline, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(
                        color: currentTheme.primaryColor.opacity(0.4),
                        radius: 12, x: 0, y: 6
                    )
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.6 : 1.0)
                .buttonStyle(PremiumMainButtonStyle())
            }
            .padding(20)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Break")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}
