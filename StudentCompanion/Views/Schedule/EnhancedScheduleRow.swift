import SwiftUI

struct EnhancedScheduleRow: View {
    let item: ScheduleItem
    let date: Date
    let scheduleID: UUID
    @EnvironmentObject var scheduleManager: ScheduleManager
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.title)
                    .font(.headline)
                Text("\(item.startTime.formatted(date: .omitted, time: .shortened)) - \(item.endTime.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if !item.location.isEmpty {
                    Text(item.location)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding()
        .background(item.color.opacity(0.2))
        .cornerRadius(10)
    }
}