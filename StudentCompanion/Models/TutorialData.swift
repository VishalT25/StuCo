import Foundation
import SwiftUI

// MARK: - Tutorial Data Models

struct TutorialPage: Identifiable {
    let id: Int
    let visualType: TutorialVisualType
    let headline: String
    let body: String
    let features: [String]?
    let isPremium: Bool
    let showCTA: Bool
}

enum TutorialVisualType {
    case welcome
    case dashboard
    case scheduleWizard
    case aiScheduleImport
    case courseCreation
    case academicCalendar
    case aiCalendarImport
    case events
    case gpa
    case documents
    case customization
    case completion

    @ViewBuilder
    func makeVisual(theme: AppTheme) -> some View {
        switch self {
        case .welcome:
            WelcomeVisual(theme: theme)
        case .dashboard:
            DashboardVisual(theme: theme)
        case .scheduleWizard:
            ScheduleWizardVisual(theme: theme)
        case .aiScheduleImport:
            AIScheduleImportVisual(theme: theme)
        case .courseCreation:
            CourseCreationVisual(theme: theme)
        case .academicCalendar:
            AcademicCalendarVisual(theme: theme)
        case .aiCalendarImport:
            AICalendarImportVisual(theme: theme)
        case .events:
            EventsVisual(theme: theme)
        case .gpa:
            GPAVisual(theme: theme)
        case .documents:
            DocumentsVisual(theme: theme)
        case .customization:
            CustomizationVisual(theme: theme)
        case .completion:
            CompletionVisual(theme: theme)
        }
    }
}

// MARK: - Tutorial Content

extension TutorialPage {
    static let allPages: [TutorialPage] = [
        // Page 1: Welcome
        TutorialPage(
            id: 0,
            visualType: .welcome,
            headline: "Welcome to StuCo",
            body: "Your all-in-one academic companion. Let's take a quick tour of what StuCo can do for you.",
            features: nil,
            isPremium: false,
            showCTA: false
        ),

        // Page 2: Dashboard
        TutorialPage(
            id: 1,
            visualType: .dashboard,
            headline: "Everything at a Glance",
            body: "Your dashboard shows today's classes, upcoming events, and quick access to all your academic needs.",
            features: nil,
            isPremium: false,
            showCTA: false
        ),

        // Page 3: Schedule Wizard
        TutorialPage(
            id: 2,
            visualType: .scheduleWizard,
            headline: "Build Your Schedule",
            body: "Follow our easy 4-step wizard to create your class schedule. Add your courses, meeting times, and you're all set.",
            features: [
                "Name your schedule",
                "Set semester dates",
                "Choose academic calendar",
                "Add classes"
            ],
            isPremium: false,
            showCTA: false
        ),

        // Page 4: AI Schedule Import (Premium)
        TutorialPage(
            id: 3,
            visualType: .aiScheduleImport,
            headline: "Import Schedules Instantly",
            body: "Take a photo of your class schedule and let AI do the work. StuCo automatically extracts class times, locations, and creates your schedule.",
            features: nil,
            isPremium: true,
            showCTA: false
        ),

        // Page 5: Course Creation
        TutorialPage(
            id: 4,
            visualType: .courseCreation,
            headline: "Flexible Course Setup",
            body: "Add courses with multiple meeting times—lectures, labs, tutorials. Customize colors, icons, and set reminders for each meeting.",
            features: [
                "Multiple meetings per course",
                "Custom colors & icons",
                "Individual reminders"
            ],
            isPremium: false,
            showCTA: false
        ),

        // Page 6: Academic Calendar
        TutorialPage(
            id: 5,
            visualType: .academicCalendar,
            headline: "Plan Your Semester",
            body: "Create academic calendars with semester dates, breaks, and holidays. Never lose track of important dates.",
            features: [
                "Semester dates",
                "Breaks management",
                "Holiday tracking"
            ],
            isPremium: false,
            showCTA: false
        ),

        // Page 7: AI Calendar Import (Premium)
        TutorialPage(
            id: 6,
            visualType: .aiCalendarImport,
            headline: "Smart Calendar Creation",
            body: "Upload your syllabus and StuCo extracts all important dates—breaks, deadlines, holidays—automatically.",
            features: nil,
            isPremium: true,
            showCTA: false
        ),

        // Page 8: Events & Reminders
        TutorialPage(
            id: 7,
            visualType: .events,
            headline: "Stay Organized",
            body: "Create events, assignments, and reminders. Link them to courses and sync with your Apple or Google Calendar.",
            features: [
                "Event categories",
                "Reminder times",
                "Calendar sync"
            ],
            isPremium: false,
            showCTA: false
        ),

        // Page 9: GPA Tracking
        TutorialPage(
            id: 8,
            visualType: .gpa,
            headline: "Monitor Your Progress",
            body: "Track your grades and GPA across all courses. StuCo automatically calculates your semester and cumulative GPA.",
            features: [
                "Weighted GPA",
                "Percentage/letter grades",
                "Semester averages"
            ],
            isPremium: false,
            showCTA: false
        ),

        // Page 10: Documents (Premium)
        TutorialPage(
            id: 9,
            visualType: .documents,
            headline: "All Your Files in One Place",
            body: "Upload course syllabi, notes, and documents. Use AI to extract important information from syllabi automatically.",
            features: [
                "PDF storage",
                "AI syllabus parsing",
                "Document viewer"
            ],
            isPremium: true,
            showCTA: false
        ),

        // Page 11: Customization
        TutorialPage(
            id: 10,
            visualType: .customization,
            headline: "Make It Yours",
            body: "Choose from beautiful themes, customize app icons, sync with calendars, and adjust settings to match your workflow.",
            features: [
                "4 stunning themes",
                "Custom app icons",
                "Calendar sync"
            ],
            isPremium: false,
            showCTA: false
        ),

        // Page 12: Completion
        TutorialPage(
            id: 11,
            visualType: .completion,
            headline: "You're Ready to Go!",
            body: "That's the tour! Start by creating your first schedule or explore at your own pace. You can revisit this tutorial anytime in Settings.",
            features: nil,
            isPremium: false,
            showCTA: true
        )
    ]
}
