import SwiftUI
import RevenueCat
import RevenueCatUI

/// View modifier for presenting paywall if user doesn't have required entitlement
struct PaywallIfNeededModifier: ViewModifier {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Binding var isPresented: Bool

    let requiredEntitlement: String
    let onPurchaseCompleted: ((CustomerInfo) -> Void)?
    let onRestoreCompleted: ((CustomerInfo) -> Void)?

    func body(content: Content) -> some View {
        content
            .presentPaywallIfNeeded(
                requiredEntitlementIdentifier: requiredEntitlement,
                purchaseCompleted: { customerInfo in
                    onPurchaseCompleted?(customerInfo)
                },
                restoreCompleted: { customerInfo in
                    onRestoreCompleted?(customerInfo)
                }
            )
    }
}

/// View modifier for presenting custom paywall manually
struct CustomPaywallModifier: ViewModifier {
    @Binding var isPresented: Bool

    let onPurchaseCompleted: ((CustomerInfo) -> Void)?
    let onRestoreCompleted: ((CustomerInfo) -> Void)?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                CustomPaywallView(
                    isPresented: $isPresented
                )
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Automatically present RevenueCat paywall if entitlement is not active
    func presentPaywallIfNeeded(
        isPresented: Binding<Bool>,
        requiredEntitlement: String = "StuCo Pro",
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil,
        onRestoreCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> some View {
        modifier(PaywallIfNeededModifier(
            isPresented: isPresented,
            requiredEntitlement: requiredEntitlement,
            onPurchaseCompleted: onPurchaseCompleted,
            onRestoreCompleted: onRestoreCompleted
        ))
    }

    /// Present custom paywall view
    func customPaywall(
        isPresented: Binding<Bool>,
        onPurchaseCompleted: ((CustomerInfo) -> Void)? = nil,
        onRestoreCompleted: ((CustomerInfo) -> Void)? = nil
    ) -> some View {
        modifier(CustomPaywallModifier(
            isPresented: isPresented,
            onPurchaseCompleted: onPurchaseCompleted,
            onRestoreCompleted: onRestoreCompleted
        ))
    }

    /// Check if user has pro entitlement before performing action
    func requiresPro(
        showPaywall: Binding<Bool>,
        perform action: @escaping () -> Void
    ) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                if PurchaseManager.shared.hasPro {
                    action()
                } else {
                    showPaywall.wrappedValue = true
                }
            }
        )
    }
}

// MARK: - Pro Feature Gate View

/// View that shows content only if user has Pro, otherwise shows upgrade prompt
struct ProFeatureGate<Content: View>: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @State private var showPaywall = false

    let content: () -> Content
    let featureName: String
    let requiredTier: SubscriptionTier?

    init(
        featureName: String,
        requiredTier: SubscriptionTier? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.featureName = featureName
        self.requiredTier = requiredTier
        self.content = content
    }

    var body: some View {
        Group {
            if hasAccess {
                content()
            } else {
                lockedFeatureView
            }
        }
        .sheet(isPresented: $showPaywall) {
            CustomPaywallView(isPresented: $showPaywall)
        }
    }

    private var hasAccess: Bool {
        if let required = requiredTier {
            return purchaseManager.subscriptionTier.priority >= required.priority
        }
        return purchaseManager.hasProAccess
    }

    private var lockedFeatureView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("\(featureName) is a Pro Feature")
                .font(.title2.weight(.bold))

            if let required = requiredTier {
                Text("Requires \(required.displayName) tier or higher")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Upgrade to StuCo Pro to unlock this feature")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showPaywall = true
            } label: {
                Text("Upgrade to Pro")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: 300)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Pro Badge View

/// Badge showing Pro status
struct ProBadge: View {
    @StateObject private var purchaseManager = PurchaseManager.shared

    var body: some View {
        if purchaseManager.subscriptionTier.isPaidTier {
            HStack(spacing: 4) {
                Image(systemName: badgeIcon)
                    .font(.caption2)

                Text(badgeText)
                    .font(.caption2.weight(.bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeGradient)
            .cornerRadius(6)
        }
    }

    private var badgeIcon: String {
        switch purchaseManager.subscriptionTier {
        case .founder:
            return "crown.fill"
        default:
            return "star.fill"
        }
    }

    private var badgeText: String {
        switch purchaseManager.subscriptionTier {
        case .founder:
            return "FOUNDER"
        case .pro, .premium:
            return "PRO"
        default:
            return ""
        }
    }

    private var badgeGradient: LinearGradient {
        switch purchaseManager.subscriptionTier {
        case .founder:
            return LinearGradient(
                colors: [.purple, .pink],
                startPoint: .leading,
                endPoint: .trailing
            )
        default:
            return LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Previews

#Preview("Locked Feature") {
    ProFeatureGate(featureName: "Advanced Analytics") {
        Text("Premium content here")
    }
}

#Preview("Pro Badge") {
    ProBadge()
}
