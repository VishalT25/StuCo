import SwiftUI

struct AcademicCalendarManagementView: View {
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var showingCreateCalendar = false
    @State private var showingDeleteAlert = false
    @State private var calendarToDelete: AcademicCalendar?
    @State private var selectedCalendar: AcademicCalendar?
    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    
    private var sortedCalendars: [AcademicCalendar] {
        academicCalendarManager.academicCalendars.sorted { calendar1, calendar2 in
            // Sort by start date, most recent first
            calendar1.startDate > calendar2.startDate
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                navigationHeader
                
                if sortedCalendars.isEmpty {
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
                .environmentObject(calendarSyncManager)
        }
        .sheet(item: $selectedCalendar) { calendar in
            EditAcademicCalendarView(calendar: calendar)
                .environmentObject(academicCalendarManager)
                .environmentObject(themeManager)
        }
        .alert("Delete Academic Calendar", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                calendarToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let calendar = calendarToDelete {
                    deleteCalendar(calendar)
                }
            }
        } message: {
            if let calendar = calendarToDelete {
                let usageCount = getUsageCount(for: calendar)
                if usageCount > 0 {
                    Text("This calendar is used by \(usageCount) schedule\(usageCount == 1 ? "" : "s"). Deleting it may affect your course schedules.")
                } else {
                    Text("Are you sure you want to delete '\(calendar.name)'? This action cannot be undone.")
                }
            }
        }
    }
    
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.08
        }
        
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }
    }
    
    private var navigationHeader: some View {
        HStack {
            Button("Done") {
                dismiss()
            }
            .font(.forma(.callout, weight: .semibold))
            .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Spacer()
            
            Text("Academic Calendars")
                .font(.forma(.title2, weight: .bold))
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
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 24)
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
                        
                        Image(systemName: "calendar.badge.clock")
                            .font(.forma(.largeTitle, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Content
                VStack(spacing: 16) {
                    Text("No Academic Calendars")
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Create academic calendars to manage semester dates, breaks, and holidays across all your course schedules.")
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
                ForEach(sortedCalendars) { calendar in
                    AcademicCalendarCardView(
                        calendar: calendar,
                        usageCount: getUsageCount(for: calendar),
                        onEdit: {
                            selectedCalendar = calendar
                        },
                        onDelete: {
                            calendarToDelete = calendar
                            showingDeleteAlert = true
                        }
                    )
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }
    
    private func getUsageCount(for calendar: AcademicCalendar) -> Int {
        scheduleManager.scheduleCollections.filter { $0.academicCalendarID == calendar.id }.count
    }
    
    private func deleteCalendar(_ calendar: AcademicCalendar) {
        academicCalendarManager.deleteCalendar(calendar)
        calendarToDelete = nil
    }
}

struct AcademicCalendarCardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) var colorScheme
    
    let calendar: AcademicCalendar
    let usageCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    private var upcomingBreaks: [AcademicBreak] {
        calendar.breaks
            .filter { $0.endDate >= Date() }
            .sorted { $0.startDate < $1.startDate }
            .prefix(3)
            .map { $0 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calendar.name)
                        .font(.forma(.title2, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        Text(calendar.academicYear)
                            .font(.forma(.subheadline, weight: .semibold))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        
                        if usageCount > 0 {
                            Text("•")
                                .font(.forma(.caption))
                                .foregroundColor(.secondary)
                            
                            Text("\(usageCount) schedule\(usageCount == 1 ? "" : "s")")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Text("\(dateFormatter.string(from: calendar.startDate)) - \(dateFormatter.string(from: calendar.endDate))")
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button("Edit Calendar", systemImage: "pencil") {
                        onEdit()
                    }
                    
                    Divider()
                    
                    Button("Delete Calendar", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.forma(.title3))
                        .foregroundColor(.secondary)
                }
            }
            
            // Stats
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(calendar.breaks.count)")
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    
                    Text("Breaks")
                        .font(.forma(.caption2, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(calendar.termType.rawValue.capitalized)
                        .font(.forma(.title3, weight: .bold))
                        .foregroundColor(themeManager.currentTheme.secondaryColor)
                    
                    Text("System")
                        .font(.forma(.caption2, weight: .medium))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                if usageCount > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(usageCount)")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(.green)
                        
                        Text("In Use")
                            .font(.forma(.caption2, weight: .medium))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                    }
                }
                
                Spacer()
            }
            
            // Upcoming Breaks
            if !upcomingBreaks.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upcoming Breaks")
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 8) {
                        ForEach(upcomingBreaks, id: \.id) { break_ in
                            HStack(spacing: 12) {
                                Image(systemName: break_.type.icon)
                                    .font(.forma(.subheadline))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(break_.name)
                                        .font(.forma(.subheadline, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    Text(dateFormatter.string(from: break_.startDate))
                                        .font(.forma(.caption))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(break_.type.displayName)
                                    .font(.forma(.caption2, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        themeManager.currentTheme.primaryColor.opacity(0.15),
                                        in: Capsule()
                                    )
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                            }
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(
                    color: themeManager.currentTheme.primaryColor.opacity(0.08),
                    radius: 12, x: 0, y: 6
                )
        )
        .adaptiveCardDarkModeHue(
            using: themeManager.currentTheme,
            intensity: colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0,
            cornerRadius: 20
        )
    }
}