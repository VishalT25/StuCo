import Foundation
import SwiftUI
import Supabase

// MARK: - Shareable Schedule Models

struct ShareableSchedule: Codable {
    let id: UUID
    let name: String
    let semester: String
    let courses: [ShareableCourse]
    let academicCalendarId: UUID?
    let metadata: ShareMetadata
    let scheduleType: String?
    let isRotating: Bool
}

struct ShareableCourse: Codable {
    let id: UUID
    let name: String
    let courseCode: String
    let colorHex: String
    let meetings: [ShareableMeeting]
    let instructor: String
    let location: String
    let emoji: String?
    let iconName: String
    let creditHours: Double
    let section: String
}

struct ShareableMeeting: Codable {
    let id: UUID
    let meetingType: String
    let startTime: Date
    let endTime: Date
    let daysOfWeek: [Int]
    let location: String
    let instructor: String
    let reminderTime: Int
    let isRotating: Bool
    let rotationLabel: String?
    let rotationIndex: Int?
}

struct ShareMetadata: Codable {
    let sharedBy: String?
    let sharedAt: Date
    let appVersion: String
    let totalCourses: Int
    let totalMeetings: Int
}

// MARK: - ShareableScheduleBuilder

@MainActor
final class ShareableScheduleBuilder: ObservableObject {
    static let shared = ShareableScheduleBuilder()

    @Published var isGeneratingShare = false
    @Published var lastError: Error?

    private init() {}

    // MARK: - Build Shareable Schedule

    func buildShareableSchedule(
        from schedule: ScheduleCollection,
        courses: [Course]
    ) -> ShareableSchedule {
        let shareableCourses = courses.map { course in
            ShareableCourse(
                id: course.id,
                name: course.name,
                courseCode: course.courseCode,
                colorHex: course.colorHex,
                meetings: course.meetings.map { meeting in
                    ShareableMeeting(
                        id: meeting.id,
                        meetingType: meeting.meetingType.rawValue,
                        startTime: meeting.startTime,
                        endTime: meeting.endTime,
                        daysOfWeek: meeting.daysOfWeek,
                        location: meeting.location,
                        instructor: meeting.instructor,
                        reminderTime: meeting.reminderTime.rawValue,
                        isRotating: meeting.isRotating,
                        rotationLabel: meeting.rotationLabel,
                        rotationIndex: meeting.rotationIndex
                    )
                },
                instructor: course.instructor,
                location: course.location,
                emoji: course.emoji,
                iconName: course.iconName,
                creditHours: course.creditHours,
                section: course.section
            )
        }

        let totalMeetings = shareableCourses.reduce(0) { $0 + $1.meetings.count }

        let metadata = ShareMetadata(
            sharedBy: nil, // Will be set by server if user info is available
            sharedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
            totalCourses: courses.count,
            totalMeetings: totalMeetings
        )

        return ShareableSchedule(
            id: schedule.id,
            name: schedule.name,
            semester: schedule.semester,
            courses: shareableCourses,
            academicCalendarId: schedule.academicCalendarID,
            metadata: metadata,
            scheduleType: schedule.scheduleType.rawValue,
            isRotating: schedule.scheduleType == .rotating
        )
    }

    // MARK: - Upload to Supabase and Get Share Link

    func shareSchedule(
        _ schedule: ScheduleCollection,
        courses: [Course]
    ) async throws -> String {
        isGeneratingShare = true
        defer { isGeneratingShare = false }

        // Build shareable format
        let shareable = buildShareableSchedule(from: schedule, courses: courses)

        // Generate unique share ID (8-character random string)
        let shareId = generateShareId()

        // Get user ID from auth
        guard let userId = SupabaseService.shared.currentUser?.id else {
            throw ShareError.notAuthenticated
        }

        // Create insert record
        struct SharedScheduleInsert: Encodable {
            let share_id: String
            let user_id: String
            let schedule_id: String
            let schedule_name: String
            let schedule_data: ShareableSchedule
        }

        let insertRecord = SharedScheduleInsert(
            share_id: shareId,
            user_id: userId.uuidString,
            schedule_id: schedule.id.uuidString,
            schedule_name: schedule.name,
            schedule_data: shareable
        )

        try await SupabaseService.shared.client
            .from("shared_schedules")
            .insert(insertRecord)
            .execute()

        // Return share URL
        let shareURL = "stuco://schedule/\(shareId)"
        return shareURL
    }

