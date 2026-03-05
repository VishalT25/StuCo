import SwiftUI

struct TutorialPageView: View {
    let page: TutorialPage
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Visual placeholder
                page.visualType.makeVisual(theme: themeManager.currentTheme)
                    .scaleEffect(showContent ? 1.0 : 0.95)
                    .opacity(showContent ? 1.0 : 0.0)

                // Content section
                VStack(spacing: 24) {
                    // Headline
                    Text(page.headline)
                        .font(.forma(.title, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    // Premium badge (moved after headline)
                    if page.isPremium {
                        premiumBadge
                            .padding(.top, 4)
                    }

                    // Body text
                    Text(page.body)
                        .font(.forma(.body, weight: .regular))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .fixedSize(horizontal: false, vertical: true)

                    // Feature highlights
                    if let features = page.features {
                        featureList(features)
                    }
                }
                .padding(.horizontal, 40)
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)
            }
            .padding(.vertical, 40)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                showContent = true
            }
        }
        .onDisappear {
            showContent = false
        }
    }

    private var premiumBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10, weight: .bold))
            Text("PREMIUM")
                .font(.forma(.caption2, weight: .bold))
                .tracking(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.843, blue: 0.0), // Gold
                            Color(red: 1.0, green: 0.647, blue: 0.0)  // Orange
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: Color(red: 1.0, green: 0.843, blue: 0.0).opacity(0.5), radius: 8, x: 0, y: 2)
    }

    private func featureList(_ features: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(features, id: \.self) { feature in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                        .font(.system(size: 16))

                    Text(feature)
                        .font(.forma(.subheadline, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }
}

#Preview {
    TutorialPageView(page: TutorialPage.allPages[0])
        .environmentObject(ThemeManager())
        .preferredColorScheme(.dark)
        .background(Color.black)
}
