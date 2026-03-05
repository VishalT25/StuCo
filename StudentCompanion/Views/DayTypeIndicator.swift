import SwiftUI

struct DayTypeIndicator: View {
    let schedule: ScheduleCollection
    let date: Date
    @EnvironmentObject var themeManager: ThemeManager
    
    private var breakInfo: AcademicBreak? {
        schedule.academicCalendar?.breakForDate(date)
    }
    
    var body: some View {
        Group {
            if let breakInfo = breakInfo {
                breakDayView(break: breakInfo)
            } else {
                traditionalDayView
            }
        }
    }
    
    @ViewBuilder
    private func breakDayView(break: AcademicBreak) -> some View {
        HStack(spacing: 12) {
            Image(systemName: `break`.type.icon)
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(`break`.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(`break`.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("BREAK")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.orange.opacity(0.2))
                .foregroundColor(.orange)
                .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var traditionalDayView: some View {
        HStack(spacing: 12) {
            Image(systemName: schedule.scheduleType == .rotating ? "repeat" : "calendar")
                .font(.title2)
                .foregroundColor(themeManager.currentTheme.primaryColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(longDayName(from: date))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                if schedule.scheduleType == .rotating {
                    Text(rotatingDayLabel(for: date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Weekly Schedule")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if schedule.scheduleType == .rotating {
                Text(rotatingDayShort(for: date))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.15))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func longDayName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func rotatingDayLabel(for date: Date) -> String {
        let d = Calendar.current.component(.day, from: date)
        return d % 2 == 1 ? "Day 1 (Odd dates)" : "Day 2 (Even dates)"
    }
    
    private func rotatingDayShort(for date: Date) -> String {
        let d = Calendar.current.component(.day, from: date)
        return d % 2 == 1 ? "DAY 1" : "DAY 2"
    }
}

// Compact version for smaller spaces
struct CompactDayTypeIndicator: View {
    let schedule: ScheduleCollection
    let date: Date
    @EnvironmentObject var themeManager: ThemeManager
    
    private var isBreakDay: Bool {
        schedule.academicCalendar?.isBreakDay(date) ?? false
    }
    
    var body: some View {
        Group {
            if isBreakDay {
                Label("Break", systemImage: "sun.max.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                EmptyView()
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        DayTypeIndicator(
            schedule: ScheduleCollection(
                name: "Test Schedule",
                semester: "Fall 2024"
            ),
            date: Date()
        )
        .environmentObject(ThemeManager())
        
        CompactDayTypeIndicator(
            schedule: ScheduleCollection(
                name: "Test Schedule", 
                semester: "Fall 2024"
            ),
            date: Date()
        )
        .environmentObject(ThemeManager())
    }
    .padding()
}