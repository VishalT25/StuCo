import SwiftUI

/// A floating tooltip banner for in-sheet onboarding guidance.
/// Renders directly — visibility is controlled by the parent modifier.
struct OnboardingTooltipBanner: View {
    let icon: String
    let text: String
    let accentColor: Color
    let onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28)

            Text(text)
                .font(.forma(.subheadline, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if onDismiss != nil {
                Button {
                    onDismiss?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.4),
                                    accentColor.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: accentColor.opacity(0.15), radius: 12, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        )
        .padding(.horizontal, 16)
    }
}

/// View modifier that manages showing/hiding an OnboardingTooltipBanner
/// with auto-dismiss after a specified delay.
struct OnboardingTooltipModifier: ViewModifier {
    let icon: String
    let text: String
    let accentColor: Color
    let isVisible: Bool
    let autoDismissDelay: TimeInterval
    let onDismiss: (() -> Void)?

    @State private var showBanner = false
    @State private var dismissTask: Task<Void, Never>?
    // Track the text so we can re-show when it changes
    @State private var currentText: String = ""

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if showBanner && !icon.isEmpty && !text.isEmpty {
                    OnboardingTooltipBanner(
                        icon: icon,
                        text: text,
                        accentColor: accentColor,
                        onDismiss: {
                            dismissBanner()
                            onDismiss?()
                        }
                    )
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .zIndex(999)
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showBanner)
            .onChange(of: isVisible) { _, newValue in
                handleVisibilityChange(newValue)
            }
            .onChange(of: text) { oldText, newText in
                // When tooltip text changes (wizard step changed), re-show banner
                if isVisible && !newText.isEmpty && newText != oldText {
                    dismissTask?.cancel()
                    // Brief hide then show for visual feedback
                    showBanner = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 200_000_000)
                        showBanner = true
                        scheduleAutoDismiss()
                    }
                }
            }
            .onAppear {
                // Handle case where isVisible is already true when view appears
                if isVisible && !icon.isEmpty && !text.isEmpty {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        showBanner = true
                        scheduleAutoDismiss()
                    }
                }
            }
    }

    private func handleVisibilityChange(_ visible: Bool) {
        dismissTask?.cancel()
        if visible && !icon.isEmpty && !text.isEmpty {
            showBanner = true
            scheduleAutoDismiss()
        } else {
            showBanner = false
        }
    }

    private func scheduleAutoDismiss() {
        guard autoDismissDelay > 0 else { return }
        dismissTask?.cancel()
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(autoDismissDelay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            dismissBanner()
        }
    }

    private func dismissBanner() {
        dismissTask?.cancel()
        showBanner = false
    }
}

extension View {
    /// Adds an onboarding tooltip banner overlay that slides in from the top.
    func onboardingTooltip(
        icon: String,
        text: String,
        accentColor: Color,
        isVisible: Bool,
        autoDismissDelay: TimeInterval = 0,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(OnboardingTooltipModifier(
            icon: icon,
            text: text,
            accentColor: accentColor,
            isVisible: isVisible,
            autoDismissDelay: autoDismissDelay,
            onDismiss: onDismiss
        ))
    }
}
