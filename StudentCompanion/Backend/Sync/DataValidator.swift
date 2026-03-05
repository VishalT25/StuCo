import Foundation

// MARK: - Validation Result Types
enum ValidationResult {
    case valid
    case invalid(ValidationError)
    case warning(ValidationWarning)
    
    var isValid: Bool {
        switch self {
        case .valid: return true
        default: return false
        }
    }
    
    var hasWarning: Bool {
        switch self {
        case .warning: return true
        default: return false
        }
    }
}

struct ValidationError: Error, LocalizedError {
    let field: String
    let message: String
    let severity: ValidationSeverity
    
    var errorDescription: String? {
        "\(field): \(message)"
    }
}

struct ValidationWarning {
    let field: String
    let message: String
    let suggestion: String?
}

enum ValidationSeverity {
    case critical, high, medium, low
    
    var displayName: String {
        switch self {
        case .critical: return "Critical"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }
}

// MARK: - Data Validator Protocol
protocol DataValidator {
    associatedtype ModelType
    
    func validate(_ model: ModelType) -> ValidationResult
    func validateForSync(_ model: ModelType) -> ValidationResult
    func validateRelationships(_ model: ModelType, context: ValidationContext) -> ValidationResult
}

struct ValidationContext {
    let existingCourses: [Course]
    let existingSchedules: [ScheduleCollection]
    let existingCategories: [Category]
    let existingEvents: [Event]
    let existingAssignments: [Assignment]
    let existingAcademicCalendars: [AcademicCalendar]
}

// MARK: - Comprehensive Data Validator
@MainActor
class DataConsistencyValidator: ObservableObject {
    @Published private(set) var validationResults: [String: [ValidationResult]] = [:]
    @Published private(set) var consistencyIssues: [ConsistencyIssue] = []
    @Published private(set) var lastValidationTime: Date?
    @Published private(set) var validationStatistics = ValidationStatistics()
    
    private let cacheSystem = CacheSystem.shared
    
    // Individual validators
    private let courseValidator = CourseValidator()
    private let eventValidator = EventValidator()
    private let assignmentValidator = AssignmentValidator()
    private let scheduleValidator = ScheduleValidator()
    private let academicCalendarValidator = AcademicCalendarValidator()
    private let categoryValidator = CategoryValidator()
    
    // MARK: - Comprehensive Validation
    
    func validateAllData() async -> DataConsistencyReport {
        print("🔍 DataValidator: Starting comprehensive validation...")
        
        // Load all data from cache
        let context = ValidationContext(
            existingCourses: await cacheSystem.courseCache.retrieve(),
            existingSchedules: await cacheSystem.scheduleCache.retrieve(),
            existingCategories: await cacheSystem.categoryCache.retrieve(),
            existingEvents: await cacheSystem.eventCache.retrieve(),
            existingAssignments: await cacheSystem.assignmentCache.retrieve(),
            existingAcademicCalendars: await cacheSystem.academicCalendarCache.retrieve()
        )
        
        var allResults: [String: [ValidationResult]] = [:]
        var allIssues: [ConsistencyIssue] = []
        
        // Validate each data type
        allResults["courses"] = await validateCourses(context.existingCourses, context: context)
        allResults["events"] = await validateEvents(context.existingEvents, context: context)
        allResults["assignments"] = await validateAssignments(context.existingAssignments, context: context)
        allResults["schedules"] = await validateSchedules(context.existingSchedules, context: context)
        allResults["academic_calendars"] = await validateAcademicCalendars(context.existingAcademicCalendars, context: context)
        allResults["categories"] = await validateCategories(context.existingCategories, context: context)
        
        // Check cross-table consistency
        allIssues.append(contentsOf: await validateCrossTableConsistency(context))
        
        // Update state
        validationResults = allResults
        consistencyIssues = allIssues
        lastValidationTime = Date()
        
        // Update statistics
        updateValidationStatistics(allResults, issues: allIssues)
        
        let report = DataConsistencyReport(
            results: allResults,
            issues: allIssues,
            statistics: validationStatistics,
            timestamp: Date()
        )
        
        print("🔍 DataValidator: Validation complete - \(report.totalErrors) errors, \(report.totalWarnings) warnings")
        
        return report
    }
    
    // MARK: - Individual Validators
    
    private func validateCourses(_ courses: [Course], context: ValidationContext) async -> [ValidationResult] {
        return courses.map { course in
            let basicValidation = courseValidator.validate(course)
            if !basicValidation.isValid {
                return basicValidation
            }
            
            let syncValidation = courseValidator.validateForSync(course)
            if !syncValidation.isValid {
                return syncValidation
            }
            
            return courseValidator.validateRelationships(course, context: context)
        }
    }
    
