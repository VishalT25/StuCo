import SwiftUI
import RevenueCat
import RevenueCatUI

struct AccountManagementView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sizeCategory) private var sizeCategory

    @State private var showingChangePassword = false
    @State private var showingChangeEmail = false
    @State private var showingEditDisplayName = false
    @State private var showingPaywall = false
    @State private var isRestoringPurchases = false
    @State private var restoreMessage: String?
    @State private var showingRestoreAlert = false
    @State private var showingCancelConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    
    var body: some View {
        GeometryReader { geometry in
            NavigationView {
                List {
                    Section {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(subscriptionGradient)
                                    .frame(width: 56, height: 56)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(displayName)
                                        .font(.forma(.title3, weight: .bold))
                                    
                                    Text(subscriptionDisplayName)
                                        .font(.forma(.caption, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(subscriptionColor.opacity(0.2))
                                        .foregroundColor(subscriptionColor)
                                        .clipShape(Capsule())
                                }
                                
                                Text(supabaseService.currentUser?.email ?? "")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.secondary)

                                // Show subscription status from RevenueCat
                                if purchaseManager.hasProAccess {
                                    if let expirationDate = purchaseManager.subscriptionExpirationDate {
                                        Text(purchaseManager.willRenew ? "Renews" : "Expires" + " \(expirationDate.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.forma(.caption))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Lifetime Access")
                                            .font(.forma(.caption))
                                            .foregroundColor(subscriptionColor)
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Section(header: Text("Account Settings").font(.forma(.footnote, weight: .medium))) {
                        Button {
                            showingEditDisplayName = true
                        } label: {
                            SettingsRow(icon: "person.fill", iconColor: .purple, title: "Display Name", subtitle: displayName)
                        }
                        
                        Button {
                            showingChangeEmail = true
                        } label: {
                            SettingsRow(icon: "envelope.fill", iconColor: .blue, title: "Change Email", subtitle: "Update your email address")
                        }
                        
                        Button {
                            showingChangePassword = true
                        } label: {
                            SettingsRow(icon: "key.fill", iconColor: .orange, title: "Change Password", subtitle: "Update your password")
                        }
                    }
                    
                    Section(header: Text("Subscription").font(.forma(.footnote, weight: .medium))) {
                        // Subscription Status Card
                        VStack(spacing: 16) {
                            // Tier Badge and Info
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(subscriptionGradient)
                                        .frame(width: 60, height: 60)

                                    Image(systemName: purchaseManager.subscriptionTier.icon)
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(purchaseManager.tierDescription)
                                            .font(.forma(.headline, weight: .bold))

                                        ProBadge()
                                    }

                                    if purchaseManager.hasProAccess {
                                        if let expirationDate = purchaseManager.subscriptionExpirationDate {
                                            Text((purchaseManager.willRenew ? "Renews " : "Expires ") + expirationDate.formatted(date: .abbreviated, time: .omitted))
                                                .font(.forma(.subheadline))
                                                .foregroundColor(.secondary)
                                        } else {
                                            HStack(spacing: 4) {
                                                Image(systemName: "infinity")
                                                    .font(.forma(.caption))
                                                Text("Lifetime Access")
                                                    .font(.forma(.subheadline))
                                            }
                                            .foregroundColor(purchaseManager.subscriptionTier.color)
                                        }

                                        if let productID = purchaseManager.activeProductIdentifier {
                                            Text(planDisplayName(for: productID))
                                                .font(.forma(.caption))
                                                .foregroundColor(.secondary)
                                        }
                                    } else {
                                        Text("No active subscription")
                                            .font(.forma(.subheadline))
                                            .foregroundColor(.secondary)
                                    }
                                }

                                Spacer()
                            }
                        }
                        .padding(.vertical, 8)

                        // Action Buttons
                        if purchaseManager.hasProAccess {
                            // For subscribed users - show management options
                            VStack(spacing: 12) {
                                // Manage in App Store Settings
                                Button {
                                    openSubscriptionSettings()
                                } label: {
                                    HStack {
                                        Image(systemName: "gear")
                                            .font(.forma(.body))
                                            .foregroundColor(.white)
                                            .frame(width: 32, height: 32)
                                            .background(Circle().fill(Color.blue))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Manage Subscription")
                                                .font(.forma(.body, weight: .semibold))
                                                .foregroundColor(.primary)
                                            Text("Cancel or modify in iOS Settings")
                                                .font(.forma(.caption))
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.forma(.caption))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(12)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())

                                // Cancel Subscription Helper
                                if purchaseManager.willRenew && purchaseManager.subscriptionExpirationDate != nil {
                                    Button {
                                        showingCancelConfirmation = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "xmark.circle")
                                                .font(.forma(.body))
                                                .foregroundColor(.white)
                                                .frame(width: 32, height: 32)
                                                .background(Circle().fill(Color.red))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Cancel Subscription")
                                                    .font(.forma(.body, weight: .semibold))
                                                    .foregroundColor(.red)
                                                Text("Access until \(purchaseManager.subscriptionExpirationDate!.formatted(date: .abbreviated, time: .omitted))")
                                                    .font(.forma(.caption))
                                                    .foregroundColor(.secondary)
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.forma(.caption))
                                                .foregroundColor(.secondary)
                                        }
                                        .padding(12)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        } else {
                            // For free users - show upgrade option
                            Button {
                                showingPaywall = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.forma(.body))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(Circle().fill(themeManager.currentTheme.primaryColor))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Upgrade to StuCo Pro")
                                            .font(.forma(.body, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text("Unlock all premium features")
                                            .font(.forma(.caption))
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.forma(.caption))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                                .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                                .cornerRadius(12)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }

                        // Restore Purchases
                        Button {
                            restorePurchases()
                        } label: {
                            HStack {
                                if isRestoringPurchases {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "arrow.clockwise.circle")
                                        .font(.forma(.body))
                                }

                                Text("Restore Purchases")
                                    .font(.forma(.body, weight: .medium))

                                Spacer()
                            }
                            .foregroundColor(.secondary)
                            .padding(.vertical, 12)
                        }
                        .disabled(isRestoringPurchases)
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Section(header: Text("Account Actions").font(.forma(.footnote, weight: .medium))) {
                        Button(role: .destructive) {
                            Task {
                                await supabaseService.signOut()
                                dismiss()
                            }
                        } label: {
                            SettingsRow(icon: "rectangle.portrait.and.arrow.right", iconColor: .red, title: "Sign Out", subtitle: "Sign out of your account")
                        }

                        Button(role: .destructive) {
                            showingDeleteAccountConfirmation = true
                        } label: {
                            SettingsRow(icon: "trash.fill", iconColor: .red, title: "Delete Account", subtitle: "Permanently delete your account and data")
                        }
                    }
                }
                .frame(width: geometry.size.width, alignment: .leading)
                .listRowSpacing(4)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .environment(\.defaultMinListRowHeight, 38)
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable {
                    // Refresh user data to get updated email after confirmation
                    await supabaseService.refreshUserData()
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingChangeEmail) {
            ChangeEmailView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingChangePassword) {
            ChangePasswordView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingEditDisplayName) {
            EditDisplayNameView()
                .environmentObject(supabaseService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingPaywall) {
            CustomPaywallView(isPresented: $showingPaywall)
        }
        .alert("Restore Purchases", isPresented: $showingRestoreAlert) {
            Button("OK", role: .cancel) {
                restoreMessage = nil
            }
        } message: {
            Text(restoreMessage ?? "")
        }
        .alert("Cancel Subscription", isPresented: $showingCancelConfirmation) {
            Button("Open Settings", role: .none) {
                openSubscriptionSettings()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("To cancel your subscription, go to Settings > [Your Name] > Subscriptions > StuCo and tap 'Cancel Subscription'.\n\nYou'll keep access until \(purchaseManager.subscriptionExpirationDate?.formatted(date: .abbreviated, time: .omitted) ?? "the end of your billing period").")
        }
        .alert("Delete Account", isPresented: $showingDeleteAccountConfirmation) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.\n\nAll your data including courses, schedules, and assignments will be permanently deleted.")
        }
        .onAppear {
            Task {
                await supabaseService.refreshUserData()
                await purchaseManager.fetchCustomerInfo()
            }
        }
        .dynamicTypeSize(.small ... .large)
        .environment(\.sizeCategory, .large)
    }
    
    func openSubscriptionWebsite() {
        guard let url = URL(string: "https://stuco.lovable.app") else { return }
        UIApplication.shared.open(url)
    }

    func openSubscriptionSettings() {
        // Open iOS Settings > Subscriptions directly
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    func restorePurchases() {
        isRestoringPurchases = true

        Task {
            let success = await purchaseManager.restorePurchases()

            await MainActor.run {
                isRestoringPurchases = false

                if success {
                    restoreMessage = "Purchases restored successfully! Your \(purchaseManager.tierDescription) subscription is now active."
                } else {
                    restoreMessage = purchaseManager.errorMessage ?? "No previous purchases found."
                }

                showingRestoreAlert = true
            }
        }
    }

    func deleteAccount() {
        isDeletingAccount = true

        Task {
            let result = await supabaseService.deleteAccount()

            await MainActor.run {
                isDeletingAccount = false

                switch result {
                case .success:
                    // Sign out and dismiss
                    Task {
                        await supabaseService.signOut()
                        dismiss()
                    }
                case .failure(let error):
                    // Show error alert
                    restoreMessage = "Failed to delete account: \(error.localizedDescription)"
                    showingRestoreAlert = true
                }
            }
        }
    }

    func planDisplayName(for productID: String) -> String {
        let lowercased = productID.lowercased()
        if lowercased.contains("monthly") {
            return "Monthly Subscription"
        } else if lowercased.contains("yearly") || lowercased.contains("annual") {
            return "Yearly Subscription"
        } else if lowercased.contains("lifetime") || lowercased.contains("founder") {
            return "Lifetime Access"
        } else if lowercased.contains("three") || lowercased.contains("3") {
            return "3-Month Subscription"
        } else {
            return "Pro Subscription"
        }
    }

    var displayName: String {
        supabaseService.userProfile?.displayName ?? ""
    }
    
    var subscriptionColor: Color {
        // Prefer RevenueCat tier if available (source of truth)
        if purchaseManager.isProUser {
            return purchaseManager.subscriptionTier.color
        }
        // Fallback to Supabase tier
        return supabaseService.userSubscription?.subscriptionTier.color ?? .gray
    }

    var subscriptionDisplayName: String {
        // Prefer RevenueCat tier if available
        if purchaseManager.isProUser {
            return purchaseManager.subscriptionTier.displayName
        }
        // Fallback to Supabase tier
        return supabaseService.userSubscription?.subscriptionTier.displayName ?? "Free"
    }

    var subscriptionGradient: LinearGradient {
        let tier = purchaseManager.isProUser
            ? purchaseManager.subscriptionTier
            : (supabaseService.userSubscription?.subscriptionTier ?? .free)

        switch tier {
        case .free:
            return LinearGradient(colors: [.gray.opacity(0.7), .gray], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .premium, .pro:
            return LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .leading, endPoint: .trailing)
        case .founder:
            return LinearGradient(colors: [.purple.opacity(0.8), .purple, .pink.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct EditDisplayNameView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Display Name")) {
                    TextField("Enter display name", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
                
                Section(footer: Text("This is how your name will appear in the app. You can change it anytime.")) {
                    EmptyView()
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .font(.forma(.footnote))
                            .foregroundColor(.red)
                    }
                }
                
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .font(.forma(.footnote))
                            .foregroundColor(.green)
                    }
                }
                
                Section {
                    Button {
                        updateDisplayName()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Update Display Name")
                                .font(.forma(.body, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                    .disabled(isLoading || displayName.isEmpty || displayName == currentDisplayName)
                }
            }
            .navigationTitle("Edit Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { 
                        dismiss() 
                    }
                    .font(.forma(.body))
                }
            }
        }
        .onAppear {
            displayName = supabaseService.userProfile?.displayName ?? ""
        }
    }
    
    var currentDisplayName: String {
        supabaseService.userProfile?.displayName ?? ""
    }
    
    func updateDisplayName() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            let result = await supabaseService.updateProfile(displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines))
            
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Display name updated successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct ChangeEmailView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var newEmail = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false

    private var currentEmail: String {
        supabaseService.currentUser?.email ?? "No email"
    }

    var body: some View {
        NavigationView {
            ZStack {
                themeManager.currentTheme.darkModeBackgroundFill
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Info section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                Text("Email Change Process")
                                    .font(.forma(.headline, weight: .semibold))
                            }

                            Text("You'll receive a confirmation link at your new email address. Click it to complete the change.")
                                .font(.forma(.subheadline))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground).opacity(0.5))
                        )

                        // Current email
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Email")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            Text(currentEmail)
                                .font(.forma(.body))
                                .foregroundColor(.primary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemGray6))
                                )
                        }

                        // New email input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New Email Address")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            TextField("Enter new email", text: $newEmail)
                                .textInputAutocapitalization(.none)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .font(.forma(.body))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }

                        // Password confirmation
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Confirm Password")
                                .font(.forma(.caption, weight: .medium))
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)

                            SecureField("Enter password", text: $password)
                                .font(.forma(.body))
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color(.systemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }

                        // Error message
                        if !errorMessage.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(errorMessage)
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange.opacity(0.1))
                            )
                        }

                        // Update button
                        Button {
                            updateEmail()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "envelope.fill")
                                    Text("Update Email")
                                }
                            }
                            .font(.forma(.body, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.darkModeAccentHue
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .disabled(isLoading || newEmail.isEmpty || password.isEmpty || !isValidEmail(newEmail))
                        .opacity((isLoading || newEmail.isEmpty || password.isEmpty || !isValidEmail(newEmail)) ? 0.6 : 1.0)

                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Change Email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .alert("Email Change Requested", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("A confirmation link has been sent to \(newEmail). Please check your inbox and click the link to complete the email change.\n\nAfter confirming, pull down on the Settings screen to refresh and see your updated email.")
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    func updateEmail() {
        // Validate email format
        guard isValidEmail(newEmail) else {
            errorMessage = "Please enter a valid email address"
            return
        }

        // Check if new email is different from current
        if newEmail.lowercased() == currentEmail.lowercased() {
            errorMessage = "New email must be different from current email"
            return
        }

        isLoading = true
        errorMessage = ""

        Task {
            // First verify password by trying to sign in
            let signInResult = await supabaseService.signIn(email: currentEmail, password: password)

            switch signInResult {
            case .success:
                // Password is correct, now update email
                let result = await supabaseService.updateEmail(newEmail)

                await MainActor.run {
                    isLoading = false
                    switch result {
                    case .success:
                        showingSuccessAlert = true
                    case .failure(let error):
                        if error == .invalidEmail {
                            errorMessage = "Please enter a valid email address"
                        } else if error == .missingConfiguration {
                            errorMessage = "Email service is not configured. Please contact support."
                        } else {
                            errorMessage = "Failed to update email: \(error.localizedDescription)"
                        }
                    }
                }

            case .failure:
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Incorrect password. Please try again."
                }
            }
        }
    }
}

struct ChangePasswordView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Password")) {
                    SecureField("Enter new password", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                
                Section(footer: Text("Password must be at least 8 characters with uppercase, lowercase, numbers, and special characters.")) {
                    EmptyView()
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.forma(.footnote))
                    }
                }
                
                if !successMessage.isEmpty {
                    Section {
                        Text(successMessage)
                            .foregroundColor(.green)
                            .font(.forma(.footnote))
                    }
                }
                
                Section {
                    Button {
                        updatePassword()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView().tint(.primary)
                            }
                            Text("Update Password")
                                .font(.forma(.body, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isLoading || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func updatePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords don't match"
            return
        }
        
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            let result = await supabaseService.updatePassword(newPassword)
            
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    successMessage = "Password updated successfully!"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}


extension SubscriptionTier {
    var icon: String {
        switch self {
        case .free: return "person"
        case .premium: return "star.fill"
        case .pro: return "star.fill"
        case .founder: return "crown.fill"
        }
    }

    var benefits: [String] {
        switch self {
        case .free:
            return [
                "Basic features",
                "Local data storage"
            ]
        case .premium, .pro:
            return [
                "Cloud sync across devices",
                "Priority support",
                "Advanced analytics"
            ]
        case .founder:
            return [
                "All Premium benefits",
                "Lifetime access",
                "Early access to new features",
                "Founder badge"
            ]
        }
    }
}
