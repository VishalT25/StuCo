import Foundation
import SwiftUI
import RevenueCat
import Combine

/// Manages all RevenueCat subscription and purchase operations
@MainActor
final class PurchaseManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = PurchaseManager()

    // MARK: - Published Properties
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isProUser = false
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var subscriptionTier: SubscriptionTier = .free
    @Published private(set) var isFounder = false

    // MARK: - Configuration
    // RevenueCat API Keys
    private let productionAPIKey = "appl_RNVaWwGJZHMWrvyQTnznhoznmpS"
    private let sandboxAPIKey = "appl_RNVaWwGJZHMWrvyQTnznhoznmpS" // Using same key for both

    private var apiKey: String {
        #if DEBUG
        return sandboxAPIKey // Use sandbox in debug builds
        #else
        return productionAPIKey // Use production in release builds
        #endif
    }

    private let proEntitlementID = "StuCo Pro"

    // MARK: - Initialization
    private override init() {
        super.init()
        print("💰 PurchaseManager: Initializing...")
    }

    // MARK: - Configuration

    /// Configure RevenueCat with API key and user ID
    func configure(appUserID: String? = nil) {
        print("💰 PurchaseManager: Configuring RevenueCat...")

        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .info
        #endif

        Purchases.configure(
            withAPIKey: apiKey,
            appUserID: appUserID
        )

        // Set up customer info listener
        Purchases.shared.delegate = self

        print("💰 PurchaseManager: RevenueCat configured")

        // Fetch initial data
        Task {
            await fetchCustomerInfo()
            await fetchOfferings()
        }
    }

    // MARK: - Customer Info

    /// Fetch latest customer info from RevenueCat
    func fetchCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            await updateCustomerInfo(info)
            print("💰 PurchaseManager: Fetched customer info")
        } catch {
            print("💰 PurchaseManager: Failed to fetch customer info: \(error)")
            errorMessage = "Failed to load subscription status"
        }
    }

    /// Update customer info and entitlement status
    private func updateCustomerInfo(_ info: CustomerInfo) async {
        customerInfo = info
        isProUser = info.entitlements[proEntitlementID]?.isActive == true

        // Calculate subscription tier
        subscriptionTier = determineSubscriptionTier(from: info)
        isFounder = (subscriptionTier == .founder)

        // Sync tier to Supabase
        await syncTierToSupabase(tier: subscriptionTier, customerInfo: info)

        print("💰 PurchaseManager: Pro user: \(isProUser)")
        print("💰 PurchaseManager: Tier: \(subscriptionTier.displayName)")
        print("💰 PurchaseManager: Is Founder: \(isFounder)")
    }

    // MARK: - Tier Mapping

    /// Determine subscription tier from RevenueCat CustomerInfo
    func determineSubscriptionTier(from customerInfo: CustomerInfo) -> SubscriptionTier {
        // Check for active "StuCo Pro" entitlement
        guard let entitlement = customerInfo.entitlements[proEntitlementID],
              entitlement.isActive else {
            return .free
        }

        // Check if user is founder (special handling)
        if isFounderEntitlement(customerInfo) {
            return .founder
        }

        // Regular pro subscriber
        return .pro
    }

    /// Check if user has founder status
    private func isFounderEntitlement(_ customerInfo: CustomerInfo) -> Bool {
        // Check for founder-specific product identifiers
        guard let entitlement = customerInfo.entitlements[proEntitlementID] else {
            return false
        }

        // Option 1: Check product identifier for founder/lifetime keywords
        let founderProductIDs = ["founder", "lifetime"]
        if founderProductIDs.contains(where: { entitlement.productIdentifier.lowercased().contains($0) }) {
            return true
        }

        // Option 2: Check for lifetime period type (no expiration date)
        if entitlement.expirationDate == nil {
            // Lifetime access = founder
            return true
        }

        return false
    }

    /// Sync subscription tier to Supabase database
    private func syncTierToSupabase(tier: SubscriptionTier, customerInfo: CustomerInfo) async {
        guard let userId = SupabaseService.shared.currentUser?.id.uuidString else {
            print("💰 PurchaseManager: Cannot sync tier - no user ID")
            return
        }

        do {
            // Update subscriber record with new tier
            let subscriptionEnd = subscriptionEndDateString(from: customerInfo)

            struct SubscriberUpdate: Codable {
                let subscription_tier: String
                let role: String
                let subscribed: Bool
                let revenuecat_customer_id: String
                let last_entitlement_check: String
                let subscription_end: String?
                let updated_at: String
            }

            let update = SubscriberUpdate(
                subscription_tier: tier.rawValue,
                role: tier.rawValue,
                subscribed: tier.isPaidTier,
                revenuecat_customer_id: customerInfo.originalAppUserId,
                last_entitlement_check: ISO8601DateFormatter().string(from: Date()),
                subscription_end: subscriptionEnd,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )

            _ = try await SupabaseService.shared.client
                .from("subscribers")
                .update(update)
                .eq("user_id", value: userId)
                .execute()

            print("💰 PurchaseManager: Synced tier '\(tier.rawValue)' to Supabase")

        } catch {
            print("💰 PurchaseManager: Failed to sync tier to Supabase: \(error)")
        }
    }

    private func subscriptionEndDateString(from customerInfo: CustomerInfo) -> String? {
        guard let entitlement = customerInfo.entitlements[proEntitlementID],
              let expirationDate = entitlement.expirationDate else {
            // Lifetime access (no expiration)
            return nil
        }
        return ISO8601DateFormatter().string(from: expirationDate)
    }

    // MARK: - Offerings

    /// Fetch available offerings from RevenueCat
    func fetchOfferings() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fetchedOfferings = try await Purchases.shared.offerings()
            offerings = fetchedOfferings
            print("💰 PurchaseManager: Fetched \(fetchedOfferings.all.count) offerings")

            if let current = fetchedOfferings.current {
                print("💰 PurchaseManager: Current offering: \(current.identifier)")
                print("💰 PurchaseManager: Available packages: \(current.availablePackages.map { $0.identifier })")

                if current.availablePackages.isEmpty {
                    print("⚠️ PurchaseManager: WARNING - No packages in current offering!")
                    print("⚠️ PurchaseManager: Check that products are attached to packages in RevenueCat dashboard")
                }
            } else {
                print("⚠️ PurchaseManager: WARNING - No current offering set!")
                print("⚠️ PurchaseManager: Available offering IDs: \(fetchedOfferings.all.keys.joined(separator: ", "))")
            }
        } catch {
            print("💰 PurchaseManager: Failed to fetch offerings: \(error)")
            print("💰 PurchaseManager: Error details: \(String(describing: error))")
            errorMessage = "Failed to load subscription options"
        }
    }

    // MARK: - Purchase

    /// Purchase a specific package
    func purchase(_ package: Package) async -> Bool {
        logEvent("Purchase initiated", metadata: [
            "package": package.identifier,
            "product": package.storeProduct.productIdentifier,
            "price": package.storeProduct.localizedPriceString
        ])

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            await updateCustomerInfo(result.customerInfo)

            logEvent("Purchase successful", metadata: [
                "package": package.identifier,
                "tier": subscriptionTier.rawValue,
                "userCancelled": result.userCancelled
            ])

            // Check if user unlocked pro
            if result.customerInfo.entitlements[proEntitlementID]?.isActive == true {
                print("💰 PurchaseManager: User unlocked StuCo Pro!")
                return true
            }

            return false
        } catch {
            let mappedError = mapError(error)

            logEvent("Purchase failed", metadata: [
                "package": package.identifier,
                "error": mappedError.errorDescription ?? "unknown"
            ])

            if case .purchaseCancelled = mappedError {
                errorMessage = nil
            } else {
                errorMessage = mappedError.errorDescription
            }

            return false
        }
    }

    /// Purchase a product by identifier
    func purchase(productIdentifier: String) async -> Bool {
        guard let offerings = offerings,
              let package = offerings.current?.availablePackages.first(where: {
                  $0.storeProduct.productIdentifier == productIdentifier
              }) else {
            errorMessage = "Product not found"
            return false
        }

        return await purchase(package)
    }

    // MARK: - Restore

    /// Restore previous purchases
    func restorePurchases() async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            let info = try await Purchases.shared.restorePurchases()
            await updateCustomerInfo(info)

            print("💰 PurchaseManager: Restore successful")

            if info.entitlements[proEntitlementID]?.isActive == true {
                return true
            } else {
                errorMessage = "No previous purchases found"
                return false
            }
        } catch {
            print("💰 PurchaseManager: Restore failed: \(error)")
            errorMessage = "Failed to restore purchases"
            return false
        }
    }

    // MARK: - Entitlement Checking

    /// Check if user has active pro subscription
    var hasPro: Bool {
        return isProUser
    }

    /// Check if user has Pro access (includes both 'pro' and 'founder')
    var hasProAccess: Bool {
        return subscriptionTier.hasProAccess
    }

    /// Check if user is specifically a founder
    var hasFounderStatus: Bool {
        return subscriptionTier == .founder
    }

    /// Get human-readable tier description
    var tierDescription: String {
        switch subscriptionTier {
        case .free:
            return "Free Plan"
        case .premium:
            return "Premium (Legacy)"
        case .pro:
            return "StuCo Pro"
        case .founder:
            return "Founder Edition"
        }
    }

    /// Check specific entitlement
    func hasEntitlement(_ identifier: String) -> Bool {
        return customerInfo?.entitlements[identifier]?.isActive == true
    }

    /// Get active subscription
    var activeSubscription: EntitlementInfo? {
        return customerInfo?.entitlements[proEntitlementID]
    }

    /// Get subscription expiration date
    var subscriptionExpirationDate: Date? {
        return activeSubscription?.expirationDate
    }

    /// Check if subscription will renew
    var willRenew: Bool {
        return activeSubscription?.willRenew ?? false
    }

    /// Get product identifier for active subscription
    var activeProductIdentifier: String? {
        return activeSubscription?.productIdentifier
    }

    // MARK: - Product Info

    /// Get all available packages from current offering
    var availablePackages: [Package] {
        return offerings?.current?.availablePackages ?? []
    }

    /// Get package by identifier
    func package(withIdentifier identifier: String) -> Package? {
        return availablePackages.first { $0.identifier == identifier }
    }

    /// Get monthly package
    var monthlyPackage: Package? {
        return offerings?.current?.monthly
    }

    /// Get annual package
    var annualPackage: Package? {
        return offerings?.current?.annual
    }

    /// Get lifetime package
    var lifetimePackage: Package? {
        return offerings?.current?.lifetime
    }

    // MARK: - Helper Methods

    /// Clear error message
    func clearError() {
        errorMessage = nil
    }

    /// Sync user ID with RevenueCat
    func syncUserID(_ userID: String) async {
        do {
            let info = try await Purchases.shared.logIn(userID)
            await updateCustomerInfo(info.customerInfo)
            print("💰 PurchaseManager: Synced user ID: \(userID)")
        } catch {
            print("💰 PurchaseManager: Failed to sync user ID: \(error)")
        }
    }

    /// Log out current user (for anonymous users)
    func logOut() async {
        do {
            let info = try await Purchases.shared.logOut()
            await updateCustomerInfo(info)
            print("💰 PurchaseManager: Logged out user")
        } catch {
            print("💰 PurchaseManager: Failed to log out: \(error)")
        }
    }

    // MARK: - Error Handling

    /// Purchase error types with localized descriptions
    enum PurchaseError: LocalizedError {
        case notConfigured
        case networkError
        case purchaseCancelled
        case productNotFound
        case alreadyPurchased
        case receiptInvalid
        case unknown(Error)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "RevenueCat is not properly configured"
            case .networkError:
                return "Network error. Please check your connection and try again."
            case .purchaseCancelled:
                return nil // Don't show error for user cancellation
            case .productNotFound:
                return "Product not found. Please try again later."
            case .alreadyPurchased:
                return "You already own this subscription. Try restoring purchases."
            case .receiptInvalid:
                return "Receipt validation failed. Please contact support."
            case .unknown(let error):
                return "Purchase failed: \(error.localizedDescription)"
            }
        }
    }

    /// Map RevenueCat errors to PurchaseError
    private func mapError(_ error: Error) -> PurchaseError {
        if let rcError = error as? RevenueCat.ErrorCode {
            switch rcError {
            case .purchaseCancelledError:
                return .purchaseCancelled
            case .productAlreadyPurchasedError:
                return .alreadyPurchased
            case .networkError:
                return .networkError
            case .receiptAlreadyInUseError:
                return .receiptInvalid
            case .invalidReceiptError:
                return .receiptInvalid
            default:
                return .unknown(error)
            }
        }
        return .unknown(error)
    }

    /// Log event with metadata
    private func logEvent(_ event: String, metadata: [String: Any] = [:]) {
        var logMessage = "💰 PurchaseManager: \(event)"

        if !metadata.isEmpty {
            let metadataString = metadata.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            logMessage += " | \(metadataString)"
        }

        print(logMessage)

        // TODO: Add analytics logging here if needed
        // Analytics.logEvent(event, parameters: metadata)
    }
}