    private func validateEvents(_ events: [Event], context: ValidationContext) async -> [ValidationResult] {
        return events.map { event in
            let basicValidation = eventValidator.validate(event)
            if !basicValidation.isValid {
                return basicValidation
            }
            
            let syncValidation = eventValidator.validateForSync(event)
            if !syncValidation.isValid {
                return syncValidation
            }
            
            return eventValidator.validateRelationships(event, context: context)
        }
    }
    
    private func validateAssignments(_ assignments: [Assignment], context: ValidationContext) async -> [ValidationResult] {
        return assignments.map { assignment in
            let basicValidation = assignmentValidator.validate(assignment)
            if !basicValidation.isValid {
                return basicValidation
            }
            
            let syncValidation = assignmentValidator.validateForSync(assignment)
            if !syncValidation.isValid {
                return syncValidation
            }
            
            return assignmentValidator.validateRelationships(assignment, context: context)
        }
    }
    
    private func validateSchedules(_ schedules: [ScheduleCollection], context: ValidationContext) async -> [ValidationResult] {
        return schedules.map { schedule in
            let basicValidation = scheduleValidator.validate(schedule)
            if !basicValidation.isValid {
                return basicValidation
            }
            
            let syncValidation = scheduleValidator.validateForSync(schedule)
            if !syncValidation.isValid {
                return syncValidation
            }
            
            return scheduleValidator.validateRelationships(schedule, context: context)
        }
    }
    
    private func validateAcademicCalendars(_ calendars: [AcademicCalendar], context: ValidationContext) async -> [ValidationResult] {
        return calendars.map { calendar in
            let basicValidation = academicCalendarValidator.validate(calendar)
            if !basicValidation.isValid {
                return basicValidation
            }
            
            let syncValidation = academicCalendarValidator.validateForSync(calendar)
            if !syncValidation.isValid {
                return syncValidation
            }
            
            return academicCalendarValidator.validateRelationships(calendar, context: context)
        }
    }
    
    private func validateCategories(_ categories: [Category], context: ValidationContext) async -> [ValidationResult] {
        return categories.map { category in
            let basicValidation = categoryValidator.validate(category)
            if !basicValidation.isValid {
                return basicValidation
            }
            
            let syncValidation = categoryValidator.validateForSync(category)
            if !syncValidation.isValid {
                return syncValidation
            }
            
            return categoryValidator.validateRelationships(category, context: context)
        }
    }
    
    // MARK: - Cross-Table Consistency
    
    private func validateCrossTableConsistency(_ context: ValidationContext) async -> [ConsistencyIssue] {
        var issues: [ConsistencyIssue] = []
        
        // Check orphaned assignments (assignments without courses)
        let courseIds = Set(context.existingCourses.map { $0.id })
        let orphanedAssignments = context.existingAssignments.filter { !courseIds.contains($0.courseId) }
        
        for assignment in orphanedAssignments {
            issues.append(ConsistencyIssue(
                type: .orphanedReference,
                description: "Assignment '\(assignment.name)' references non-existent course",
                affectedTable: "assignments",
                affectedId: assignment.id.uuidString,
                severity: .high,
                autoFixable: false
            ))
        }
        
        // Check orphaned events (events with invalid course/category references)
        let categoryIds = Set(context.existingCategories.map { $0.id })
        
        for event in context.existingEvents {
            if let courseId = event.courseId, !courseIds.contains(courseId) {
                issues.append(ConsistencyIssue(
                    type: .orphanedReference,
                    description: "Event '\(event.title)' references non-existent course",
                    affectedTable: "events",
                    affectedId: event.id.uuidString,
                    severity: .medium,
                    autoFixable: true
                ))
            }
            
            if let categoryId = event.categoryId, !categoryIds.contains(categoryId) {
                issues.append(ConsistencyIssue(
                    type: .orphanedReference,
                    description: "Event '\(event.title)' references non-existent category",
                    affectedTable: "events",
                    affectedId: event.id.uuidString,
                    severity: .low,
                    autoFixable: true
                ))
            }
        }
        
        // Check schedule-course consistency
        let scheduleIds = Set(context.existingSchedules.map { $0.id })
        let coursesWithInvalidSchedules = context.existingCourses.filter { !scheduleIds.contains($0.scheduleId) }
        
        for course in coursesWithInvalidSchedules {
            issues.append(ConsistencyIssue(
                type: .orphanedReference,
                description: "Course '\(course.name)' references non-existent schedule",
                affectedTable: "courses",
                affectedId: course.id.uuidString,
                severity: .critical,
                autoFixable: false
            ))
        }
        
        // Check for duplicate active schedules
        let activeSchedules = context.existingSchedules.filter { $0.isActive && !$0.isArchived }
        if activeSchedules.count > 1 {
            for schedule in activeSchedules.dropFirst() {
                issues.append(ConsistencyIssue(
                    type: .dataInconsistency,
                    description: "Multiple active schedules detected",
                    affectedTable: "schedules",
                    affectedId: schedule.id.uuidString,
                    severity: .high,
                    autoFixable: true
                ))
            }
        }
        
        // Check for time conflicts in schedule items
        for schedule in context.existingSchedules where !schedule.isArchived {
            let timeConflicts = findTimeConflicts(in: schedule.scheduleItems)
            for conflict in timeConflicts {
                issues.append(ConsistencyIssue(
                    type: .timeConflict,
                    description: "Schedule items '\(conflict.item1.title)' and '\(conflict.item2.title)' have overlapping times",
                    affectedTable: "schedule_items",
                    affectedId: conflict.item1.id.uuidString,
                    severity: .medium,
                    autoFixable: false
                ))
            }
        }
        
        return issues
    }
    
