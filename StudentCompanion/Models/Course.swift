import SwiftUI
import Combine
import Foundation

// MARK: - Supporting Types (Simplified)
struct CourseTimeSlot: Codable, Equatable {
    let start: Date
    let end: Date
    
    init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

class Course: Identifiable, ObservableObject, Codable, Equatable {
    @Published var id: UUID
    @Published var scheduleId: UUID // Required reference to schedule
    @Published var name: String
    @Published var iconName: String
    @Published var emoji: String? // Optional emoji icon (takes precedence over iconName if set)
    @Published var colorHex: String
    @Published var sortOrder: Int // Used for custom user-defined ordering
    
    // Academic Properties
    @Published var assignments: [Assignment] {
        didSet {
            oldValue.forEach { assignment in 
                cancellables.filter { $0.hashValue == assignment.id.hashValue }.forEach { $0.cancel() } 
            }
            setupAssignmentsObservation()
            triggerGradeUpdate()
        }
    }
    
    @Published var finalGradeGoal: String {
        didSet {
            triggerGradeUpdate()
        }
    }
    @Published var weightOfRemainingTasks: String {
        didSet {
            triggerGradeUpdate()
        }
    }

    // Course Information (Academic metadata only)
    @Published var creditHours: Double = 3.0
    @Published var courseCode: String = "" // e.g., "CS 101"
    @Published var section: String = ""    // e.g., "Section A"
    @Published var instructor: String = "" // Default instructor
    @Published var location: String = ""   // Default location

    // Grade Curve - added/subtracted from final grade calculation
    @Published var gradeCurve: Double = 0.0
    
    // Course Meetings - NEW: This is where scheduling happens
    @Published var meetings: [CourseMeeting] = []
    
    // DEPRECATED: Legacy fields kept for backward compatibility during migration
    @Published private var _legacyStartTime: Date?
    @Published private var _legacyEndTime: Date?
    @Published private var _legacyDaysOfWeek: [DayOfWeek] = []
    @Published private var _legacyReminderTime: ReminderTime = .none
    @Published private var _legacyIsLiveActivityEnabled: Bool = true
    @Published private var _legacyIsRotating: Bool = false
    @Published private var _legacyDay1StartTime: Date?
    @Published private var _legacyDay1EndTime: Date?
    @Published private var _legacyDay2StartTime: Date?
    @Published private var _legacyDay2EndTime: Date?
    
    private var cancellables = Set<AnyCancellable>()

    init(
        id: UUID = UUID(),
        scheduleId: UUID,
        name: String = "New Course",
        iconName: String = "book.closed.fill",
        emoji: String? = nil,
        colorHex: String = Color.blue.toHex() ?? "007AFF",
        assignments: [Assignment] = [],
        finalGradeGoal: String = "",
        weightOfRemainingTasks: String = "",
        creditHours: Double = 3.0,
        courseCode: String = "",
        section: String = "",
        instructor: String = "",
        location: String = "",
        meetings: [CourseMeeting] = [],
        sortOrder: Int = 0,
        gradeCurve: Double = 0.0
    ) {
        self.id = id
        self.scheduleId = scheduleId
        self.name = name
        self.iconName = iconName
        self.emoji = emoji
        self.colorHex = colorHex
        self.sortOrder = sortOrder

        // Ensure all assignments have the correct courseId
        self.assignments = assignments.map { assignment in
            var updatedAssignment = assignment
            updatedAssignment.courseId = id
            return updatedAssignment
        }

        self.finalGradeGoal = finalGradeGoal
        self.weightOfRemainingTasks = weightOfRemainingTasks
        self.creditHours = creditHours
        self.courseCode = courseCode
        self.section = section
        self.instructor = instructor
        self.location = location
        self.meetings = meetings
        self.gradeCurve = gradeCurve

        DispatchQueue.main.async { [weak self] in
            self?.setupAssignmentsObservation()
        }
    }

