import SwiftUI

struct ScheduleAcademicCalendarView: View {
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    let schedule: ScheduleCollection
    @State private var selectedCalendarID: UUID?
    @State private var showingCreateNewCalendar = false
    
    private var currentCalendar: AcademicCalendar? {
        if let calendarID = schedule.academicCalendarID {
            return academicCalendarManager.calendar(withID: calendarID)
        } else if let legacyCalendar = schedule.academicCalendar {
            return legacyCalendar
        }
        return nil
    }
    
    var body: some View {
        NavigationView {
            Form {
                if let current = currentCalendar {
                    Section(header: Text("Current Calendar")) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(current.name)
                                    .font(.headline)
                                Text(current.academicYear)
                                    .font(.subheadline)
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                Text("\(current.breaks.count) breaks configured")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if schedule.academicCalendar != nil {
                                Text("Legacy")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                
                Section(header: Text("Available Calendars")) {
                    if academicCalendarManager.academicCalendars.isEmpty {
                        Text("No academic calendars available")
                            .foregroundColor(.secondary)
                        
                        Button("Create First Calendar") {
                            showingCreateNewCalendar = true
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    } else {
                        ForEach(academicCalendarManager.academicCalendars) { calendar in
                            Button(action: {
                                assignCalendar(calendar)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(calendar.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(calendar.academicYear)
                                            .font(.subheadline)
                                            .foregroundColor(themeManager.currentTheme.primaryColor)
                                        Text("\(calendar.breaks.count) breaks configured")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if schedule.academicCalendarID == calendar.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(themeManager.currentTheme.primaryColor)
                                    }
                                }
                            }
                        }
                    }
                    
                    Button("Create New Calendar") {
                        showingCreateNewCalendar = true
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                if currentCalendar != nil {
                    Section(header: Text("Actions")) {
                        Button("Remove Calendar from Schedule") {
                            removeCalendar()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Academic Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
        }
        .sheet(isPresented: $showingCreateNewCalendar) {
            AddEditAcademicCalendarView(calendar: .constant(nil))
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .onAppear {
            selectedCalendarID = schedule.academicCalendarID
        }
    }
    
    private func assignCalendar(_ calendar: AcademicCalendar) {
        var updatedSchedule = schedule
        updatedSchedule.academicCalendarID = calendar.id
        updatedSchedule.academicCalendar = nil // Clear legacy calendar
        scheduleManager.updateSchedule(updatedSchedule)
    }
    
    private func removeCalendar() {
        var updatedSchedule = schedule
        updatedSchedule.academicCalendarID = nil
        updatedSchedule.academicCalendar = nil
        scheduleManager.updateSchedule(updatedSchedule)
    }
}