    private func findTimeConflicts(in scheduleItems: [ScheduleItem]) -> [TimeConflict] {
        var conflicts: [TimeConflict] = []
        
        for i in 0..<scheduleItems.count {
            for j in (i+1)..<scheduleItems.count {
                let item1 = scheduleItems[i]
                let item2 = scheduleItems[j]
                
                // Check if they have overlapping days
                let commonDays = Set(item1.daysOfWeek).intersection(Set(item2.daysOfWeek))
                guard !commonDays.isEmpty else { continue }
                
                // Check for time overlap
                let item1Start = item1.startTime.timeIntervalSince1970
                let item1End = item1.endTime.timeIntervalSince1970
                let item2Start = item2.startTime.timeIntervalSince1970
                let item2End = item2.endTime.timeIntervalSince1970
                
                let hasTimeOverlap = (item1Start < item2End) && (item2Start < item1End)
                
                if hasTimeOverlap {
                    conflicts.append(TimeConflict(item1: item1, item2: item2, conflictingDays: Array(commonDays)))
                }
            }
        }
        
        return conflicts
    }
    
    // MARK: - Issue Resolution
    
    func autoFixIssue(_ issue: ConsistencyIssue) async -> Bool {
        guard issue.autoFixable else { return false }
        
        switch issue.type {
        case .orphanedReference:
            return await fixOrphanedReference(issue)
        case .dataInconsistency:
            return await fixDataInconsistency(issue)
        case .duplicateData:
            return await fixDuplicateData(issue)
        default:
            return false
        }
    }
    
    private func fixOrphanedReference(_ issue: ConsistencyIssue) async -> Bool {
        switch issue.affectedTable {
        case "events":
            // Remove invalid course/category references
            if let eventId = UUID(uuidString: issue.affectedId),
               var event = await cacheSystem.eventCache.retrieve(id: issue.affectedId) {
                
                if issue.description.contains("course") {
                    event.courseId = nil
                } else if issue.description.contains("category") {
                    event.categoryId = nil
                }
                
                await cacheSystem.eventCache.update(event)
                return true
            }
        default:
            break
        }
        
        return false
    }
    
    private func fixDataInconsistency(_ issue: ConsistencyIssue) async -> Bool {
        if issue.affectedTable == "schedules" && issue.description.contains("Multiple active schedules") {
            // Deactivate all but the first active schedule
            let schedules = await cacheSystem.scheduleCache.retrieve()
            let activeSchedules = schedules.filter { $0.isActive && !$0.isArchived }
            
            for (index, schedule) in activeSchedules.enumerated() {
                if index > 0 {
                    var updatedSchedule = schedule
                    updatedSchedule.isActive = false
                    await cacheSystem.scheduleCache.update(updatedSchedule)
                }
            }
            return true
        }
        
        return false
    }
    
    private func fixDuplicateData(_ issue: ConsistencyIssue) async -> Bool {
        // Implementation for fixing duplicate data
        return false
    }
    
    // MARK: - Statistics
    
    private func updateValidationStatistics(_ results: [String: [ValidationResult]], issues: [ConsistencyIssue]) {
        var errors = 0
        var warnings = 0
        
        for (table, tableResults) in results {
            for result in tableResults {
                switch result {
                case .invalid:
                    errors += 1
                    validationStatistics.incrementError(for: table)
                case .warning:
                    warnings += 1
                    validationStatistics.incrementWarning(for: table)
                case .valid:
                    validationStatistics.incrementValid(for: table)
                }
            }
        }
        
        validationStatistics.updateSummary(
            totalErrors: errors,
            totalWarnings: warnings,
            totalIssues: issues.count
        )
    }

