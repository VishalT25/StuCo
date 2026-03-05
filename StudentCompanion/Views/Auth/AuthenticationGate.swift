import SwiftUI

struct AuthenticationGate<Content: View>: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @EnvironmentObject private var themeManager: ThemeManager
    @ViewBuilder let content: () -> Content

    var body: some View {
        Group {
            if supabaseService.isCheckingAuth {
                // Show splash while restoring session — prevents sign-in screen flash for returning users
                SplashScreenView()
            } else if supabaseService.isAuthenticated {
                content()
            } else {
                WelcomeScreen()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: supabaseService.isCheckingAuth)
        .animation(.easeInOut, value: supabaseService.isAuthenticated)
    }
}

#Preview {
    AuthenticationGate {
        Text("Authenticated Content")
    }
    .environmentObject(SupabaseService.shared)
}