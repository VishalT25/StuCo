import SwiftUI

struct WeekDayCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var academicCalendarManager: AcademicCalendarManager
    @Environment(\.colorScheme) var colorScheme
    
    let date: Date
    let dayOfWeek: DayOfWeek
    let classCount: Int
    let isSelected: Bool
    let isToday: Bool
    let schedule: ScheduleCollection
    
    @State private var shimmerPhase: CGFloat = 0
    @State private var pulseScale: CGFloat = 1
    
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
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var dayAbbreviation: String {
        dayOfWeek.short
    }
    
    var body: some View {
        VStack(spacing: 4) {
            // Day abbreviation - clean and simple
            Text(dayAbbreviation)
                .font(.system(.caption2, weight: .medium))
                .foregroundColor(dayTextColor.opacity(0.7))
                .scaleEffect(0.9)
            
            // Day number - clean with subtle break indication
            Text(dayNumber)
                .font(.system(.callout, weight: .bold))
                .foregroundColor(numberTextColor)
                .scaleEffect(pulseScale)
            
            // Bottom indicator - elegant and minimal
            bottomIndicator
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderGradient, lineWidth: borderWidth)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0, y: shadowRadius / 2
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isSelected)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isToday)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isBreakDay)
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Bottom Indicator (Elegant Break/Class Display)
    @ViewBuilder
    private var bottomIndicator: some View {
        if isBreakDay {
            // Empty space to maintain layout for break days
            Circle()
                .fill(Color.clear)
                .frame(width: 14, height: 14)
        } else if classCount > 0 {
            // Original class count badge - unchanged
            Text("\(classCount)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(badgeTextColor)
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(badgeBackgroundGradient)
                )
        } else {
            // Empty space to maintain layout
            Circle()
                .fill(Color.clear)
                .frame(width: 14, height: 14)
        }
    }
    
    // MARK: - Background View (Enhanced for Breaks)
    @ViewBuilder
    private var backgroundView: some View {
        if isBreakDay, let breakInfo = breakInfo {
            // Elegant break background - very subtle
            ZStack {
                // Base subtle tint
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                breakInfo.type.color.opacity(isSelected ? 0.15 : 0.08),
                                breakInfo.type.color.opacity(isSelected ? 0.12 : 0.06),
                                breakInfo.type.color.opacity(isSelected ? 0.08 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // Subtle animated overlay for selected break days
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: pulseScale)
                }
            }
        } else {
            // Original background for non-break days
            RoundedRectangle(cornerRadius: 12)
                .fill(originalBackgroundGradient)
        }
    }
    
    // MARK: - Original Background Gradient
    private var originalBackgroundGradient: LinearGradient {
        if isSelected {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.2),
                    themeManager.currentTheme.primaryColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isToday {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.1),
                    themeManager.currentTheme.primaryColor.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [.clear, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Border Properties
    private var borderGradient: LinearGradient {
        if isBreakDay, let breakInfo = breakInfo {
            return LinearGradient(
                colors: [
                    breakInfo.type.color.opacity(isSelected ? 0.6 : 0.4),
                    breakInfo.type.color.opacity(isSelected ? 0.5 : 0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isSelected {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.primaryColor.opacity(0.7)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isToday {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.5),
                    themeManager.currentTheme.primaryColor.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    Color(.systemGray5),
                    Color(.systemGray6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
    
    private var borderWidth: CGFloat {
        if isBreakDay && isSelected {
            return 2.5
        } else if isSelected {
            return 2
        } else if isBreakDay {
            return 1.5
        } else {
            return 1
        }
    }
    
    // MARK: - Text Colors (Refined)
    private var dayTextColor: Color {
        if isBreakDay, let breakInfo = breakInfo {
            return breakInfo.type.color.opacity(0.9)
        } else if isSelected {
            return themeManager.currentTheme.primaryColor
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else {
            return .primary
        }
    }
    
    private var numberTextColor: Color {
        if isBreakDay, let breakInfo = breakInfo {
            return breakInfo.type.color
        } else if isSelected {
            return themeManager.currentTheme.primaryColor
        } else if isToday {
            return themeManager.currentTheme.primaryColor
        } else {
            return .primary
        }
    }
    
    // MARK: - Badge Properties (Unchanged)
    private var badgeBackgroundGradient: LinearGradient {
        if isSelected || isToday {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.primaryColor.opacity(0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.3),
                    themeManager.currentTheme.primaryColor.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var badgeTextColor: Color {
        if isSelected || isToday {
            return .white
        } else {
            return themeManager.currentTheme.primaryColor
        }
    }
    
    // MARK: - Shadow Properties (Enhanced for Breaks)
    private var shadowColor: Color {
        if isBreakDay, let breakInfo = breakInfo {
            return breakInfo.type.color.opacity(isSelected ? 0.25 : 0.15)
        } else if isSelected {
            return themeManager.currentTheme.primaryColor.opacity(0.2)
        } else if isToday {
            return themeManager.currentTheme.primaryColor.opacity(0.1)
        } else {
            return Color.black.opacity(0.02)
        }
    }
    
    private var shadowRadius: CGFloat {
        if isBreakDay && isSelected {
            return 14
        } else if isSelected {
            return 12
        } else if isBreakDay {
            return 8
        } else if isToday {
            return 6
        } else {
            return 3
        }
    }
    
    // MARK: - Animations
    private func startAnimations() {
        // Subtle pulse for selected break days
        if isBreakDay && isSelected {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.02
            }
        }
    }
}