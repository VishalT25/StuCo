import SwiftUI
import RevenueCat

/// Example view demonstrating all RevenueCat subscription features
/// This view can be accessed from settings or used as a reference
struct SubscriptionExampleView: View {
    @EnvironmentObject var purchaseManager: PurchaseManager

    @State private var showPaywall = false
    @State private var showCustomerCenter = false
    @State private var showCustomPaywall = false

    var body: some View {
        NavigationStack {
            List {
                // Current Status Section
                Section("Current Status") {
                    HStack {
                        Text("Pro Status")
                        Spacer()
                        if purchaseManager.hasPro {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Active")
                                    .foregroundColor(.green)
                            }
                            .font(.subheadline.weight(.semibold))
                        } else {
                            Text("Free")
                                .foregroundColor(.secondary)
                        }
                    }

                    if purchaseManager.hasPro {
                        HStack {
                            Text("Subscription")
                            Spacer()
                            Text(purchaseManager.subscriptionStatusMessage)
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                    }

                    if let productID = purchaseManager.activeProductIdentifier {
                        HStack {
                            Text("Plan")
                            Spacer()
                            Text(productID.replacingOccurrences(of: "_", with: " ").capitalized)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Actions Section
                Section("Actions") {
                    // Show RevenueCat Paywall
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Show RevenueCat Paywall", systemImage: "dollarsign.circle")
                    }

                    // Show Custom Paywall
                    Button {
                        showCustomPaywall = true
                    } label: {
                        Label("Show Custom Paywall", systemImage: "star.circle")
                    }

                    // Manage Subscription
                    if purchaseManager.hasPro {
                        Button {
                            showCustomerCenter = true
                        } label: {
                            Label("Manage Subscription", systemImage: "gear")
                        }
                    }

                    // Restore Purchases
                    Button {
                        Task {
                            await purchaseManager.restorePurchases()
                        }
                    } label: {
                        Label("Restore Purchases", systemImage: "arrow.clockwise")
                    }
                    .disabled(purchaseManager.isLoading)

                    if purchaseManager.isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }

                // Available Products Section
                if !purchaseManager.availablePackages.isEmpty {
                    Section("Available Products") {
                        ForEach(purchaseManager.availablePackages, id: \.identifier) { package in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(packageName(package))
                                        .font(.headline)

                                    if let description = packageDescription(package) {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()

                                Text(purchaseManager.formattedPrice(for: package))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // Pro Features Example
                Section("Pro Features") {
                    NavigationLink {
                        ProFeatureGate(featureName: "Advanced Analytics") {
                            VStack {
                                Text("🎉 Premium Content Unlocked!")
                                    .font(.title)
                                Text("This is a pro-only feature")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .systemGroupedBackground))
                        }
                    } label: {
                        Label("Advanced Analytics (Pro)", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        ProFeatureGate(featureName: "Document Storage") {
                            VStack {
                                Text("📁 Document Storage")
                                    .font(.title)
                                Text("Upload and manage course documents")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(uiColor: .systemGroupedBackground))
                        }
                    } label: {
                        Label("Document Storage (Pro)", systemImage: "doc.fill")
                    }
                }

                // Info Section
                Section("Implementation") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This example demonstrates:")
                            .font(.subheadline.weight(.semibold))

                        FeatureItem("✓ Checking Pro status")
                        FeatureItem("✓ Showing paywalls")
                        FeatureItem("✓ Managing subscriptions")
                        FeatureItem("✓ Restoring purchases")
                        FeatureItem("✓ Listing products")
                        FeatureItem("✓ Gating pro features")
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        CodeExamplesView()
                    } label: {
                        Label("View Code Examples", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                }
            }
            .navigationTitle("Subscription Demo")
            .sheet(isPresented: $showPaywall) {
                StuCoPaywallView(isPresented: $showPaywall)
            }
            .sheet(isPresented: $showCustomPaywall) {
                CustomPaywallView(isPresented: $showCustomPaywall)
            }
            .sheet(isPresented: $showCustomerCenter) {
                SubscriptionManagementView()
            }
        }
    }

    private func packageName(_ package: Package) -> String {
        switch package.packageType {
        case .monthly: return "Monthly"
        case .annual: return "Yearly"
        case .lifetime: return "Lifetime"
        case .threeMonth: return "3 Months"
        default: return package.identifier
        }
    }

    private func packageDescription(_ package: Package) -> String? {
        switch package.packageType {
        case .annual: return "Save 40% compared to monthly"
        case .threeMonth: return "Save 20% compared to monthly"
        case .lifetime: return "One-time purchase"
        default: return nil
        }
    }
}

// MARK: - Feature Item

struct FeatureItem: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

// MARK: - Code Examples View

struct CodeExamplesView: View {
    var body: some View {
        List {
            Section("Check Pro Status") {
                CodeExample("""
                @EnvironmentObject var purchaseManager: PurchaseManager

                if purchaseManager.hasPro {
                    Text("Pro user!")
                }
                """)
            }

            Section("Show Paywall") {
                CodeExample("""
                @State private var showPaywall = false

                Button("Upgrade") {
                    showPaywall = true
                }
                .sheet(isPresented: $showPaywall) {
                    CustomPaywallView(isPresented: $showPaywall)
                }
                """)
            }

            Section("Gate Premium Feature") {
                CodeExample("""
                ProFeatureGate(featureName: "Analytics") {
                    AdvancedAnalyticsView()
                }
                """)
            }

            Section("Make Purchase") {
                CodeExample("""
                let success = await purchaseManager.purchase(
                    productIdentifier: "monthly"
                )
                """)
            }

            Section("Restore Purchases") {
                CodeExample("""
                let success = await purchaseManager.restorePurchases()
                """)
            }
        }
        .navigationTitle("Code Examples")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CodeExample: View {
    let code: String

    init(_ code: String) {
        self.code = code
    }

    var body: some View {
        Text(code)
            .font(.system(.caption, design: .monospaced))
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SubscriptionExampleView()
            .environmentObject(PurchaseManager.shared)
    }
}
