import SwiftUI
import Combine

// MARK: - Wizard Tooltip Step (sub-steps inside ScheduleCreationWizardView)

enum WizardTooltipStep: Int, CaseIterable {
    case none = 0
    case nameIntro = 1
    case semesterTip = 2
    case calendarTip = 3
    case reviewTip = 4

    var icon: String {
        switch self {
        case .none: return ""
        case .nameIntro: return "pencil.and.list.clipboard"
        case .semesterTip: return "calendar.badge.clock"
        case .calendarTip: return "calendar.badge.plus"
        case .reviewTip: return "checkmark.seal"
        }
    }

    var text: String {
        switch self {
        case .none: return ""
        case .nameIntro: return "Name your schedule and choose your semester"
        case .semesterTip: return "Set when your semester starts and how long it is"
        case .calendarTip: return "Link an academic calendar to track breaks — or skip for now"
        case .reviewTip: return "Looking good! Tap Create Schedule when ready"
        }
    }
}

// MARK: - Course Detail Tooltip Step

enum CourseDetailTooltipStep: Int, CaseIterable {
    case none = 0
    case gradesIntro = 1
    case documentsTip = 2
    case done = 3

    var icon: String {
        switch self {
        case .none, .done: return ""
        case .gradesIntro: return "chart.bar.fill"
        case .documentsTip: return "folder.fill"
        }
    }

    var text: String {
        switch self {
        case .none, .done: return ""
        case .gradesIntro: return "Add assignments and track your grades here"
        case .documentsTip: return "Tap the folder icon above to store your syllabus and course documents"
        }
    }
}

// MARK: - Onboarding Step

enum OnboardingStep: Int, CaseIterable {
    case inactive = -1
    case tutorial = 0
    case scheduleIntro = 1
    case highlightScheduleOption = 2
    case creatingSchedule = 3
    case scheduleComplete = 4
    case coursesTip = 5
    case remindersTip = 6
    case complete = 7
    case done = 8

    /// Whether this step should show the guided overlay (dimmed background + card/spotlight)
    var showsGuidedOverlay: Bool {
        switch self {
        case .scheduleIntro, .highlightScheduleOption, .scheduleComplete,
             .coursesTip, .remindersTip, .complete:
            return true
        default:
            return false
        }
    }

    /// The spotlight anchor ID this step highlights (nil for card-only steps)
    var spotlightAnchorID: String? {
        switch self {
        case .highlightScheduleOption:
            return "fab-schedule"
        default:
            return nil
        }
    }
}

// MARK: - Tooltip Position

enum TooltipPosition {
    case above
    case below
    case leading
    case trailing
    case auto

    func calculatePosition(for targetFrame: CGRect, tooltipSize: CGSize, screenSize: CGSize, safeArea: EdgeInsets) -> CGPoint {
        let padding: CGFloat = 16

        switch self {
        case .above:
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.minY - tooltipSize.height / 2 - padding
            )
        case .below:
            return CGPoint(
                x: targetFrame.midX,
                y: targetFrame.maxY + tooltipSize.height / 2 + padding
            )
        case .leading:
            return CGPoint(
                x: targetFrame.minX - tooltipSize.width / 2 - padding,
                y: targetFrame.midY
            )
        case .trailing:
            return CGPoint(
                x: targetFrame.maxX + tooltipSize.width / 2 + padding,
                y: targetFrame.midY
            )
        case .auto:
            let spaceAbove = targetFrame.minY - safeArea.top
            let spaceBelow = screenSize.height - targetFrame.maxY - safeArea.bottom
            let requiredHeight = tooltipSize.height + padding * 2

            if spaceAbove >= requiredHeight {
                return TooltipPosition.above.calculatePosition(
                    for: targetFrame, tooltipSize: tooltipSize,
                    screenSize: screenSize, safeArea: safeArea
                )
            } else if spaceBelow >= requiredHeight {
                return TooltipPosition.below.calculatePosition(
                    for: targetFrame, tooltipSize: tooltipSize,
                    screenSize: screenSize, safeArea: safeArea
                )
            } else {
                return TooltipPosition.above.calculatePosition(
                    for: targetFrame, tooltipSize: tooltipSize,
                    screenSize: screenSize, safeArea: safeArea
                )
            }
        }
    }
}

// MARK: - Arrow Direction

enum ArrowDirection {
    case up
    case down
    case left
    case right
}

// MARK: - Spotlight Anchor Preference Key

struct SpotlightAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

// MARK: - View Extension for Spotlight Anchors

