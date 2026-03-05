import SwiftUI

struct AcademicCalendarSelectionView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    let schedule: ScheduleCollection
    @State private var showingCreateCalendar = false
    @State private var pulseAnimation: Double = 1.0
    
    private var availableCalendars: [AcademicCalendar] {
        academicCalendarManager.academicCalendars.sorted { calendar1, calendar2 in
            calendar1.startDate > calendar2.startDate
        }
    }
    
    private var currentlySelectedCalendar: AcademicCalendar? {
        guard let calendarID = schedule.academicCalendarID else { return nil }
        return academicCalendarManager.calendar(withID: calendarID)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navigationHeader
                
                if availableCalendars.isEmpty {
                    emptyStateView
                } else {
                    calendarsListView
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .onAppear {
                startAnimations()
            }
        }
        .sheet(isPresented: $showingCreateCalendar) {
            CreateAcademicCalendarView()
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.08
        }
    }
    
    private var navigationHeader: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .font(.forma(.callout, weight: .semibold))
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Select Academic Calendar")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    showingCreateCalendar = true
                } label: {
                    Image(systemName: "plus")
                        .font(.forma(.callout, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
            }
            
            // Schedule Info
            VStack(spacing: 6) {
                Text("For Schedule")
                    .font(.forma(.caption, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                Text(schedule.displayName)
                    .font(.forma(.subheadline, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let currentCalendar = currentlySelectedCalendar {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.forma(.caption))
                            .foregroundColor(.green)
                        
                        Text("Currently using: \(currentCalendar.name)")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.forma(.caption))
                            .foregroundColor(.orange)
                        
                        Text("No academic calendar selected")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(
            .regularMaterial,
            in: Rectangle()
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.1))
                .frame(height: 0.5)
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 32) {
                // Animated Icon
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.1 - Double(index) * 0.03),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80 + CGFloat(index * 30)
                                )
                            )
                            .frame(width: 160 + CGFloat(index * 60), height: 160 + CGFloat(index * 60))
                            .scaleEffect(pulseAnimation + Double(index) * 0.05)
                    }
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .shadow(
                                color: themeManager.currentTheme.primaryColor.opacity(0.3),
                                radius: 20, x: 0, y: 10
                            )
                        
                        Image(systemName: "calendar.badge.plus")
                            .font(.forma(.largeTitle, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Content
                VStack(spacing: 16) {
                    Text("No Academic Calendars")
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Create your first academic calendar to manage semester dates, breaks, and holidays for this schedule.")
                        .font(.forma(.body))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Action Button
                Button {
                    showingCreateCalendar = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.title3, weight: .bold))
                        
                        Text("Create Academic Calendar")
                            .font(.forma(.headline, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(
                                color: themeManager.currentTheme.primaryColor.opacity(0.4),
                                radius: 16, x: 0, y: 8
                            )
                    )
                }
                .buttonStyle(EventsBounceButtonStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    
    private var calendarsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(availableCalendars) { calendar in
                    CalendarSelectionCardView(
                        calendar: calendar,
                        isSelected: calendar.id == schedule.academicCalendarID,
                        onSelect: {
                            selectCalendar(calendar)
                        }
                    )
                    .environmentObject(themeManager)
                }
                
                // Option to create new calendar
                Button {
                    showingCreateCalendar = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.forma(.title2))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Create New Calendar")
                                .font(.forma(.callout, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Add a new academic calendar")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.forma(.caption, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 2)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.regularMaterial)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    private func selectCalendar(_ calendar: AcademicCalendar) {
        // Update the schedule's academic calendar ID
        if let scheduleIndex = scheduleManager.scheduleCollections.firstIndex(where: { $0.id == schedule.id }) {
            scheduleManager.scheduleCollections[scheduleIndex].academicCalendarID = calendar.id
            scheduleManager.scheduleCollections[scheduleIndex].lastModified = Date()
            
            // Update the schedule in the manager
            scheduleManager.updateSchedule(scheduleManager.scheduleCollections[scheduleIndex])
            
            dismiss()
        }
    }
}

struct CalendarSelectionCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.colorScheme) var colorScheme
    
    let calendar: AcademicCalendar
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var showingEditCalendar = false
    @State private var showingManageBreaks = false
    @State private var showingDeleteAlert = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator
            Button(action: onSelect) {
                ZStack {
                    Circle()
                        .fill(isSelected ? themeManager.currentTheme.primaryColor : Color(.systemGray5))
                        .frame(width: 24, height: 24)
                    
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.forma(.caption, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Calendar info
            Button(action: onSelect) {
                VStack(alignment: .leading, spacing: 8) {
                    // Top row: Calendar name and year
                    HStack {
                        Text(calendar.name)
                            .font(.forma(.subheadline, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(calendar.academicYear)
                            .font(.forma(.caption, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(themeManager.currentTheme.primaryColor.opacity(0.15))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .clipShape(Capsule())
                    }
                    
                    // Date range
                    Text("\(dateFormatter.string(from: calendar.startDate)) - \(dateFormatter.string(from: calendar.endDate))")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                    
                    // Bottom row: Stats and three-dot menu
                    HStack {
                        HStack(spacing: 16) {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar.badge.minus")
                                    .font(.forma(.caption2))
                                    .foregroundColor(.secondary)
                                
                                Text("\(calendar.breaks.count) breaks")
                                    .font(.forma(.caption2, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.forma(.caption2))
                                    .foregroundColor(.secondary)
                                
                                Text(calendar.termType.rawValue.capitalized)
                                    .font(.forma(.caption2, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // Three-dot menu button moved here
                        Menu {
                            Button {
                                showingEditCalendar = true
                            } label: {
                                Label("Edit Calendar", systemImage: "pencil")
                            }
                            
                            Button {
                                showingManageBreaks = true
                            } label: {
                                Label("Manage Breaks", systemImage: "calendar.badge.checkmark")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                Label("Delete Calendar", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.forma(.subheadline, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? themeManager.currentTheme.primaryColor : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isSelected 
                        ? themeManager.currentTheme.primaryColor.opacity(0.3)
                        : themeManager.currentTheme.primaryColor.opacity(0.05),
                    radius: isSelected ? 12 : 6,
                    x: 0,
                    y: isSelected ? 8 : 3
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0,
            cornerRadius: 16
        )
        .sheet(isPresented: $showingEditCalendar) {
            AddEditAcademicCalendarView(calendar: .constant(calendar))
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingManageBreaks) {
            AcademicCalendarEditorView(academicCalendar: .constant(calendar))
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .alert("Delete Academic Calendar", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                academicCalendarManager.deleteCalendar(calendar)
            }
        } message: {
            Text("Are you sure you want to delete '\(calendar.name)'? This action cannot be undone and will affect any schedules using this calendar.")
        }
    }
}