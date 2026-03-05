import Foundation
import WidgetKit

struct WidgetScheduleEventDTO: Codable, Hashable {
    var id: String
    var title: String
    var location: String?
    var startDate: Date
    var endDate: Date
}

struct WidgetScheduleSnapshotDTO: Codable {
    var generatedAt: Date
    var day: Date
    var events: [WidgetScheduleEventDTO]
}

enum ScheduleWidgetBridge {
    // Change this to match your App Group ID in Signing & Capabilities
    private static let appGroupCandidates = [
        "group.com.vishal.StuCo",
    ]
    private static let snapshotKey = "ScheduleWidgetSnapshot"

    private static func sharedDefaults() -> UserDefaults? {
        for id in appGroupCandidates {
            if let ud = UserDefaults(suiteName: id) {
                return ud
            }
        }
        return nil
    }

    @MainActor
    static func pushTodaySnapshot(scheduleManager: ScheduleManager) {
        guard let active = scheduleManager.activeSchedule else {
            return
        }

        let today = Date()
        let cal = Calendar.current

        // Gather today's schedule items
        let items = active.getScheduleItems(for: today)

        func absoluteDate(from timeOnly: Date, ref: Date) -> Date {
            let comps = cal.dateComponents([.hour, .minute, .second], from: timeOnly)
            return cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: comps.second ?? 0, of: ref) ?? ref
        }

        let events: [WidgetScheduleEventDTO] = items.map { item in
            let start = absoluteDate(from: item.startTime, ref: today)
            let end = absoluteDate(from: item.endTime, ref: today)
            return WidgetScheduleEventDTO(
                id: item.id.uuidString,
                title: item.title,
                location: item.location.isEmpty ? nil : item.location,
                startDate: start,
                endDate: end
            )
        }
        .sorted { $0.startDate < $1.startDate }

        let snapshot = WidgetScheduleSnapshotDTO(
            generatedAt: Date(),
            day: cal.startOfDay(for: today),
            events: events
        )

        guard let data = try? JSONEncoder().encode(snapshot),
              let ud = sharedDefaults() else {
            return
        }
        ud.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func readSnapshot() -> WidgetScheduleSnapshotDTO? {
        guard let ud = sharedDefaults(),
              let data = ud.data(forKey: snapshotKey),
              let snapshot = try? JSONDecoder().decode(WidgetScheduleSnapshotDTO.self, from: data) else {
            return nil
        }
        return snapshot
    }
}