extension View {
    func spotlightAnchor(_ id: String) -> some View {
        self.anchorPreference(key: SpotlightAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

// MARK: - Guided Onboarding Manager

@MainActor
final class GuidedOnboardingManager: ObservableObject {
    static let shared = GuidedOnboardingManager()

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .inactive
    @Published var isActive = false
    @Published var spotlightFrame: CGRect = .zero
    @Published var showCompactTutorial = false
    @Published var requestedTabSwitch: Int?
    @Published var requestAutoExpandFAB = false
    @Published var spotlightVisible = false

    // Sub-step tracking for in-sheet tooltips
    @Published var wizardTooltipStep: WizardTooltipStep = .none
    @Published var courseDetailTooltipStep: CourseDetailTooltipStep = .none
    @Published var shouldAutoOpenCourse = false

    // Persistence
    @AppStorage("hasCompletedGuidedOnboarding") var hasCompletedGuidedOnboarding = false

    private init() {}

    // MARK: - Lifecycle

    func startOnboarding() {
        guard !hasCompletedGuidedOnboarding else { return }
        guard !isActive else { return }

        isActive = true
        currentStep = .tutorial
        showCompactTutorial = true
    }

    func skipOnboarding() {
        completeOnboarding()
    }

    func completeOnboarding() {
        currentStep = .done
        isActive = false
        hasCompletedGuidedOnboarding = true
        showCompactTutorial = false
        spotlightFrame = .zero
        spotlightVisible = false
        requestedTabSwitch = nil
        requestAutoExpandFAB = false
        wizardTooltipStep = .none
        courseDetailTooltipStep = .none
        shouldAutoOpenCourse = false
        // Also mark the legacy tutorial as completed
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func resetOnboarding() {
        hasCompletedGuidedOnboarding = false
        currentStep = .inactive
        isActive = false
        spotlightFrame = .zero
        showCompactTutorial = false
        spotlightVisible = false
        requestedTabSwitch = nil
        requestAutoExpandFAB = false
        wizardTooltipStep = .none
        courseDetailTooltipStep = .none
        shouldAutoOpenCourse = false
    }

    // MARK: - Step Transitions

    /// Called when the 5-page compact tutorial finishes
    func completeCompactTutorial() {
        withAnimation(.easeOut(duration: 0.35)) {
            showCompactTutorial = false
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard isActive else { return }

            // Swipe to schedule tab
            requestedTabSwitch = 2

            try? await Task.sleep(nanoseconds: 500_000_000)
            guard isActive else { return }

            // Show the schedule intro card
            withAnimation(.easeInOut(duration: 0.4)) {
                currentStep = .scheduleIntro
            }
        }
    }

    /// "Next" tapped on the schedule intro card
    func advanceFromScheduleIntro() {
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = .highlightScheduleOption
        }

        Task { @MainActor in
            // Brief pause for the card dismiss animation, then expand the FAB
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard isActive, currentStep == .highlightScheduleOption else { return }
            requestAutoExpandFAB = true
            // The spotlight will appear automatically once the FAB expands
            // and the anchor preference reports the "Schedule" option's frame
        }
    }

    /// User tapped the "Schedule" option in the expanded FAB
    func userSelectedScheduleOption() {
        guard currentStep == .highlightScheduleOption else { return }

        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = .creatingSchedule
            spotlightFrame = .zero
            spotlightVisible = false
        }
    }

    /// Called when the schedule creation wizard sheet is dismissed
    func scheduleWizardDismissed() {
        guard currentStep == .creatingSchedule else { return }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard isActive else { return }

            // Show "Well Done" card and swipe to courses tab
            withAnimation(.easeInOut(duration: 0.4)) {
                currentStep = .scheduleComplete
            }

            try? await Task.sleep(nanoseconds: 300_000_000)
            requestedTabSwitch = 0 // Courses tab
        }
    }

    /// "Continue" tapped on the schedule complete card
    func advanceFromScheduleComplete() {
        // Switch to courses tab and trigger auto-open of first course
        shouldAutoOpenCourse = true
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep = .coursesTip
        }
    }

    /// "Got it" tapped on the courses tip card
    func advanceFromCoursesTip() {
        withAnimation(.easeOut(duration: 0.3)) {
            currentStep = .remindersTip
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            requestedTabSwitch = 3 // Reminders tab
        }
    }

    /// "Got it" tapped on the reminders tip card
    func advanceFromRemindersTip() {
        withAnimation(.easeInOut(duration: 0.4)) {
            currentStep = .complete
        }
    }

    /// "Finish" tapped on the completion card
    func finishOnboarding() {
        withAnimation(.easeOut(duration: 0.4)) {
            completeOnboarding()
        }
    }

    // MARK: - User Action Handlers

    /// Called when user taps the FAB button (legacy compatibility)
    func userTappedFAB() {
        // FAB is now auto-expanded during onboarding
    }

    /// Update the spotlight frame from anchor preferences
    func updateSpotlightFrame(_ frame: CGRect) {
        guard isActive, currentStep.spotlightAnchorID != nil else { return }
        if spotlightFrame != frame {
            spotlightFrame = frame
        }
    }

    // MARK: - Wizard Tooltip Methods

    /// Start showing wizard tooltips when wizard opens during onboarding
    func startWizardGuidance() {
        print("🎓 startWizardGuidance called — isActive: \(isActive), currentStep: \(currentStep)")
        guard isActive, currentStep == .creatingSchedule else {
            print("🎓 startWizardGuidance skipped — guard failed")
            return
        }
        print("🎓 Setting wizardTooltipStep = .nameIntro")
        wizardTooltipStep = .nameIntro
    }

    /// Map the wizard's current step to the appropriate tooltip
    func advanceWizardTooltip(to wizardStep: ScheduleCreationWizardView.WizardStep) {
        guard isActive, currentStep == .creatingSchedule else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            switch wizardStep {
            case .name:
                wizardTooltipStep = .nameIntro
            case .semesterDetails:
                wizardTooltipStep = .semesterTip
            case .academicCalendar:
                wizardTooltipStep = .calendarTip
            case .aiImport:
                wizardTooltipStep = .none
            case .review:
                wizardTooltipStep = .reviewTip
            }
        }
    }

    /// Dismiss all wizard tooltips
    func dismissWizardTooltips() {
        withAnimation(.easeOut(duration: 0.2)) {
            wizardTooltipStep = .none
        }
    }

    // MARK: - Course Detail Tooltip Methods

    /// Start showing course detail tooltips
    func startCourseDetailGuidance() {
        guard isActive else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            courseDetailTooltipStep = .gradesIntro
        }
    }

    /// Dismiss all course detail tooltips
    func dismissCourseDetailTooltips() {
        withAnimation(.easeOut(duration: 0.2)) {
            courseDetailTooltipStep = .done
            shouldAutoOpenCourse = false
        }
    }
}
