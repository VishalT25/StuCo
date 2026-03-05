import SwiftUI
import GoogleSignIn
import GoogleAPIClientForREST_Calendar

struct GoogleCalendarSettingsView: View {
    @EnvironmentObject var calendarSyncManager: CalendarSyncManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var animationOffset: CGFloat = 0
    @State private var pulseAnimation: Double = 1.0
    @State private var showContent = false

    private var currentTheme: AppTheme {
        themeManager.currentTheme
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Spectacular animated background
                spectacularBackground

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        if calendarSyncManager.googleCalendarManager.isSignedIn {
                            signedInContent
                        } else {
                            signedOutContent
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.forma(.body, weight: .semibold))
                        Text("Back")
                            .font(.forma(.body, weight: .medium))
                    }
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                currentTheme.primaryColor,
                                currentTheme.secondaryColor
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .padding(.leading, 20)
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            startAnimations()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
    }

    // MARK: - Signed Out Content

    private var signedOutContent: some View {
        VStack(spacing: 32) {
            // Hero Section
            VStack(spacing: 16) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    currentTheme.primaryColor.opacity(0.2),
                                    currentTheme.secondaryColor.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 80
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation)

                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor,
                                    currentTheme.secondaryColor
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .padding(.top, 40)

                VStack(spacing: 12) {
                    Text("Connect Google Calendar")
                        .font(.forma(.title, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    currentTheme.primaryColor,
                                    currentTheme.secondaryColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)

                    Text("Sync your academic events, assignments, and calendar breaks with Google Calendar for seamless cross-platform access")
                        .font(.forma(.subheadline))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 8)
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor.opacity(0.3),
                                        currentTheme.secondaryColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: currentTheme.primaryColor.opacity(
                            colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15
                        ),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )

            // Features
            VStack(spacing: 16) {
                GoogleCalendarFeatureItem(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Two-Way Sync",
                    description: "Keep everything in sync across all your devices",
                    color: currentTheme.primaryColor
                )

                GoogleCalendarFeatureItem(
                    icon: "bell.badge.fill",
                    title: "Smart Reminders",
                    description: "Get notified on all platforms with Google Calendar",
                    color: currentTheme.secondaryColor
                )

                GoogleCalendarFeatureItem(
                    icon: "calendar.badge.checkmark",
                    title: "Auto Updates",
                    description: "Changes sync automatically in real-time",
                    color: currentTheme.primaryColor.opacity(0.8)
                )
            }

            // Sign In Button
            Button {
                if let topVC = UIApplication.getTopViewController() {
                    calendarSyncManager.googleCalendarManager.signIn(presentingViewController: topVC)
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 24, height: 24)

                        Image(systemName: "link")
                            .font(.forma(.body, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("Sign In with Google")
                        .font(.forma(.headline, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 18)
                .background(
                    ZStack {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: animationOffset * 0.5 - 50)
                            .mask(Capsule())
                    }
                    .shadow(
                        color: currentTheme.primaryColor.opacity(0.5),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                    .overlay(
                        Capsule()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                    )
                )
            }
            .buttonStyle(GoogleCalendarButtonStyle())
        }
    }

    // MARK: - Signed In Content

    private var signedInContent: some View {
        VStack(spacing: 24) {
            // User Profile Card
            if let profile = calendarSyncManager.googleCalendarManager.userProfile {
                VStack(spacing: 16) {
                    // Profile Image and Info
                    VStack(spacing: 12) {
                        if let imageURL = profile.imageURL(withDimension: 100) {
                            AsyncImage(url: imageURL) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                ProgressView()
                                    .tint(currentTheme.primaryColor)
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                currentTheme.primaryColor,
                                                currentTheme.secondaryColor
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(
                                color: currentTheme.primaryColor.opacity(0.3),
                                radius: 10,
                                x: 0,
                                y: 5
                            )
                        }

                        VStack(spacing: 4) {
                            Text(profile.name ?? "Unknown User")
                                .font(.forma(.title3, weight: .bold))
                                .foregroundColor(.primary)

                            if !profile.email.isEmpty {
                                Text(profile.email)
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Connected badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)

                            Text("Connected")
                                .font(.forma(.caption, weight: .semibold))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            currentTheme.primaryColor.opacity(0.3),
                                            currentTheme.secondaryColor.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                        )
                        .shadow(
                            color: currentTheme.primaryColor.opacity(
                                colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15
                            ),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                )
            }

            // Calendar Selection Card
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sync Calendars")
                            .font(.forma(.title3, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Select which calendars to sync with StuCo")
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        calendarSyncManager.googleCalendarManager.loadCalendarList()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.forma(.body, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor,
                                        currentTheme.secondaryColor
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(10)
                            .background(
                                Circle()
                                    .fill(currentTheme.primaryColor.opacity(0.15))
                            )
                    }
                }

                // Calendar List
                if calendarSyncManager.googleCalendarManager.isLoadingCalendars {
                    HStack(spacing: 12) {
                        ProgressView()
                            .tint(currentTheme.primaryColor)
                        Text("Loading calendars...")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else if calendarSyncManager.googleCalendarManager.fetchedCalendars.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No calendars found")
                            .font(.forma(.subheadline))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    VStack(spacing: 12) {
                        ForEach(calendarSyncManager.googleCalendarManager.fetchedCalendars, id: \.identifier) { calendar in
                            let calendarId = calendar.identifier ?? ""
                            if !calendarId.isEmpty {
                                CalendarRow(
                                    calendar: calendar,
                                    calendarId: calendarId,
                                    isSelected: calendarSyncManager.googleCalendarManager.selectedCalendarIDs.contains(calendarId),
                                    themeColor: currentTheme.primaryColor
                                ) { isSelected in
                                    if isSelected {
                                        calendarSyncManager.googleCalendarManager.selectedCalendarIDs.insert(calendarId)
                                    } else {
                                        calendarSyncManager.googleCalendarManager.selectedCalendarIDs.remove(calendarId)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        currentTheme.primaryColor.opacity(0.3),
                                        currentTheme.secondaryColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: currentTheme.primaryColor.opacity(
                            colorScheme == .dark ? themeManager.darkModeHueIntensity * 0.3 : 0.15
                        ),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )

            // Sign Out Button
            Button {
                calendarSyncManager.googleCalendarManager.signOut()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.forma(.body, weight: .semibold))

                    Text("Sign Out")
                        .font(.forma(.body, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.red, Color.red.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(
                            color: Color.red.opacity(0.3),
                            radius: 12,
                            x: 0,
                            y: 6
                        )
                )
            }
            .buttonStyle(GoogleCalendarButtonStyle())
        }
    }

    // MARK: - Spectacular Background

    private var spectacularBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    currentTheme.primaryColor.opacity(colorScheme == .dark ? 0.12 : 0.04),
                    currentTheme.secondaryColor.opacity(colorScheme == .dark ? 0.08 : 0.02),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating shapes
            ForEach(0..<6, id: \.self) { index in
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                currentTheme.primaryColor.opacity(0.08 - Double(index) * 0.01),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60 + CGFloat(index * 15)
                        )
                    )
                    .frame(
                        width: 100 + CGFloat(index * 25),
                        height: 100 + CGFloat(index * 25)
                    )
                    .offset(
                        x: sin(animationOffset * 0.008 + Double(index) * 0.5) * 60,
                        y: cos(animationOffset * 0.006 + Double(index) * 0.3) * 40
                    )
                    .blur(radius: CGFloat(index * 2 + 1))
            }
        }
    }

    // MARK: - Helper Methods

    private func startAnimations() {
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            animationOffset = 360
        }

        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.1
        }
    }
}

// MARK: - Google Calendar Feature Item

struct GoogleCalendarFeatureItem: View {
    let icon: String
    let title: String
    let description: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.forma(.title2, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.3), lineWidth: 1)
                        )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.forma(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.forma(.caption))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Calendar Row

struct CalendarRow: View {
    let calendar: GTLRCalendar_CalendarListEntry
    let calendarId: String
    let isSelected: Bool
    let themeColor: Color
    let onToggle: (Bool) -> Void

    var body: some View {
        Button {
            onToggle(!isSelected)
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                ZStack {
                    Circle()
                        .stroke(isSelected ? themeColor : Color.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(themeColor)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.forma(.caption, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(calendar.summary ?? "Unnamed Calendar")
                        .font(.forma(.body, weight: .medium))
                        .foregroundColor(.primary)

                    if let description = calendar.descriptionProperty, !description.isEmpty {
                        Text(description)
                            .font(.forma(.caption))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? themeColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? themeColor.opacity(0.3) : Color.secondary.opacity(0.15),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Google Calendar Button Style

struct GoogleCalendarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.9), value: configuration.isPressed)
    }
}
