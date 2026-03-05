import SwiftUI
import RevenueCat
import RevenueCatUI

/// RevenueCat Paywall view for subscription management
struct StuCoPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Binding var isPresented: Bool

    var onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil
    var onRestoreCompleted: ((CustomerInfo) -> Void)? = nil

    var body: some View {
        PaywallView()
            .onPurchaseCompleted { customerInfo in
                print("💰 Paywall: Purchase completed")
                onPurchaseCompleted?(customerInfo)
                isPresented = false
            }
            .onRestoreCompleted { customerInfo in
                print("💰 Paywall: Restore completed")
                onRestoreCompleted?(customerInfo)
                if customerInfo.entitlements["StuCo Pro"]?.isActive == true {
                    isPresented = false
                }
            }
            .onPurchaseCancelled {
                print("💰 Paywall: Purchase cancelled")
            }
            .onRestoreStarted {
                print("💰 Paywall: Restore started")
            }
            .onRestoreFailure { error in
                print("💰 Paywall: Restore failed: \(error)")
            }
    }
}

/// Custom paywall matching StuCo's design language
struct CustomPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Binding var isPresented: Bool

    @State private var selectedPackage: Package?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var showContent = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3

    private var theme: AppTheme { themeManager.currentTheme }
    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        ZStack {
            // Background
            backgroundView

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    closeButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Hero section
                        heroSection

                        // Features
                        featuresGrid

                        // Packages
                        packagesSection

                        // CTA
                        ctaSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { purchaseManager.clearError() }
        } message: {
            if let error = purchaseManager.errorMessage {
                Text(error)
            }
        }
        .onChange(of: purchaseManager.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.08
                glowOpacity = 0.6
            }
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
        ZStack {
            (isDark ? Color.black : Color(.systemBackground))
                .ignoresSafeArea()

            // Gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.primaryColor.opacity(isDark ? 0.2 : 0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -200)
                .blur(radius: 60)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.secondaryColor.opacity(isDark ? 0.15 : 0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 350, height: 350)
                .offset(x: 120, y: 300)
                .blur(radius: 50)
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            isPresented = false
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(theme.primaryColor.opacity(0.2), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Animated icon with glow
            ZStack {
                // Glow effect
                Circle()
                    .fill(theme.primaryColor.opacity(glowOpacity * 0.5))
                    .frame(width: 100, height: 100)
                    .blur(radius: 30)
                    .scaleEffect(pulseScale)

                // Icon background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.primaryColor.opacity(0.25),
                                theme.secondaryColor.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        theme.primaryColor.opacity(0.5),
                                        theme.secondaryColor.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .scaleEffect(pulseScale)

                Image(systemName: "crown.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primaryColor, theme.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Upgrade to Pro")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isDark
                                ? [theme.darkModeAccentHue, theme.darkModeHue]
                                : [theme.primaryColor, theme.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Unlock the full potential of your academic journey")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.top, 8)
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : -30)
        .animation(.easeOut(duration: 0.6), value: showContent)
    }

    // MARK: - Features Grid

    private var featuresGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            FeatureCard(
                icon: "wand.and.stars",
                title: "AI Imports",
                description: "Unlimited schedule imports",
                theme: theme,
                isDark: isDark
            )

            FeatureCard(
                icon: "paintpalette.fill",
                title: "Themes",
                description: "Exclusive premium themes",
                theme: theme,
                isDark: isDark
            )

            FeatureCard(
                icon: "doc.text.fill",
                title: "Documents",
                description: "Upgraded storage",
                theme: theme,
                isDark: isDark
            )

            FeatureCard(
                icon: "chart.bar.fill",
                title: "Analytics",
                description: "Advanced insights",
                theme: theme,
                isDark: isDark
            )
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: showContent)
    }

    // MARK: - Packages Section

    private var packagesSection: some View {
        VStack(spacing: 12) {
            if purchaseManager.availablePackages.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(theme.primaryColor)
                    Text("Loading plans...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(height: 140)
            } else {
                ForEach(purchaseManager.availablePackages.sorted { p1, p2 in
                    let order: [PackageType: Int] = [.annual: 0, .monthly: 1, .lifetime: 2]
                    return (order[p1.packageType] ?? 3) < (order[p2.packageType] ?? 3)
                }, id: \.identifier) { package in
                    PackageCard(
                        package: package,
                        isSelected: selectedPackage?.identifier == package.identifier,
                        theme: theme,
                        isDark: isDark
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPackage = package
                        }
                    }
                }
            }
        }
        .opacity(showContent ? 1 : 0)
        .offset(y: showContent ? 0 : 30)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: showContent)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 16) {
            // Purchase button
            Button {
                Task {
                    guard let package = selectedPackage else { return }
                    isPurchasing = true
                    let success = await purchaseManager.purchase(package)
                    isPurchasing = false
                    if success {
                        isPresented = false
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if isPurchasing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "lock.open.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Continue")
                            .font(.system(size: 17, weight: .bold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    Group {
                        if selectedPackage != nil {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [theme.primaryColor, theme.secondaryColor],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(
                                    color: theme.primaryColor.opacity(isDark ? 0.5 : 0.3),
                                    radius: 12,
                                    x: 0,
                                    y: 6
                                )
                        } else {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.secondary.opacity(0.3))
                        }
                    }
                )
            }
            .disabled(selectedPackage == nil || isPurchasing)

            // Restore + Terms
            VStack(spacing: 10) {
                Button {
                    Task {
                        let success = await purchaseManager.restorePurchases()
                        if success { isPresented = false }
                    }
                } label: {
                    Text("Restore Purchases")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(theme.primaryColor)
                }

                Text("Auto-renews until cancelled · [Terms](https://www.stuco.app/terms) · [Privacy](https://www.stuco.app/privacy)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .tint(theme.primaryColor)
            }
        }
        .opacity(showContent ? 1 : 0)
        .animation(.easeOut(duration: 0.6).delay(0.3), value: showContent)
    }
}