    // MARK: - Legacy Compatibility Initializer
    convenience init(
        id: UUID = UUID(), 
        scheduleId: UUID, 
        name: String = "New Course", 
        iconName: String = "book.closed.fill", 
        colorHex: String = Color.blue.toHex() ?? "007AFF", 
        assignments: [Assignment] = [], 
        finalGradeGoal: String = "", 
        weightOfRemainingTasks: String = "",
        // Legacy schedule parameters - will be converted to meetings
        startTime: Date? = nil,
        endTime: Date? = nil,
        daysOfWeek: [DayOfWeek] = [],
        location: String = "",
        instructor: String = "",
        creditHours: Double = 3.0,
        courseCode: String = "",
        section: String = "",
        isRotating: Bool = false,
        day1StartTime: Date? = nil,
        day1EndTime: Date? = nil,
        day2StartTime: Date? = nil,
        day2EndTime: Date? = nil
    ) {
        self.init(
            id: id,
            scheduleId: scheduleId,
            name: name,
            iconName: iconName,
            colorHex: colorHex,
            assignments: assignments,
            finalGradeGoal: finalGradeGoal,
            weightOfRemainingTasks: weightOfRemainingTasks,
            creditHours: creditHours,
            courseCode: courseCode,
            section: section,
            instructor: instructor,
            location: location,
            meetings: []
        )
        
        // Convert legacy schedule data to meetings
        if isRotating {
            if let start1 = day1StartTime, let end1 = day1EndTime {
                let meeting1 = CourseMeeting(
                    courseId: id,
                    scheduleId: scheduleId,
                    rotationLabel: "Day 1",
                    rotationIndex: 1,
                    startTime: start1,
                    endTime: end1,
                    location: location,
                    instructor: instructor
                )
                self.meetings.append(meeting1)
            }
            
            if let start2 = day2StartTime, let end2 = day2EndTime {
                let meeting2 = CourseMeeting(
                    courseId: id,
                    scheduleId: scheduleId,
                    rotationLabel: "Day 2",
                    rotationIndex: 2,
                    startTime: start2,
                    endTime: end2,
                    location: location,
                    instructor: instructor
                )
                self.meetings.append(meeting2)
            }
        } else if let start = startTime, let end = endTime, !daysOfWeek.isEmpty {
            // Create a single meeting for traditional schedule
            let meeting = CourseMeeting(
                courseId: id,
                scheduleId: scheduleId,
                startTime: start,
                endTime: end,
                location: location,
                instructor: instructor
            )
            self.meetings.append(meeting)
        }
        
        // Store legacy data for compatibility
        self._legacyStartTime = startTime
        self._legacyEndTime = endTime
        self._legacyDaysOfWeek = daysOfWeek
        self._legacyIsRotating = isRotating
        self._legacyDay1StartTime = day1StartTime
        self._legacyDay1EndTime = day1EndTime
        self._legacyDay2StartTime = day2StartTime
        self._legacyDay2EndTime = day2EndTime
    }

    private func setupAssignmentsObservation() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()