    func validateEvent(_ event: Event) -> ValidationResult {
        eventValidator.validate(event)
    }
    
    func validateCategory(_ category: Category) -> ValidationResult {
        categoryValidator.validate(category)
    }
    
    func validateCourse(_ course: Course) -> ValidationResult {
        courseValidator.validate(course)
    }
    
    func validateAssignment(_ assignment: Assignment) -> ValidationResult {
        assignmentValidator.validate(assignment)
    }
}

// MARK: - Specific Validators

class CourseValidator: DataValidator {
    func validate(_ model: Course) -> ValidationResult {
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "name",
                message: "Course name cannot be empty",
                severity: .critical
            ))
        }
        
        if model.name.count > 100 {
            return .warning(ValidationWarning(
                field: "name",
                message: "Course name is very long",
                suggestion: "Consider shortening to under 100 characters"
            ))
        }
        
        return .valid
    }
    
    func validateForSync(_ model: Course) -> ValidationResult {
        // Validate data that would be synced to database
        if model.colorHex.isEmpty {
            return .invalid(ValidationError(
                field: "colorHex",
                message: "Color hex value is required for sync",
                severity: .medium
            ))
        }
        
        return .valid
    }
    
    func validateRelationships(_ model: Course, context: ValidationContext) -> ValidationResult {
        // Check if referenced schedule exists
        let scheduleExists = context.existingSchedules.contains { $0.id == model.scheduleId }
        
        if !scheduleExists {
            return .invalid(ValidationError(
                field: "scheduleId",
                message: "Referenced schedule does not exist",
                severity: .critical
            ))
        }
        
        return .valid
    }
}

class EventValidator: DataValidator {
    func validate(_ model: Event) -> ValidationResult {
        if model.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "title",
                message: "Event title cannot be empty",
                severity: .critical
            ))
        }
        
        if model.date < Calendar.current.date(byAdding: .year, value: -2, to: Date())! {
            return .warning(ValidationWarning(
                field: "date",
                message: "Event date is more than 2 years in the past",
                suggestion: "Verify this date is correct"
            ))
        }
        
        return .valid
    }
    
    func validateForSync(_ model: Event) -> ValidationResult {
        return .valid
    }
    
    func validateRelationships(_ model: Event, context: ValidationContext) -> ValidationResult {
        if let courseId = model.courseId {
            let courseExists = context.existingCourses.contains { $0.id == courseId }
            if !courseExists {
                return .invalid(ValidationError(
                    field: "courseId",
                    message: "Referenced course does not exist",
                    severity: .medium
                ))
            }
        }
        
        if let categoryId = model.categoryId {
            let categoryExists = context.existingCategories.contains { $0.id == categoryId }
            if !categoryExists {
                return .warning(ValidationWarning(
                    field: "categoryId",
                    message: "Referenced category does not exist",
                    suggestion: "Category reference will be cleared"
                ))
            }
        }
        
        return .valid
    }
}

class AssignmentValidator: DataValidator {
    func validate(_ model: Assignment) -> ValidationResult {
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "name",
                message: "Assignment name cannot be empty",
                severity: .critical
            ))
        }
        
        // Validate grade if provided
        if !model.grade.isEmpty, let grade = Double(model.grade) {
            if grade < 0 || grade > 100 {
                return .warning(ValidationWarning(
                    field: "grade",
                    message: "Grade value seems unusual",
                    suggestion: "Verify grade is correct (0-100)"
                ))
            }
        }
        
        // Validate weight if provided
        if !model.weight.isEmpty, let weight = Double(model.weight) {
            if weight <= 0 || weight > 100 {
                return .warning(ValidationWarning(
                    field: "weight",
                    message: "Weight value seems unusual",
                    suggestion: "Verify weight is correct (0-100)"
                ))
            }
        }
        
        return .valid
    }
    
    func validateForSync(_ model: Assignment) -> ValidationResult {
        return .valid
    }
    
    func validateRelationships(_ model: Assignment, context: ValidationContext) -> ValidationResult {
        let courseExists = context.existingCourses.contains { $0.id == model.courseId }
        
        if !courseExists {
            return .invalid(ValidationError(
                field: "courseId",
                message: "Referenced course does not exist",
                severity: .critical
            ))
        }
        
        return .valid
    }
}