// MARK: - Feature Card

private struct FeatureCard: View {
    let icon: String
    let title: String
    let description: String
    let theme: AppTheme
    let isDark: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.primaryColor, theme.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.primaryColor.opacity(isDark ? 0.2 : 0.12))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.primaryColor.opacity(isDark ? 0.3 : 0.15),
                                    theme.secondaryColor.opacity(isDark ? 0.2 : 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - Package Card

private struct PackageCard: View {
    let package: Package
    let isSelected: Bool
    let theme: AppTheme
    let isDark: Bool
    let onTap: () -> Void

    private var isAnnual: Bool { package.packageType == .annual }
    private var isLifetime: Bool { package.packageType == .lifetime }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(
                            isSelected
                                ? LinearGradient(colors: [theme.primaryColor, theme.secondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing)
                                : LinearGradient(colors: [Color.secondary.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)

                    if isSelected {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [theme.primaryColor, theme.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 12, height: 12)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(packageTitle)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)

                        if isAnnual {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.green, Color.green.opacity(0.8)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }

                        if isLifetime {
                            Text("FOREVER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [theme.primaryColor, theme.secondaryColor],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                )
                        }
                    }

                    if let subtitle = packageSubtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(theme.primaryColor)
                    }
                }

                Spacer()

                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    Text(package.storeProduct.localizedPriceString)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    if let period = periodText {
                        Text(period)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        isSelected
                            ? theme.primaryColor.opacity(isDark ? 0.15 : 0.08)
                            : Color.secondary.opacity(isDark ? 0.08 : 0.04)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isSelected
                                    ? LinearGradient(
                                        colors: [theme.primaryColor, theme.secondaryColor],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Color.secondary.opacity(0.2)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
                    .shadow(
                        color: isSelected ? theme.primaryColor.opacity(isDark ? 0.3 : 0.15) : .clear,
                        radius: isSelected ? 10 : 0,
                        x: 0,
                        y: isSelected ? 4 : 0
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var packageTitle: String {
        switch package.packageType {
        case .monthly: return "Monthly"
        case .annual: return "Yearly"
        case .lifetime: return "Lifetime"
        case .threeMonth: return "3 Months"
        case .sixMonth: return "6 Months"
        default: return package.identifier.capitalized
        }
    }

    private var packageSubtitle: String? {
        switch package.packageType {
        case .annual: return "Save 40% compared to monthly"
        case .lifetime: return "One-time purchase, forever access"
        default: return nil
        }
    }

    private var periodText: String? {
        switch package.packageType {
        case .monthly: return "per month"
        case .annual: return "per year"
        default: return nil
        }
    }
}

// MARK: - Preview

#Preview {
    CustomPaywallView(isPresented: .constant(true))
        .environmentObject(ThemeManager())
}