// MARK: - PurchasesDelegate

extension PurchaseManager: PurchasesDelegate {

    /// Called whenever new customer info is available
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            await updateCustomerInfo(customerInfo)
            print("💰 PurchaseManager: Received updated customer info")
        }
    }

    /// Called when user initiates a promoted purchase from App Store
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase makeDeferredPurchase: @escaping StartPurchaseBlock) {
        print("💰 PurchaseManager: Ready for promoted product: \(product.productIdentifier)")

        // Execute the purchase
        makeDeferredPurchase { transaction, customerInfo, error, userCancelled in
            if let error = error {
                print("💰 PurchaseManager: Promoted purchase failed: \(error)")
                return
            }

            if userCancelled {
                print("💰 PurchaseManager: User cancelled promoted purchase")
                return
            }

            if let customerInfo = customerInfo {
                Task { @MainActor [weak self] in
                    await self?.updateCustomerInfo(customerInfo)
                    print("💰 PurchaseManager: Promoted purchase successful")
                }
            }
        }
    }
}

// MARK: - Formatted Strings

extension PurchaseManager {

    /// Get formatted price for a package
    func formattedPrice(for package: Package) -> String {
        return package.storeProduct.localizedPriceString
    }

    /// Get subscription status message
    var subscriptionStatusMessage: String {
        guard let subscription = activeSubscription else {
            return "No active subscription"
        }

        if let expirationDate = subscription.expirationDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium

            if subscription.willRenew {
                return "Renews on \(formatter.string(from: expirationDate))"
            } else {
                return "Expires on \(formatter.string(from: expirationDate))"
            }
        }

        return "Active subscription"
    }
}
