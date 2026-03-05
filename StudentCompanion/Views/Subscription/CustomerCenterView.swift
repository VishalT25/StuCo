import SwiftUI
import RevenueCat
import RevenueCatUI

/// RevenueCat Customer Center for managing subscriptions
struct StuCoCustomerCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        CustomerCenterView()
            .onCustomerCenterRestoreStarted {
                print("💰 Customer Center: Restore started")
            }
            .onCustomerCenterRestoreCompleted { customerInfo in
                print("💰 Customer Center: Restore completed")
                showRestoreAlert = true
                if customerInfo.entitlements["StuCo Pro"]?.isActive == true {
                    restoreMessage = "Successfully restored StuCo Pro subscription"
                } else {
                    restoreMessage = "No previous purchases found"
                }
            }
            .onCustomerCenterRefundRequestCompleted { productId, status in
                print("💰 Customer Center: Refund request completed for \(productId): \(status)")
            }
            .onCustomerCenterCustomActionSelected { actionId, purchaseId in
                print("💰 Customer Center: Custom action \(actionId) selected for purchase \(purchaseId ?? "unknown")")
            }
            .alert("Restore Purchases", isPresented: $showRestoreAlert) {
                Button("OK") {
                    showRestoreAlert = false
                }
            } message: {
                Text(restoreMessage)
            }
    }
}

/// Subscription management view with custom UI
struct SubscriptionManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var purchaseManager = PurchaseManager.shared

    @State private var showCustomerCenter = false
    @State private var showRestoreAlert = false
    @State private var restoreMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor
                    .ignoresSafeArea()

                if purchaseManager.isLoading {
                    ProgressView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Subscription status
                            subscriptionStatusSection

                            // Actions
                            actionsSection

                            // Subscription details
                            if purchaseManager.hasPro {
                                subscriptionDetailsSection
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCustomerCenter) {
                StuCoCustomerCenterView()
            }
            .alert("Restore Purchases", isPresented: $showRestoreAlert) {
                Button("OK") {
                    showRestoreAlert = false
                }
            } message: {
                Text(restoreMessage)
            }
        }
    }

    // MARK: - Subscription Status Section

    private var subscriptionStatusSection: some View {
        VStack(spacing: 16) {
            // Pro badge
            ZStack {
                Circle()
                    .fill(purchaseManager.hasPro ?
                        LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 100, height: 100)

                Image(systemName: purchaseManager.hasPro ? "star.fill" : "star")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }

            Text(purchaseManager.hasPro ? "StuCo Pro" : "Free Plan")
                .font(.title.weight(.bold))

            Text(purchaseManager.subscriptionStatusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 12) {
            if purchaseManager.hasPro {
                // Open Customer Center
                Button {
                    showCustomerCenter = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                        Text("Manage Subscription")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Restore purchases
            Button {
                Task {
                    let success = await purchaseManager.restorePurchases()
                    restoreMessage = success ?
                        "Successfully restored StuCo Pro subscription" :
                        "No previous purchases found"
                    showRestoreAlert = true
                }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Restore Purchases")
                    Spacer()
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }

    // MARK: - Subscription Details Section

    private var subscriptionDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription Details")
                .font(.headline)
                .padding(.bottom, 4)

            if let productID = purchaseManager.activeProductIdentifier {
                DetailRow(
                    title: "Plan",
                    value: planName(for: productID)
                )
            }

            if let expirationDate = purchaseManager.subscriptionExpirationDate {
                DetailRow(
                    title: purchaseManager.willRenew ? "Renews" : "Expires",
                    value: formatDate(expirationDate)
                )
            }

            DetailRow(
                title: "Auto-Renewal",
                value: purchaseManager.willRenew ? "On" : "Off"
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Helper Methods

    private func planName(for productID: String) -> String {
        if productID.contains("monthly") {
            return "Monthly"
        } else if productID.contains("yearly") {
            return "Yearly"
        } else if productID.contains("lifetime") {
            return "Lifetime"
        } else if productID.contains("three_month") {
            return "3 Months"
        } else {
            return "Pro"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var backgroundColor: Color {
        colorScheme == .dark ? Color.black : Color.white
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Previews

#Preview {
    SubscriptionManagementView()
}
