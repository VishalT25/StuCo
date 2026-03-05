import SwiftUI

// MARK: - Compact Tutorial Page Data

struct CompactTutorialPage: Identifiable {
    let id: Int
    let icon: String
    let iconColors: [Color]
    let headline: String
    let body: String
    let isLast: Bool
}

// MARK: - Compact Tutorial View

struct CompactTutorialView: View {
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onSkip: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    @State private var currentPage: Int = 0

    private let haptic = UIImpactFeedbackGenerator(style: .light)

    private var pages: [CompactTutorialPage] {
        [
            CompactTutorialPage(
                id: 0,
                icon: "graduationcap.fill",
                iconColors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                headline: "Welcome to StuCo",
                body: "Your all-in-one academic companion. Let's get you set up.",
                isLast: false
            ),
            CompactTutorialPage(
                id: 1,
                icon: "calendar.badge.clock",
                iconColors: [.blue, .cyan],
                headline: "Your Schedule, Organized",
                body: "Create and manage your class schedule with ease. See all your classes at a glance.",
                isLast: false
            ),
            CompactTutorialPage(
                id: 2,
                icon: "star.fill",
                iconColors: [.orange, .yellow],
                headline: "Never Miss a Deadline",
                body: "Track assignments, exams, and events. Get reminders so you're always prepared.",
                isLast: false
            ),
            CompactTutorialPage(
                id: 3,
                icon: "book.closed.fill",
                iconColors: [.purple, .pink],
                headline: "All Your Courses",
                body: "Manage courses with multiple meeting times, track grades, and store documents.",
                isLast: false
            ),
            CompactTutorialPage(
                id: 4,
                icon: "sparkles",
                iconColors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.darkModeAccentHue],
                headline: "Ready to Start?",
                body: "Let's walk you through creating your first schedule. You can skip this anytime.",
                isLast: true
            )
        ]
    }

    var body: some View {
        ZStack {
            // Dark solid background for better text contrast
            Color.black
                .ignoresSafeArea()

            // Subtle gradient overlay for visual interest
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.03, green: 0.03, blue: 0.05),
                    themeManager.currentTheme.primaryColor.opacity(0.05),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with progress and skip
                headerView
                    .padding(.top, 8)

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        CompactTutorialPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    haptic.impactOccurred()
                }

                // Bottom button area
                bottomButtonArea
            }
        }
        .preferredColorScheme(.dark)
    }

    private var headerView: some View {
        HStack {
            Spacer()

            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(
                            index == currentPage
                                ? themeManager.currentTheme.primaryColor
                                : Color.white.opacity(0.3)
                        )
                        .frame(
                            width: index == currentPage ? 12 : 8,
                            height: index == currentPage ? 12 : 8
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: currentPage)
                }
            }

            Spacer()

            // Skip button
            Button {
                onSkip()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.15))
                    )
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var bottomButtonArea: some View {
        if let page = pages.first(where: { $0.id == currentPage }), page.isLast {
            Button {
                let mediumHaptic = UIImpactFeedbackGenerator(style: .medium)
                mediumHaptic.impactOccurred()
                onComplete()
            } label: {
                Text("Let's Go")
                    .font(.forma(.headline, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.primaryColor.opacity(0.8)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            // Next button for non-last pages
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if currentPage < pages.count - 1 {
                        currentPage += 1
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Next")
                        .font(.forma(.headline, weight: .semibold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    themeManager.currentTheme.primaryColor.opacity(0.8),
                                    themeManager.currentTheme.primaryColor.opacity(0.6)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Compact Tutorial Page View

struct CompactTutorialPageView: View {
    let page: CompactTutorialPage
    @State private var showContent = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.iconColors.map { $0.opacity(0.15) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 140, height: 140)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: page.iconColors.map { $0.opacity(0.25) },
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)

                Image(systemName: page.icon)
                    .font(.system(size: 50, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: page.iconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(showContent ? 1.0 : 0.8)
            .opacity(showContent ? 1.0 : 0.0)

            // Text content
            VStack(spacing: 16) {
                Text(page.headline)
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.forma(.body))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 40)
            .opacity(showContent ? 1.0 : 0.0)
            .offset(y: showContent ? 0 : 20)

            Spacer()
            Spacer()
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1)) {
                showContent = true
            }
        }
        .onDisappear {
            showContent = false
        }
    }
}

// MARK: - Preview

#Preview {
    CompactTutorialView(
        isPresented: .constant(true),
        onComplete: { print("Complete") },
        onSkip: { print("Skip") }
    )
    .environmentObject(ThemeManager())
}
