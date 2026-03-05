import SwiftUI

struct ExpandableFAB: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var onboardingManager: GuidedOnboardingManager
    @Environment(\.colorScheme) private var colorScheme

    let onCreateCourse: () -> Void
    let onCreateSchedule: () -> Void
    let includeCalendarButton: Bool
    let onCalendarTap: (() -> Void)?
    let isOnboardingTarget: Bool

    @State private var isExpanded = false

    init(
        onCreateCourse: @escaping () -> Void,
        onCreateSchedule: @escaping () -> Void,
        includeCalendarButton: Bool = false,
        onCalendarTap: (() -> Void)? = nil,
        isOnboardingTarget: Bool = false
    ) {
        self.onCreateCourse = onCreateCourse
        self.onCreateSchedule = onCreateSchedule
        self.includeCalendarButton = includeCalendarButton
        self.onCalendarTap = onCalendarTap
        self.isOnboardingTarget = isOnboardingTarget
    }

    var body: some View {
        VStack(spacing: 16) {
            // Calendar button (only in Schedule tab)
            if includeCalendarButton, let calendarAction = onCalendarTap {
                Button {
                    calendarAction()
                } label: {
                    Image(systemName: "calendar")
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.secondaryColor,
                                            themeManager.currentTheme.secondaryColor.opacity(0.8)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .shadow(color: themeManager.currentTheme.secondaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
                        )
                }
                .buttonStyle(MagicalButtonStyle())
            }

            // Expanded options
            if isExpanded {
                VStack(spacing: 12) {
                    // Create Schedule option
                    ExpandedFABOption(
                        icon: "calendar.badge.plus",
                        label: "Schedule",
                        color: themeManager.currentTheme.secondaryColor,
                        themeManager: themeManager
                    ) {
                        // Notify onboarding manager
                        onboardingManager.userSelectedScheduleOption()

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onCreateSchedule()
                        }
                    }
                    .ifOnboardingTarget(isOnboardingTarget, anchor: "fab-schedule")

                    // Create Course option
                    ExpandedFABOption(
                        icon: "book.closed.fill",
                        label: "Course",
                        color: themeManager.currentTheme.primaryColor.opacity(0.8),
                        themeManager: themeManager
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onCreateCourse()
                        }
                    }
                    .ifOnboardingTarget(isOnboardingTarget, anchor: "fab-course")
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity),
                    removal: .scale(scale: 0.8, anchor: .bottom).combined(with: .opacity)
                ))
            }

            // Main FAB button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()

                // Notify onboarding manager when FAB is tapped
                onboardingManager.userTappedFAB()

                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: isExpanded ? "xmark" : "plus")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.primaryColor,
                                            themeManager.currentTheme.secondaryColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [
                                            themeManager.currentTheme.darkModeAccentHue.opacity(0.6),
                                            Color.clear
                                        ],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: 40
                                    )
                                )
                                .opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity : 0.3)
                        }
                        .shadow(
                            color: themeManager.currentTheme.primaryColor.opacity(0.4),
                            radius: 20, x: 0, y: 10
                        )
                        .shadow(
                            color: themeManager.currentTheme.darkModeAccentHue.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.6 : 0.2),
                            radius: 12, x: 0, y: 6
                        )
                    )
                    .rotationEffect(.degrees(isExpanded ? 135 : 0))
            }
            .buttonStyle(MagicalButtonStyle())
            .ifOnboardingTarget(isOnboardingTarget, anchor: "fab-main")
        }
        .padding(.trailing, 24)
        .padding(.bottom, 32)
        // Auto-expand FAB when onboarding requests it (only for the onboarding target FAB)
        .onChange(of: onboardingManager.requestAutoExpandFAB) { _, shouldExpand in
            guard isOnboardingTarget, shouldExpand else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isExpanded = true
            }
            onboardingManager.requestAutoExpandFAB = false
        }
    }
}

// MARK: - Expanded Option Button

struct ExpandedFABOption: View {
    let icon: String
    let label: String
    let color: Color
    let themeManager: ThemeManager
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.forma(.body, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [color, color.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Text(label)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.trailing, 8)
            }
            .padding(.leading, 4)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: color.opacity(colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.2),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conditional Spotlight Anchor

private extension View {
    /// Only sets the spotlight anchor when this FAB is the onboarding target.
    /// Prevents duplicate anchors across tabs in PageTabViewStyle.
    @ViewBuilder
    func ifOnboardingTarget(_ isTarget: Bool, anchor id: String) -> some View {
        if isTarget {
            self.spotlightAnchor(id)
        } else {
            self
        }
    }
}

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                ExpandableFAB(
                    onCreateCourse: { print("Create Course") },
                    onCreateSchedule: { print("Create Schedule") },
                    includeCalendarButton: true,
                    onCalendarTap: { print("Calendar") }
                )
            }
        }
    }
    .environmentObject(ThemeManager())
    .environmentObject(GuidedOnboardingManager.shared)
}
