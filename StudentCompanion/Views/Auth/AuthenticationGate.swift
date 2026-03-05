import SwiftUI

struct AuthenticationGate<Content: View>: View {
    @EnvironmentObject private var supabaseService: SupabaseService
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        Group {
            if supabaseService.isAuthenticated {
                content()
            } else {
                WelcomeScreen()
            }
        }
        .animation(.easeInOut, value: supabaseService.isAuthenticated)
    }
}

#Preview {
    AuthenticationGate {
        Text("Authenticated Content")
    }
    .environmentObject(SupabaseService.shared)
}