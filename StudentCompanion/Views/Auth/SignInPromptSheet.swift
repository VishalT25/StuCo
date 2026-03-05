import SwiftUI

struct SignInPromptSheet: View {
    @Binding var isPresented: Bool
    let actionTitle: String
    let actionDescription: String
    
    @EnvironmentObject private var supabaseService: SupabaseService
    @StateObject private var themeManager = ThemeManager()
    @State private var showFullAuth = false
    @State private var animateContent = false
    
    init(
        isPresented: Binding<Bool>,
        actionTitle: String = "Add Data",
        actionDescription: String = "add your data"
    ) {
        self._isPresented = isPresented
        self.actionTitle = actionTitle
        self.actionDescription = actionDescription
    }
    
    var body: some View {
        ZStack {
            // Background with blur
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSheet()
                }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Main content card
                mainContentCard
                    .scaleEffect(animateContent ? 1 : 0.9)
                    .opacity(animateContent ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animateContent = true
            }
        }
    }
    
    private var mainContentCard: some View {
        VStack(spacing: 32) {
            // Header with icon
            headerSection
            
            // Benefits section
            benefitsSection
            
            // Action buttons
            actionButtonsSection
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 20)
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Animated lock icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.3),
                                themeManager.currentTheme.primaryColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Sign In Required")
                    .font(.forma(.title2, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("To \(actionDescription), please sign in to your account. This ensures your data is securely synced across all your devices.")
                    .font(.forma(.subheadline))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
    }
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            Text("Why sign in?")
                .font(.forma(.headline, weight: .semibold))
                .foregroundColor(.primary)
            
            VStack(spacing: 12) {
                EnhancedBenefitRow(
                    icon: "icloud.and.arrow.up.fill",
                    title: "Cloud Sync",
                    description: "Access your data on all devices",
                    color: .blue
                )
                
                EnhancedBenefitRow(
                    icon: "shield.lefthalf.filled",
                    title: "Secure Storage",
                    description: "Your data is encrypted and protected",
                    color: .green
                )
                
                EnhancedBenefitRow(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Real-time Updates",
                    description: "Changes sync instantly everywhere",
                    color: themeManager.currentTheme.primaryColor
                )
            }
        }
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            AnimatedButton(
                title: "Sign In to Continue",
                subtitle: "Quick and secure",
                icon: "person.fill.checkmark",
                isPrimary: true
            ) {
                showFullAuth = true
            }
            
            Button("Maybe Later") {
                dismissSheet()
            }
            .font(.forma(.subheadline, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
        }
    }
    
    private func dismissSheet() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            animateContent = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isPresented = false
        }
    }
    
    // Present the full authentication view
    private var fullScreenAuthView: some View {
        AuthenticationView()
            .onReceive(supabaseService.$isAuthenticated) { isAuthenticated in
                if isAuthenticated {
                    showFullAuth = false
                    dismissSheet()
                }
            }
    }
}

struct EnhancedBenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(color)
            }
            
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground).opacity(0.5))
                .background(.ultraThinMaterial)
        )
    }
}

#Preview {
    SignInPromptSheet(
        isPresented: .constant(true),
        actionTitle: "Add Event",
        actionDescription: "add your event"
    )
    .environmentObject(SupabaseService.shared)
}