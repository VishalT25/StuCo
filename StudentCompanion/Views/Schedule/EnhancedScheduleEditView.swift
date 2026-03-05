import SwiftUI

struct EnhancedScheduleEditView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let scheduleItem: ScheduleItem?
    let scheduleID: UUID
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    @State private var selectedColor: Color = .blue
    @State private var reminderTime: ReminderTime = .none
    @State private var isLiveActivityEnabled = true
    @State private var showingDeleteAlert = false
    
    // Day selection
    @State private var selectedDays: Set<DayOfWeek> = []
    
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var showAuthAlert = false
    
    var isEditing: Bool { scheduleItem != nil }
    
    init(scheduleItem: ScheduleItem?, scheduleID: UUID) {
        self.scheduleItem = scheduleItem
        self.scheduleID = scheduleID
        
        if let item = scheduleItem {
            _title = State(initialValue: item.title)
            _startTime = State(initialValue: item.startTime)
            _endTime = State(initialValue: item.endTime)
            _selectedColor = State(initialValue: item.color)
            _reminderTime = State(initialValue: item.reminderTime)
            _isLiveActivityEnabled = State(initialValue: item.isLiveActivityEnabled)
            _selectedDays = State(initialValue: Set(item.daysOfWeek))
        } else {
            // Set reasonable default times for new schedule items
            let calendar = Calendar.current
            let now = Date()
            
            // Default start time: 9:00 AM
            let defaultStartTime = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: now) ?? now
            // Default end time: 10:00 AM
            let defaultEndTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now) ?? now.addingTimeInterval(3600)
            
            _startTime = State(initialValue: defaultStartTime)
            _endTime = State(initialValue: defaultEndTime)
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Class Details Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Class Details", icon: "book.fill")
                        
                        VStack(spacing: 12) {
                            CustomTextField(
                                title: "Class Name",
                                placeholder: "e.g., Introduction to Psychology",
                                text: $title,
                                icon: "text.alignleft"
                            )
                            
                            TimePickerRow(title: "Start Time", time: $startTime)
                            TimePickerRow(title: "End Time", time: $endTime)
                            
                            ColorPickerRow(title: "Class Color", color: $selectedColor)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                    }
                    
                    // Schedule Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Schedule", icon: "calendar")
                        
                        DaySelectionGrid(selectedDays: $selectedDays)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                            )
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Preferences", icon: "gear")
                        
                        VStack(spacing: 16) {
                            ReminderPickerRow(reminderTime: $reminderTime)
                            
                            ToggleRow(
                                title: "Live Activity",
                                subtitle: "Show in Dynamic Island & Lock Screen",
                                isOn: $isLiveActivityEnabled,
                                color: themeManager.currentTheme.primaryColor
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                        )
                    }

                    // Delete Button (if editing)
                    if isEditing {
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete Class")
                            }
                            .font(.headline.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .cornerRadius(16)
                        }
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditing ? "Edit Class" : "Add Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Save" : "Add") {
                        saveScheduleItem()
                    }
                    .disabled(!isValidInput)
                    .foregroundColor(isValidInput ? themeManager.currentTheme.primaryColor : .secondary)
                    .fontWeight(.semibold)
                }
            }
        }
        .alert("Delete Class", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let item = scheduleItem {
                    scheduleManager.deleteScheduleItem(item, from: scheduleID)
                }
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this class? This action cannot be undone.")
        }
        
        .alert("Sign in required", isPresented: $showAuthAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please sign in to add a new class.")
        }
    }
    
    private var isValidInput: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedDays.isEmpty &&
        endTime > startTime
    }
    
    private func saveScheduleItem() {
        let normalizedStartTime = normalizeTimeToToday(startTime)
        let normalizedEndTime = normalizeTimeToToday(endTime)
        
        if let existingItem = scheduleItem {
            var updatedItem = existingItem
            updatedItem.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            updatedItem.startTime = normalizedStartTime
            updatedItem.endTime = normalizedEndTime
            updatedItem.daysOfWeek = Array(selectedDays)
            updatedItem.color = selectedColor
            updatedItem.reminderTime = reminderTime
            updatedItem.isLiveActivityEnabled = isLiveActivityEnabled
            scheduleManager.updateScheduleItem(updatedItem, in: scheduleID)
        } else {
            guard supabaseService.isAuthenticated else {
                showAuthAlert = true
                return
            }
            let newItem = ScheduleItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                startTime: normalizedStartTime,
                endTime: normalizedEndTime,
                daysOfWeek: Array(selectedDays),
                location: "",
                instructor: "",
                color: selectedColor,
                isLiveActivityEnabled: isLiveActivityEnabled,
                reminderTime: reminderTime
            )
            scheduleManager.addScheduleItem(newItem, to: scheduleID)
        }
        
        dismiss()
    }
    
    // Helper function to normalize time to today's date with the selected time
    private func normalizeTimeToToday(_ time: Date) -> Date {
        let calendar = Calendar.current
        let now = Date()
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        
        return calendar.date(bySettingHour: timeComponents.hour ?? 0, 
                           minute: timeComponents.minute ?? 0, 
                           second: timeComponents.second ?? 0, 
                           of: now) ?? time
    }
}