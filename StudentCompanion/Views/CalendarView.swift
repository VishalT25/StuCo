import SwiftUI

struct CalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    @Binding var currentWeekOffset: Int
    @Binding var showingCalendarView: Bool
    let schedule: ScheduleCollection?
    
    @State private var currentMonth = Date()
    
    private var calendar: Calendar { Calendar.current }
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            monthGrid
            actionButtons
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var headerView: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                    )
            }
            
            Spacer()
            
            Text(monthTitle)
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .foregroundColor(themeManager.currentTheme.primaryColor)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                    )
            }
        }
    }
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
    
    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            // Week day headers
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { day in
                Text(day)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            
            // Calendar days
            ForEach(monthDates, id: \.self) { date in
                dayCell(for: date)
            }
        }
    }
    
    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: firstOfMonth)?.start ?? firstOfMonth
        
        var dates: [Date] = []
        var date = startOfWeek
        
        for _ in 0..<42 { // 6 weeks × 7 days
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        return dates
    }
    
    private func dayCell(for date: Date) -> some View {
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDate(date, inSameDayAs: Date())
        let hasClasses = schedule?.getScheduleItems(for: date).isEmpty == false
        
        return Button(action: { selectDate(date) }) {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(
                        isSelected ? .white :
                        isToday ? themeManager.currentTheme.primaryColor :
                        isCurrentMonth ? .primary : .secondary
                    )
                
                if hasClasses {
                    Circle()
                        .fill(isSelected ? .white : themeManager.currentTheme.primaryColor)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(
                        isSelected ? themeManager.currentTheme.primaryColor :
                        isToday ? themeManager.currentTheme.primaryColor.opacity(0.1) :
                        Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isCurrentMonth)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button("Today") {
                selectedDate = Date()
                currentMonth = Date()
                updateWeekOffset()
                showingCalendarView = false
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
            )
            .foregroundColor(themeManager.currentTheme.primaryColor)
            
            Spacer()
            
            Button("Done") {
                showingCalendarView = false
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.currentTheme.primaryColor)
            )
            .foregroundColor(.white)
        }
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func selectDate(_ date: Date) {
        selectedDate = date
        currentMonth = date
        updateWeekOffset()
        showingCalendarView = false
    }
    
    private func updateWeekOffset() {
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate which week the selected date is in relative to today's week
        guard let todayWeekInterval = calendar.dateInterval(of: .weekOfYear, for: today),
              let selectedWeekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            currentWeekOffset = 0
            return
        }
        
        let weeksDifference = calendar.dateComponents([.weekOfYear], from: todayWeekInterval.start, to: selectedWeekInterval.start).weekOfYear ?? 0
        currentWeekOffset = weeksDifference
    }
}