class ScheduleValidator: DataValidator {
    func validate(_ model: ScheduleCollection) -> ValidationResult {
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "name",
                message: "Schedule name cannot be empty",
                severity: .critical
            ))
        }
        
        if model.semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "semester",
                message: "Semester cannot be empty",
                severity: .critical
            ))
        }
        
        return .valid
    }
    
    func validateForSync(_ model: ScheduleCollection) -> ValidationResult {
        return .valid
    }
    
    func validateRelationships(_ model: ScheduleCollection, context: ValidationContext) -> ValidationResult {
        return .valid
    }
}

class AcademicCalendarValidator: DataValidator {
    func validate(_ model: AcademicCalendar) -> ValidationResult {
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "name",
                message: "Calendar name cannot be empty",
                severity: .critical
            ))
        }
        
        if model.startDate >= model.endDate {
            return .invalid(ValidationError(
                field: "dates",
                message: "Start date must be before end date",
                severity: .critical
            ))
        }
        
        // Validate breaks are within calendar period
        for breakPeriod in model.breaks {
            if breakPeriod.startDate < model.startDate || breakPeriod.endDate > model.endDate {
                return .warning(ValidationWarning(
                    field: "breaks",
                    message: "Break period '\(breakPeriod.name)' extends outside calendar period",
                    suggestion: "Adjust break dates to fit within calendar"
                ))
            }
        }
        
        return .valid
    }
    
    func validateForSync(_ model: AcademicCalendar) -> ValidationResult {
        return .valid
    }
    
    func validateRelationships(_ model: AcademicCalendar, context: ValidationContext) -> ValidationResult {
        return .valid
    }
}

class CategoryValidator: DataValidator {
    func validate(_ model: Category) -> ValidationResult {
        if model.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalid(ValidationError(
                field: "name",
                message: "Category name cannot be empty",
                severity: .critical
            ))
        }
        
        return .valid
    }
    
    func validateForSync(_ model: Category) -> ValidationResult {
        return .valid
    }
    
    func validateRelationships(_ model: Category, context: ValidationContext) -> ValidationResult {
        return .valid
    }
}

// MARK: - Supporting Types

enum ConsistencyIssueType {
    case orphanedReference
    case dataInconsistency
    case duplicateData
    case timeConflict
    case missingRequiredData
    
    var displayName: String {
        switch self {
        case .orphanedReference: return "Orphaned Reference"
        case .dataInconsistency: return "Data Inconsistency"
        case .duplicateData: return "Duplicate Data"
        case .timeConflict: return "Time Conflict"
        case .missingRequiredData: return "Missing Required Data"
        }
    }
}

struct ConsistencyIssue {
    let id = UUID()
    let type: ConsistencyIssueType
    let description: String
    let affectedTable: String
    let affectedId: String
    let severity: ValidationSeverity
    let autoFixable: Bool
    let timestamp = Date()
}

struct TimeConflict {
    let item1: ScheduleItem
    let item2: ScheduleItem
    let conflictingDays: [DayOfWeek]
}

struct DataConsistencyReport {
    let results: [String: [ValidationResult]]
    let issues: [ConsistencyIssue]
    let statistics: ValidationStatistics
    let timestamp: Date
    
    var totalErrors: Int {
        results.values.flatMap { $0 }.count { !$0.isValid }
    }
    
    var totalWarnings: Int {
        results.values.flatMap { $0 }.count { $0.hasWarning }
    }
    
    var isHealthy: Bool {
        totalErrors == 0 && issues.filter { $0.severity == .critical }.isEmpty
    }
}

class ValidationStatistics: ObservableObject {
    @Published private(set) var validCounts: [String: Int] = [:]
    @Published private(set) var errorCounts: [String: Int] = [:]
    @Published private(set) var warningCounts: [String: Int] = [:]
    @Published private(set) var totalErrors = 0
    @Published private(set) var totalWarnings = 0
    @Published private(set) var totalIssues = 0
    
    func incrementValid(for table: String) {
        validCounts[table, default: 0] += 1
    }
    
    func incrementError(for table: String) {
        errorCounts[table, default: 0] += 1
    }
    
    func incrementWarning(for table: String) {
        warningCounts[table, default: 0] += 1
    }
    
    func updateSummary(totalErrors: Int, totalWarnings: Int, totalIssues: Int) {
        self.totalErrors = totalErrors
        self.totalWarnings = totalWarnings
        self.totalIssues = totalIssues
    }
    
    var overallHealthScore: Double {
        let totalValidations = totalErrors + totalWarnings + validCounts.values.reduce(0, +)
        guard totalValidations > 0 else { return 1.0 }
        
        let validCount = validCounts.values.reduce(0, +)
        return Double(validCount) / Double(totalValidations)
    }
}