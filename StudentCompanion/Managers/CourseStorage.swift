import Foundation

struct CourseStorage {
    static let key = "gpaCourses"
    
    private static var debounceTimer: Timer?

    static func save(_ courses: [Course]) {
        guard let data = try? JSONEncoder().encode(courses) else { return }

        UserDefaults.standard.set(data, forKey: key)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastGradeUpdate")

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false) { _ in
            print("🔔 Posting debounced courseDataDidChange notification.")
        }
    }

    static func load() -> [Course] {
        if let data = UserDefaults.standard.data(forKey: key),
           let courses = try? JSONDecoder().decode([Course].self, from: data) {
            return courses
        }
        return []
    }
}
