import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: EventViewModel
    @EnvironmentObject var supabaseService: SupabaseService
    @StateObject private var authPromptHandler = AuthenticationPromptHandler.shared
    @State private var showSplash = true
    @State private var navigateToPage: PageType?
    
    var body: some View {
        NavigationStack {
            Group {
                AuthenticationGate {
                    ZStack {
                        if showSplash {
                            SplashScreenView()
                                .transition(.opacity)
                                .onAppear {
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation {
                                            showSplash = false
                                        }
                                    }
                                }
                        } else {
                            SwipePageView(navigateToPage: $navigateToPage)
                                .transition(.opacity)
                        }
                    }
                }
            }
            .environmentObject(viewModel)
            .sheet(isPresented: $authPromptHandler.showSignInPrompt) {
                SignInPromptSheet(
                    isPresented: $authPromptHandler.showSignInPrompt,
                    actionTitle: authPromptHandler.signInPromptTitle,
                    actionDescription: authPromptHandler.signInPromptDescription
                )
                .onReceive(supabaseService.$isAuthenticated) { isAuthenticated in
                    if isAuthenticated {
                        authPromptHandler.executePendingAction()
                    }
                }
            }
        }
    }
}