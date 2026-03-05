import SwiftUI

// MARK: - Guided Onboarding Overlay

struct GuidedOnboardingOverlay: View {
    @ObservedObject var onboardingManager: GuidedOnboardingManager
    @EnvironmentObject var themeManager: ThemeManager

    let spotlightAnchors: [String: CGRect]

    var body: some View {
        ZStack {
            // Phase 1: Tutorial carousel
            if onboardingManager.showCompactTutorial {
                CompactTutorialView(
                    isPresented: $onboardingManager.showCompactTutorial,
                    onComplete: {
                        onboardingManager.completeCompactTutorial()
                    },
                    onSkip: {
                        onboardingManager.skipOnboarding()
                    }
                )
                .environmentObject(themeManager)
                .transition(.opacity)
                .zIndex(1000)
            }

            // Phase 2: Guided tour overlay
            // For the spotlight step, only show once the spotlight frame is ready
            // so the user sees the FAB expand naturally before the overlay appears
            if onboardingManager.isActive && shouldShowGuidedOverlay {
                guidedOverlayContent
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .onChange(of: spotlightAnchors) { _, newAnchors in
            updateSpotlightFrame(from: newAnchors)
        }
        .onAppear {
            updateSpotlightFrame(from: spotlightAnchors)
        }
    }

    /// Whether the guided overlay should be visible right now.
    /// For the spotlight step, waits until the anchor frame is reported
    /// so the user naturally sees the FAB expanding.
    private var shouldShowGuidedOverlay: Bool {
        let step = onboardingManager.currentStep
        guard step.showsGuidedOverlay else { return false }
        if step == .highlightScheduleOption {
            return !onboardingManager.spotlightFrame.isEmpty
        }
        return true
    }

    // MARK: - Guided Overlay Content

    @ViewBuilder
    private var guidedOverlayContent: some View {
        GeometryReader { geometry in
            ZStack {
                // Background layer
                backgroundLayer

                // Content layer
                contentLayer(geometry: geometry)

                // Skip button (top-right)
                VStack {
                    HStack {
                        Spacer()
                        OnboardingSkipButton(onSkip: {
                            onboardingManager.skipOnboarding()
                        })
                        .environmentObject(themeManager)
                        .padding(.trailing, 16)
                        .padding(.top, geometry.safeAreaInsets.top + 8)
                    }
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Background Layer

    @ViewBuilder
    private var backgroundLayer: some View {
        let step = onboardingManager.currentStep
        let hasSpotlight = step == .highlightScheduleOption
            && !onboardingManager.spotlightFrame.isEmpty

        if hasSpotlight {
            // Spotlight overlay with cutout around the highlighted element
            ZStack {
                SpotlightOverlayView(
                    targetFrame: onboardingManager.spotlightFrame,
                    cornerRadius: 24
                )
                .environmentObject(themeManager)
                .allowsHitTesting(false)

                // Hit-test blocker: blocks taps outside spotlight, passes through inside
                SpotlightHitBlocker(
                    cutoutFrame: onboardingManager.spotlightFrame.insetBy(dx: -12, dy: -12),
                    cornerRadius: 32
                )
            }
            .transition(.opacity)
        } else {
            // Solid dimmed background for card steps (blocks all taps)
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {} // consume all taps
                .transition(.opacity)
        }
    }

    // MARK: - Content Layer

    @ViewBuilder
    private func contentLayer(geometry: GeometryProxy) -> some View {
        let step = onboardingManager.currentStep

        Group {
            switch step {
            case .scheduleIntro:
                OnboardingCard(
                    icon: "calendar.badge.plus",
                    iconColors: [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor
                    ],
                    title: "Let's Build Your Schedule",
                    message: "We'll walk you through creating your first schedule step by step.",
                    bulletPoints: nil,
                    buttonText: "Next",
                    action: { onboardingManager.advanceFromScheduleIntro() }
                )

            case .highlightScheduleOption:
                if !onboardingManager.spotlightFrame.isEmpty {
                    spotlightTooltipContent(geometry: geometry)
                }

            case .scheduleComplete:
                OnboardingCard(
                    icon: "checkmark.circle.fill",
                    iconColors: [.green, .mint],
                    title: "Nice Work!",
                    message: "Now let's explore a few more features that'll help you stay on top of everything.",
                    bulletPoints: nil,
                    buttonText: "Continue",
                    action: { onboardingManager.advanceFromScheduleComplete() }
                )

            case .coursesTip:
                OnboardingCard(
                    icon: "book.closed.fill",
                    iconColors: [.purple, .pink],
                    title: "Let's Explore Your Courses",
                    message: "We'll open your first course to show you the grade tracker and document storage.",
                    bulletPoints: [
                        "Track grades and calculate your GPA",
                        "See what you need on your final exam",
                        "Store syllabi and course documents"
                    ],
                    buttonText: "Show Me",
                    action: { onboardingManager.advanceFromCoursesTip() }
                )

            case .remindersTip:
                OnboardingCard(
                    icon: "star.fill",
                    iconColors: [.orange, .yellow],
                    title: "Reminders & Events",
                    message: "Never miss a deadline again.",
                    bulletPoints: [
                        "Create events, assignments, and deadlines",
                        "Set custom reminder notifications",
                        "Sync with Apple or Google Calendar in Settings"
                    ],
                    buttonText: "Got it",
                    action: { onboardingManager.advanceFromRemindersTip() }
                )

            case .complete:
                OnboardingCard(
                    icon: "sparkles",
                    iconColors: [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor
                    ],
                    title: "You're All Set!",
                    message: "That's the essentials. You can replay this tour anytime from Settings.",
                    bulletPoints: nil,
                    buttonText: "Let's Go",
                    action: { onboardingManager.finishOnboarding() }
                )

            default:
                EmptyView()
            }
        }
        .id(step.rawValue)
    }

    // MARK: - Spotlight Tooltip

    @ViewBuilder
    private func spotlightTooltipContent(geometry: GeometryProxy) -> some View {
        let frame = onboardingManager.spotlightFrame
        let tooltipWidth = min(300, geometry.size.width - 48)
        let safeTop = geometry.safeAreaInsets.top

        // Position tooltip above the spotlight target
        // The spotlight frame is in the full-screen coordinate space (ignoresSafeArea)
        let tooltipHeight: CGFloat = 200 // approximate height of tooltip card + arrow
        let desiredY = frame.minY - tooltipHeight / 2 - 30 // 30pt gap above spotlight
        let tooltipY = max(desiredY, safeTop + tooltipHeight / 2 + 16)

        // Horizontally align tooltip with the spotlight center, but clamp to screen
        let tooltipX = min(
            max(tooltipWidth / 2 + 16, frame.midX),
            geometry.size.width - tooltipWidth / 2 - 16
        )

        VStack(spacing: 12) {
            // Tooltip card
            VStack(alignment: .leading, spacing: 14) {
                Text("Ready to create your schedule?")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.white)

                Text("Make sure you have:")
                    .font(.forma(.subheadline))
                    .foregroundColor(.white.opacity(0.8))

                VStack(alignment: .leading, spacing: 10) {
                    tooltipBullet(icon: "doc.text.fill", text: "Schedule PDF, image or text")
                    tooltipBullet(icon: "calendar", text: "Academic calendar PDF or text (optional)")
                }
            }
            .padding(20)
            .frame(width: tooltipWidth)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor.opacity(0.5),
                                        themeManager.currentTheme.secondaryColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
            )

            // Animated arrow pointing down toward target
            BobbingArrow()
                .environmentObject(themeManager)
        }
        .position(x: tooltipX, y: tooltipY)
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func tooltipBullet(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(themeManager.currentTheme.primaryColor)
                .frame(width: 20)

            Text(text)
                .font(.forma(.subheadline))
                .foregroundColor(.white.opacity(0.85))
        }
    }

    // MARK: - Helpers

    private func updateSpotlightFrame(from anchors: [String: CGRect]) {
        guard let anchorID = onboardingManager.currentStep.spotlightAnchorID,
              let frame = anchors[anchorID] else { return }
        onboardingManager.updateSpotlightFrame(frame)
    }
}

// MARK: - Onboarding Card

struct OnboardingCard: View {
    let icon: String
    let iconColors: [Color]
    let title: String
    let message: String
    let bulletPoints: [String]?
    let buttonText: String
    let action: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon with layered circle background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColors.map { $0.opacity(0.12) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: iconColors.map { $0.opacity(0.22) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Text content
            VStack(spacing: 12) {
                Text(title)
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.forma(.body))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                if let bullets = bulletPoints {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(iconColors.first ?? .blue)
                                    .padding(.top, 2)

                                Text(bullet)
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.white.opacity(0.85))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 4)

            // Action button
            Button {
                let haptic = UIImpactFeedbackGenerator(style: .medium)
                haptic.impactOccurred()
                action()
            } label: {
                Text(buttonText)
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.primaryColor.opacity(0.85)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(
                        color: themeManager.currentTheme.primaryColor.opacity(0.4),
                        radius: 10, x: 0, y: 5
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(28)
        .frame(maxWidth: min(360, UIScreen.main.bounds.width - 48))
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.4),
                                    themeManager.currentTheme.secondaryColor.opacity(0.2),
                                    themeManager.currentTheme.primaryColor.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
        )
        .scaleEffect(appeared ? 1.0 : 0.92)
        .opacity(appeared ? 1.0 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }
}

// MARK: - Bobbing Arrow

struct BobbingArrow: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var bobbing = false

    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .shadow(
                color: themeManager.currentTheme.primaryColor.opacity(0.5),
                radius: 8, x: 0, y: 4
            )
            .offset(y: bobbing ? 8 : 0)
            .animation(
                .easeInOut(duration: 0.7).repeatForever(autoreverses: true),
                value: bobbing
            )
            .onAppear { bobbing = true }
    }
}

// MARK: - Spotlight Hit Blocker

/// Blocks taps everywhere except inside the spotlight cutout area.
/// Uses even-odd fill rule so the cutout region passes taps through to views below.
struct SpotlightHitBlocker: View {
    let cutoutFrame: CGRect
    let cornerRadius: CGFloat

    var body: some View {
        Color.clear
            .contentShape(
                SpotlightCutoutShape(
                    cutout: cutoutFrame,
                    cornerRadius: cornerRadius
                ),
                eoFill: true
            )
            .ignoresSafeArea()
            .onTapGesture {} // consume taps outside cutout
    }
}

struct SpotlightCutoutShape: Shape {
    let cutout: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: cutout,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )
        return path
    }
}

// MARK: - View Extension

extension View {
    func withGuidedOnboarding(
        manager: GuidedOnboardingManager,
        anchors: [String: CGRect]
    ) -> some View {
        self.overlay {
            GuidedOnboardingOverlay(
                onboardingManager: manager,
                spotlightAnchors: anchors
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(.systemBackground)
            .ignoresSafeArea()

        Text("App Content")
            .font(.largeTitle)
    }
    .overlay {
        let manager = GuidedOnboardingManager.shared
        GuidedOnboardingOverlay(
            onboardingManager: manager,
            spotlightAnchors: [:]
        )
        .onAppear {
            manager.resetOnboarding()
            manager.startOnboarding()
        }
    }
    .environmentObject(ThemeManager())
}
