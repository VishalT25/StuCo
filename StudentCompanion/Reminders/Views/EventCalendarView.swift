import SwiftUI

struct CalendarMonthView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date

    @State private var currentMonthStart: Date = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()

    private var calendar: Calendar { Calendar.current }

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        if let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: selectedDate.wrappedValue)) {
            _currentMonthStart = State(initialValue: start)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            monthGrid
        }
    }

    private var header: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonthStart = calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }

           Spacer()

            Text(monthTitle(for: currentMonthStart))
                .font(.forma(.headline, weight: .bold))
                .foregroundColor(.primary)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    currentMonthStart = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.primaryColor)
            }
        }
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        let symbols = calendar.shortWeekdaySymbols 
        return HStack {
            ForEach(0..<7, id: \.self) { idx in
                Text(symbols[idx])
                    .font(.forma(.subheadline, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let days = daysInMonth(startingAt: currentMonthStart)
        let firstWeekdayIndex = (calendar.component(.weekday, from: currentMonthStart) - calendar.firstWeekday + 7) % 7
        let totalCells = days.count + firstWeekdayIndex
        let rows = Int(ceil(Double(totalCells) / 7.0))

        return VStack(spacing: 8) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { col in
                        let index = row * 7 + col
                        if index < firstWeekdayIndex {
                            Spacer().frame(maxWidth: .infinity)
                        } else {
                            let dayIndex = index - firstWeekdayIndex
                            if dayIndex < days.count {
                                let date = days[dayIndex]
                                dayCell(for: date)
                            } else {
                                Spacer().frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEvents = !viewModel.events(for: date).isEmpty

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(maxWidth: .infinity, minHeight: 24)

                Circle()
                    .fill(isSelected ? Color.white : (hasEvents ? themeManager.currentTheme.primaryColor : Color.clear))
                    .frame(width: 5, height: 5)
                    .opacity(hasEvents ? 1.0 : 0.0)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.currentTheme.primaryColor)
                    } else if isToday {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.4), lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }

    private func monthTitle(for date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "LLLL yyyy"
        return fmt.string(from: date)
    }

    private func daysInMonth(startingAt start: Date) -> [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: start),
              let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: start))
        else { return [] }

        return range.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
    }
}