        assignments.forEach { assignment in
            assignment.objectWillChange
                .receive(on: DispatchQueue.main) 
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                    self?.debouncedGradeUpdate()
                }
                .store(in: &cancellables)
        }
    }
    
    private func triggerGradeUpdate() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastGradeUpdate")
    }
    
    private func debouncedGradeUpdate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.triggerGradeUpdate()
        }
    }
    
    func refreshObservationsAndSignalChange() {
        setupAssignmentsObservation()
        triggerGradeUpdate()
    }
    
    func addAssignment(_ assignment: Assignment) {
        var newAssignment = assignment
        newAssignment.courseId = self.id
        
        // Prevent duplicates by checking ID
        if !assignments.contains(where: { $0.id == newAssignment.id }) {
            assignments.append(newAssignment)
            #if DEBUG
            print("✅ Added assignment \(newAssignment.name) to course \(self.name)")
            #endif
        } else {
            #if DEBUG
            print("⚠️ Attempted to add duplicate assignment with ID: \(newAssignment.id.uuidString.prefix(8))")
            #endif
        }
    }
    
    func removeAssignment(withId id: UUID) {
        assignments.removeAll { $0.id == id }
        #if DEBUG
        print("🗑️ Removed assignment with ID: \(id.uuidString.prefix(8)) from course \(self.name)")
        #endif
    }

    // MARK: - Meeting Management
    
    func addMeeting(_ meeting: CourseMeeting) {
        var newMeeting = meeting
        newMeeting.courseId = self.id
        meetings.append(newMeeting)
    }
    
    func removeMeeting(withId id: UUID) {
        meetings.removeAll { $0.id == id }
    }
    
    func updateMeeting(_ meeting: CourseMeeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, scheduleId, name, iconName, emoji, colorHex, assignments, finalGradeGoal, weightOfRemainingTasks
        case creditHours, courseCode, section, instructor, location, meetings, sortOrder, gradeCurve
        // Legacy keys for backward compatibility
        case startTime, endTime, daysOfWeek, reminderTime, isLiveActivityEnabled
        case isRotating, day1StartTime, day1EndTime, day2StartTime, day2EndTime
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        scheduleId = try container.decode(UUID.self, forKey: .scheduleId)
        name = try container.decode(String.self, forKey: .name)
        iconName = try container.decode(String.self, forKey: .iconName)
        emoji = try container.decodeIfPresent(String.self, forKey: .emoji)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        
        let decodedAssignments = try container.decode([Assignment].self, forKey: .assignments)
        finalGradeGoal = try container.decode(String.self, forKey: .finalGradeGoal)
        weightOfRemainingTasks = try container.decode(String.self, forKey: .weightOfRemainingTasks)
        
        creditHours = try container.decodeIfPresent(Double.self, forKey: .creditHours) ?? 3.0
        courseCode = try container.decodeIfPresent(String.self, forKey: .courseCode) ?? ""
        section = try container.decodeIfPresent(String.self, forKey: .section) ?? ""
        instructor = try container.decodeIfPresent(String.self, forKey: .instructor) ?? ""
        location = try container.decodeIfPresent(String.self, forKey: .location) ?? ""
        meetings = try container.decodeIfPresent([CourseMeeting].self, forKey: .meetings) ?? []
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        gradeCurve = try container.decodeIfPresent(Double.self, forKey: .gradeCurve) ?? 0.0

        // Legacy compatibility - load old schedule data and convert to meetings if needed
        _legacyStartTime = try container.decodeIfPresent(Date.self, forKey: .startTime)
        _legacyEndTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        _legacyDaysOfWeek = try container.decodeIfPresent([DayOfWeek].self, forKey: .daysOfWeek) ?? []
        _legacyReminderTime = try container.decodeIfPresent(ReminderTime.self, forKey: .reminderTime) ?? .none
        _legacyIsLiveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .isLiveActivityEnabled) ?? true
        _legacyIsRotating = try container.decodeIfPresent(Bool.self, forKey: .isRotating) ?? false
        _legacyDay1StartTime = try container.decodeIfPresent(Date.self, forKey: .day1StartTime)
        _legacyDay1EndTime = try container.decodeIfPresent(Date.self, forKey: .day1EndTime)
        _legacyDay2StartTime = try container.decodeIfPresent(Date.self, forKey: .day2StartTime)
        _legacyDay2EndTime = try container.decodeIfPresent(Date.self, forKey: .day2EndTime)
        
        assignments = decodedAssignments
        
        for i in assignments.indices {
            assignments[i].courseId = id
        }
        
        // Auto-migrate legacy schedule data to meetings if meetings are empty
        if meetings.isEmpty {
            migrateLegacyScheduleToMeetings()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.setupAssignmentsObservation()
        }
    }
    
    private func migrateLegacyScheduleToMeetings() {
        if _legacyIsRotating {
            if let start1 = _legacyDay1StartTime, let end1 = _legacyDay1EndTime {
                let meeting1 = CourseMeeting(
                    courseId: id,
                    scheduleId: scheduleId,
                    rotationLabel: "Day 1",
                    rotationIndex: 1,
                    startTime: start1,
                    endTime: end1,
                    location: location,
                    instructor: instructor,
                    reminderTime: _legacyReminderTime,
                    isLiveActivityEnabled: _legacyIsLiveActivityEnabled
                )
                meetings.append(meeting1)
            }

            if let start2 = _legacyDay2StartTime, let end2 = _legacyDay2EndTime {
                let meeting2 = CourseMeeting(
                    courseId: id,
                    scheduleId: scheduleId,
                    rotationLabel: "Day 2",
                    rotationIndex: 2,
                    startTime: start2,
                    endTime: end2,
                    location: location,
                    instructor: instructor,
                    reminderTime: _legacyReminderTime,
                    isLiveActivityEnabled: _legacyIsLiveActivityEnabled
                )
                meetings.append(meeting2)
            }
        } else if let start = _legacyStartTime, let end = _legacyEndTime, !_legacyDaysOfWeek.isEmpty {
            let meeting = CourseMeeting(
                courseId: id,
                scheduleId: scheduleId,
                startTime: start,
                endTime: end,
                location: location,
                instructor: instructor,
                reminderTime: _legacyReminderTime,
                isLiveActivityEnabled: _legacyIsLiveActivityEnabled
            )
            meetings.append(meeting)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(scheduleId, forKey: .scheduleId)
        try container.encode(name, forKey: .name)
        try container.encode(iconName, forKey: .iconName)
        try container.encodeIfPresent(emoji, forKey: .emoji)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(assignments, forKey: .assignments)
        try container.encode(finalGradeGoal, forKey: .finalGradeGoal)
        try container.encode(weightOfRemainingTasks, forKey: .weightOfRemainingTasks)
        try container.encode(creditHours, forKey: .creditHours)
        try container.encode(courseCode, forKey: .courseCode)
        try container.encode(section, forKey: .section)
        try container.encode(instructor, forKey: .instructor)
        try container.encode(location, forKey: .location)
        try container.encode(meetings, forKey: .meetings)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(gradeCurve, forKey: .gradeCurve)

        // Encode legacy fields for backward compatibility
        try container.encodeIfPresent(_legacyStartTime, forKey: .startTime)
        try container.encodeIfPresent(_legacyEndTime, forKey: .endTime)
        try container.encode(_legacyDaysOfWeek, forKey: .daysOfWeek)
        try container.encode(_legacyReminderTime, forKey: .reminderTime)
        try container.encode(_legacyIsLiveActivityEnabled, forKey: .isLiveActivityEnabled)
        try container.encode(_legacyIsRotating, forKey: .isRotating)
        try container.encodeIfPresent(_legacyDay1StartTime, forKey: .day1StartTime)
        try container.encodeIfPresent(_legacyDay1EndTime, forKey: .day1EndTime)
        try container.encodeIfPresent(_legacyDay2StartTime, forKey: .day2StartTime)
        try container.encodeIfPresent(_legacyDay2EndTime, forKey: .day2EndTime)
    }

    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id &&
        lhs.scheduleId == rhs.scheduleId &&
        lhs.name == rhs.name &&
        lhs.iconName == rhs.iconName &&
        lhs.colorHex == rhs.colorHex &&
        lhs.assignments == rhs.assignments &&
        lhs.finalGradeGoal == rhs.finalGradeGoal &&
        lhs.weightOfRemainingTasks == rhs.weightOfRemainingTasks &&
        lhs.meetings == rhs.meetings
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
    
    // MARK: - Schedule Logic - Now based on meetings
    
    var hasScheduleInfo: Bool {
        return !meetings.isEmpty
    }
    
    func shouldAppear(on date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> Bool {
        // Check if any meeting should appear on this date
        for meeting in meetings {
            if meetingShouldAppear(meeting, on: date, in: schedule, calendar: calendar) {
                return true
            }
        }
        return false
    }
    
    private func meetingShouldAppear(_ meeting: CourseMeeting, on date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> Bool {
        
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return false
        }
        
        if let start = schedule.semesterStartDate, let end = schedule.semesterEndDate {
            let day = cal.startOfDay(for: date)
            let s = cal.startOfDay(for: start)
            let e = cal.startOfDay(for: end)
            if day < s || day > e {
                return false
            }
        }
        
        if let calendar {
            if !calendar.isDateWithinSemester(date) { return false }
            if calendar.isBreakDay(date) { return false }
        }
        
        // For rotating schedules, check rotation pattern
        if schedule.scheduleType == .rotating, let rotationIndex = meeting.rotationIndex {
            let day = cal.component(.day, from: date)
            let isMatchingRotationDay = (day % 2 == 1 && rotationIndex == 1) || (day % 2 == 0 && rotationIndex == 2)
            return isMatchingRotationDay
        } else {
            // For traditional schedules, check if meeting occurs on weekdays
            // (Individual meetings don't store days of week - they occur based on course schedule)
            let dayOfWeek = DayOfWeek.from(weekday: weekday)
            return _legacyDaysOfWeek.contains(dayOfWeek) || _legacyDaysOfWeek.isEmpty
        }
    }
    
    func toScheduleItems(for date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        
        for meeting in meetings {
            if meetingShouldAppear(meeting, on: date, in: schedule, calendar: calendar) {
                let item = ScheduleItem(
                    id: meeting.id,
                    title: name,
                    startTime: meeting.startTime,
                    endTime: meeting.endTime,
                    daysOfWeek: [],
                    location: meeting.location.isEmpty ? location : meeting.location,
                    instructor: meeting.instructor.isEmpty ? instructor : meeting.instructor,
                    color: color,
                    isLiveActivityEnabled: meeting.isLiveActivityEnabled,
                    reminderTime: meeting.reminderTime
                )
                items.append(item)
            }
        }
        
        return items
    }
    
    // MARK: - Legacy Compatibility Methods
    
    var startTime: Date? {
        return meetings.first?.startTime ?? _legacyStartTime
    }
    
    var endTime: Date? {
        return meetings.first?.endTime ?? _legacyEndTime
    }
    
    var daysOfWeek: [DayOfWeek] {
        return _legacyDaysOfWeek
    }
    
    var reminderTime: ReminderTime {
        return meetings.first?.reminderTime ?? _legacyReminderTime
    }
    
    var isLiveActivityEnabled: Bool {
        return meetings.first?.isLiveActivityEnabled ?? _legacyIsLiveActivityEnabled
    }
    
    var isRotating: Bool {
        return _legacyIsRotating || meetings.contains { $0.rotationIndex != nil }
    }
    
    var day1StartTime: Date? {
        return meetings.first { $0.rotationIndex == 1 }?.startTime ?? _legacyDay1StartTime
    }
    
    var day1EndTime: Date? {
        return meetings.first { $0.rotationIndex == 1 }?.endTime ?? _legacyDay1EndTime
    }
    
    var day2StartTime: Date? {
        return meetings.first { $0.rotationIndex == 2 }?.startTime ?? _legacyDay2StartTime
    }
    
    var day2EndTime: Date? {
        return meetings.first { $0.rotationIndex == 2 }?.endTime ?? _legacyDay2EndTime
    }
    
    func toScheduleItem(for date: Date, in schedule: ScheduleCollection, calendar: AcademicCalendar?) -> ScheduleItem? {
        return toScheduleItems(for: date, in: schedule, calendar: calendar).first
    }
    
    // MARK: - Legacy Methods (for backward compatibility)
    
    var isScheduledToday: Bool {
        let today = Date()
        let dayOfWeek = DayOfWeek.from(weekday: Calendar.current.component(.weekday, from: today))
        return daysOfWeek.contains(dayOfWeek)
    }
    
    var timeRange: String {
        if let firstMeeting = meetings.first {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(formatter.string(from: firstMeeting.startTime)) - \(formatter.string(from: firstMeeting.endTime))"
        }
        
        guard let start = _legacyStartTime, let end = _legacyEndTime else { return "Time TBD" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
    
    var duration: String {
        if let firstMeeting = meetings.first {
            let components = Calendar.current.dateComponents([.hour, .minute], from: firstMeeting.startTime, to: firstMeeting.endTime)
            let hours = components.hour ?? 0
            let minutes = components.minute ?? 0
            
            if hours > 0 {
                return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
            } else {
                return "\(minutes)m"
            }
        }
        
        guard let start = _legacyStartTime, let end = _legacyEndTime else { return "" }
        let components = Calendar.current.dateComponents([.hour, .minute], from: start, to: end)
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    var weeklyHours: Double {
        var totalHours: Double = 0
        
        for meeting in meetings {
            let duration = meeting.endTime.timeIntervalSince(meeting.startTime) / 3600.0
            totalHours += duration
        }
        
        if totalHours > 0 {
            return totalHours
        }
        
        // Fallback to legacy calculation
        guard let start = _legacyStartTime, let end = _legacyEndTime else { return 0.0 }
        let duration = end.timeIntervalSince(start) / 3600.0
        return duration * Double(daysOfWeek.count)
    }
    
    var daysString: String {
        if daysOfWeek.isEmpty { return "Meeting times vary" }
        return daysOfWeek.sorted { $0.rawValue < $1.rawValue }
                          .map { $0.short }
                          .joined(separator: ", ")
    }
    
    // MARK: - Grade Analytics

    /// Calculates the current grade with the curve applied
    func calculateCurrentGrade() -> Double? {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0

        for assignment in assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }

        guard totalWeight > 0 else { return nil }
        let rawGrade = totalWeightedGrade / totalWeight

        // Apply the grade curve and clamp to 0-100+
        return max(0, rawGrade + gradeCurve)
    }

    /// Calculates the raw grade without curve
    func calculateRawGrade() -> Double? {
        var totalWeightedGrade = 0.0
        var totalWeight = 0.0

        for assignment in assignments {
            if let grade = assignment.gradeValue, let weight = assignment.weightValue {
                totalWeightedGrade += grade * weight
                totalWeight += weight
            }
        }

        guard totalWeight > 0 else { return nil }
        return totalWeightedGrade / totalWeight
    }
    
    var currentGradeString: String {
        guard let grade = calculateCurrentGrade() else { return "N/A" }
        return String(format: "%.1f", grade)
    }
    
    var letterGrade: String {
        guard let grade = calculateCurrentGrade() else { return "N/A" }
        
        switch grade {
        case 97...100: return "A+"
        case 93..<97: return "A"
        case 90..<93: return "A-"
        case 87..<90: return "B+"
        case 83..<87: return "B"
        case 80..<83: return "B-"
        case 77..<80: return "C+"
        case 73..<77: return "C"
        case 70..<73: return "C-"
        case 67..<70: return "D+"
        case 65..<67: return "D"
        case 60..<65: return "D-"
        default: return "F"
        }
    }
    
    var gradeColor: Color {
        guard let grade = calculateCurrentGrade() else { return .gray }
        
        switch grade {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .red
        default: return .red
        }
    }
    
    // Calculate GPA points for this course
    var gpaPoints: Double? {
        guard let grade = calculateCurrentGrade() else { return nil }
        
        switch grade {
        case 97...100: return 4.0  // A+
        case 93..<97: return 4.0   // A
        case 90..<93: return 3.7   // A-
        case 87..<90: return 3.3   // B+
        case 83..<87: return 3.0   // B
        case 80..<83: return 2.7   // B-
        case 77..<80: return 2.3   // C+
        case 73..<77: return 2.0   // C
        case 70..<73: return 1.7   // C-
        case 67..<70: return 1.3   // D+
        case 65..<67: return 1.0   // D
        case 60..<65: return 0.7   // D-
        default: return 0.0        // F
        }
    }
    
    var fullDisplayName: String {
        var components: [String] = []
        
        if !courseCode.isEmpty {
            components.append(courseCode)
        }
        
        components.append(name)
        
        if !section.isEmpty {
            components.append("(\(section))")
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Extensions and Supporting Types (unchanged)
extension Color {
    var isDark: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance < 0.5
    }

    func lighter(by percentage: CGFloat = 0.2) -> Color {
        return self.adjust(by: abs(percentage))
    }

    private func adjust(by percentage: CGFloat) -> Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) {
            return Color(UIColor(red: min(r + percentage, 1.0),
                               green: min(g + percentage, 1.0),
                               blue: min(b + percentage, 1.0),
                               alpha: a))
        } else {
            return self
        }
    }
}

// MARK: - Legacy Support
struct Schedule: Identifiable, Codable {
    var id = UUID()
    var name: String
    var semester: String
    var isActive: Bool = false
    var isArchived: Bool = false
    var colorHex: String = Color.blue.toHex() ?? "007AFF"
    var academicCalendarId: UUID?
    var createdDate: Date = Date()
    var lastModified: Date = Date()
    
    init(name: String, semester: String, isActive: Bool = false) {
        self.name = name
        self.semester = semester
        self.isActive = isActive
    }
    
    var displayName: String {
        if name.isEmpty {
            return semester
        }
        return "\(name) - \(semester)"
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}

extension Course {
    static func from(scheduleItem: ScheduleItem, scheduleId: UUID) -> Course {
        let colorHex = scheduleItem.color.toHex() ?? "007AFF"
        
        // Create a meeting from the schedule item
        let meeting = CourseMeeting(
            courseId: scheduleItem.id,
            scheduleId: scheduleId,
            startTime: scheduleItem.startTime,
            endTime: scheduleItem.endTime,
            location: scheduleItem.location,
            instructor: scheduleItem.instructor,
            reminderTime: scheduleItem.reminderTime,
            isLiveActivityEnabled: scheduleItem.isLiveActivityEnabled
        )
        
        let course = Course(
            id: scheduleItem.id,
            scheduleId: scheduleId,
            name: scheduleItem.title,
            iconName: "book.closed.fill",
            colorHex: colorHex,
            assignments: [],
            finalGradeGoal: "",
            weightOfRemainingTasks: "",
            creditHours: 3.0,
            courseCode: "",
            section: "",
            instructor: scheduleItem.instructor,
            location: scheduleItem.location,
            meetings: [meeting]
        )
        
        return course
    }
    
    func toScheduleItem() -> ScheduleItem {
        if let firstMeeting = meetings.first {
            return ScheduleItem(
                id: firstMeeting.id,
                title: self.name,
                startTime: firstMeeting.startTime,
                endTime: firstMeeting.endTime,
                daysOfWeek: self.daysOfWeek,
                location: firstMeeting.location.isEmpty ? self.location : firstMeeting.location,
                instructor: firstMeeting.instructor.isEmpty ? self.instructor : firstMeeting.instructor,
                color: self.color,
                isLiveActivityEnabled: firstMeeting.isLiveActivityEnabled,
                reminderTime: firstMeeting.reminderTime
            )
        }
        
        // Legacy fallback
        let calendar = Calendar.current
        func defaultTimes() -> (Date, Date) {
            var components = calendar.dateComponents([.year, .month, .day], from: Date())
            components.hour = 9
            components.minute = 0
            let start = calendar.date(from: components) ?? Date()
            let end = calendar.date(byAdding: .minute, value: 60, to: start) ?? start.addingTimeInterval(3600)
            return (start, end)
        }
        
        let s = _legacyStartTime ?? defaultTimes().0
        let e = _legacyEndTime ?? calendar.date(byAdding: .minute, value: 60, to: s) ?? s.addingTimeInterval(3600)
        
        return ScheduleItem(
            id: self.id,
            title: self.name,
            startTime: s,
            endTime: e,
            daysOfWeek: self.daysOfWeek,
            location: self.location,
            instructor: self.instructor,
            color: self.color,
            isLiveActivityEnabled: self.isLiveActivityEnabled,
            reminderTime: self.reminderTime
        )
    }
}

// MARK: - Date Extension for Time Setting
extension Date {
    func setting(hour: Int, minute: Int) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)
    }
}
