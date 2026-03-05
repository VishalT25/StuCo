import SwiftUI

struct EmptyDayView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    
    let date: Date
    let schedule: ScheduleCollection
    
    // MARK: - Break Detection
    private var academicCalendar: AcademicCalendar? {
        scheduleManager.getAcademicCalendar(for: schedule, from: academicCalendarManager)
    }
    
    private var isBreakDay: Bool {
        guard let calendar = academicCalendar else { 
            return false 
        }
        let dateOnly = Calendar.current.startOfDay(for: date)
        
        for breakItem in calendar.breaks {
            let breakStart = Calendar.current.startOfDay(for: breakItem.startDate)
            let breakEnd = Calendar.current.startOfDay(for: breakItem.endDate)
            
            if dateOnly >= breakStart && dateOnly <= breakEnd {
                return true
            }
        }
        
        return false
    }
    
    private var breakInfo: AcademicBreak? {
        guard let calendar = academicCalendar else { 
            return nil 
        }
        return calendar.breakForDate(date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Beautiful illustration with break-specific styling
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                illustrationColor.opacity(0.2),
                                illustrationColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: illustrationIcon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(illustrationColor)
            }
            
            VStack(spacing: 12) {
                Text(emptyMessage)
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                Text(emptySubtitle)
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            // Enhanced break information or general free day message
            if isBreakDay, let breakInfo = breakInfo {
                breakInfoCard(breakInfo)
            } else if !isWeekend && isToday {
                generalFreeTimeCard
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Break Information Card
    private func breakInfoCard(_ breakInfo: AcademicBreak) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: breakInfo.type.icon)
                    .font(.forma(.title3, weight: .semibold))
                    .foregroundColor(breakInfo.type.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(breakInfo.name)
                        .font(.forma(.subheadline, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(breakInfo.type.displayName)
                        .font(.forma(.caption, weight: .medium))
                        .foregroundColor(breakInfo.type.color)
                }
                
                Spacer()
                
                Text(formatBreakDuration(breakInfo))
                    .font(.forma(.caption2, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            
            if !breakInfo.description.isEmpty {
                HStack {
                    Text(breakInfo.description)
                        .font(.forma(.caption))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(breakInfo.type.color.opacity(0.3), lineWidth: 1)
                )
        )
        .shadow(
            color: breakInfo.type.color.opacity(0.1),
            radius: 8,
            x: 0,
            y: 4
        )
    }
    
    // MARK: - General Free Time Card
    private var generalFreeTimeCard: some View {
        VStack(spacing: 8) {
            Text("Perfect time to relax! ✨")
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Text("Catch up on assignments or enjoy some free time.")
                .font(.forma(.caption))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(themeManager.currentTheme.primaryColor.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Methods
    private func formatBreakDuration(_ breakInfo: AcademicBreak) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        
        if Calendar.current.isDate(breakInfo.startDate, inSameDayAs: breakInfo.endDate) {
            return dateFormatter.string(from: breakInfo.startDate)
        } else {
            return "\(dateFormatter.string(from: breakInfo.startDate)) -\n\(dateFormatter.string(from: breakInfo.endDate))"
        }
    }
    
    // MARK: - Dynamic Content Based on Break Status
    private var emptyMessage: String {
        if isBreakDay, let breakInfo = breakInfo {
            return "Academic Break"
        } else if isWeekend {
            return "Weekend Vibes"
        } else if isToday {
            return "No Classes Today"
        } else {
            return "Free \(dayName)"
        }
    }
    
    private var emptySubtitle: String {
        if isBreakDay, let breakInfo = breakInfo {
            return "No classes scheduled during \(breakInfo.name.lowercased())"
        } else if isWeekend {
            return "Time to relax and recharge for the week ahead"
        } else if isToday {
            return "You have a completely free day ahead"
        } else {
            return "This day is free from scheduled classes"
        }
    }
    
    private var illustrationIcon: String {
        if isBreakDay, let breakInfo = breakInfo {
            return breakInfo.type.icon
        } else if isWeekend {
            return "sun.max.fill"
        } else if isToday {
            return "hand.wave.fill"
        } else {
            return "calendar"
        }
    }
    
    private var illustrationColor: Color {
        if isBreakDay, let breakInfo = breakInfo {
            return breakInfo.type.color
        } else if isWeekend {
            return .orange
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else {
            return themeManager.currentTheme.secondaryColor
        }
    }
}