    // MARK: - Import Shared Schedule

    func importSharedSchedule(shareId: String) async throws -> (ScheduleCollection, [Course]) {
        // Fetch from Supabase
        struct SharedScheduleRecord: Decodable {
            let schedule_data: ShareableSchedule
        }

        let response: SharedScheduleRecord = try await SupabaseService.shared.client
            .from("shared_schedules")
            .select("schedule_data")
            .eq("share_id", value: shareId)
            .single()
            .execute()
            .value

        let shareable = response.schedule_data

        // Convert to local models with new UUIDs
        let newScheduleId = UUID()

        // Create ScheduleCollection
        var scheduleCollection = ScheduleCollection(
            name: shareable.name + " (Imported)",
            semester: shareable.semester,
            color: .blue,
            scheduleType: ScheduleType(rawValue: shareable.scheduleType ?? "traditional") ?? .traditional
        )
        scheduleCollection.id = newScheduleId
        scheduleCollection.isActive = false // Don't activate immediately
        scheduleCollection.academicCalendarID = shareable.academicCalendarId

        // Create courses with new UUIDs
        let courses: [Course] = shareable.courses.map { shareableCourse in
            let newCourseId = UUID()

            let meetings = shareableCourse.meetings.map { shareableMeeting in
                CourseMeeting(
                    id: UUID(),
                    userId: nil,
                    courseId: newCourseId,
                    scheduleId: newScheduleId,
                    meetingType: MeetingType(rawValue: shareableMeeting.meetingType) ?? .lecture,
                    meetingLabel: nil,
                    isRotating: shareableMeeting.isRotating,
                    rotationLabel: shareableMeeting.rotationLabel,
                    rotationPattern: nil,
                    rotationIndex: shareableMeeting.rotationIndex,
                    startTime: shareableMeeting.startTime,
                    endTime: shareableMeeting.endTime,
                    daysOfWeek: shareableMeeting.daysOfWeek,
                    location: shareableMeeting.location,
                    instructor: shareableMeeting.instructor,
                    reminderTime: ReminderTime(rawValue: shareableMeeting.reminderTime) ?? .none,
                    isLiveActivityEnabled: true
                )
            }

            return Course(
                id: newCourseId,
                scheduleId: newScheduleId,
                name: shareableCourse.name,
                iconName: shareableCourse.iconName,
                emoji: shareableCourse.emoji,
                colorHex: shareableCourse.colorHex,
                assignments: [],
                finalGradeGoal: "",
                weightOfRemainingTasks: "",
                creditHours: shareableCourse.creditHours,
                courseCode: shareableCourse.courseCode,
                section: shareableCourse.section,
                instructor: shareableCourse.instructor,
                location: shareableCourse.location,
                meetings: meetings,
                sortOrder: 0,
                gradeCurve: 0.0
            )
        }

        return (scheduleCollection, courses)
    }

    // MARK: - Helpers

    private func generateShareId() -> String {
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).compactMap { _ in characters.randomElement() })
    }
}

// MARK: - Errors

enum ShareError: LocalizedError {
    case notAuthenticated
    case encodingFailed
    case uploadFailed
    case invalidShareId
    case networkError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be signed in to share schedules"
        case .encodingFailed:
            return "Failed to encode schedule data"
        case .uploadFailed:
            return "Failed to upload schedule to server"
        case .invalidShareId:
            return "Invalid or expired share link"
        case .networkError:
            return "Network error occurred"
        }
    }
}
