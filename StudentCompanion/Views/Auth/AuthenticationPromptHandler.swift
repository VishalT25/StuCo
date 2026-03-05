import SwiftUI

/// Shared authentication prompt handler for consistent sign-in prompts across the app
@MainActor
class AuthenticationPromptHandler: ObservableObject {
    static let shared = AuthenticationPromptHandler()
    
    @Published var showSignInPrompt = false
    @Published var signInPromptTitle = "Sign In Required"
    @Published var signInPromptDescription = "add your data"
    
    private var pendingAction: (() -> Void)?
    
    private init() {}
    
    func promptForSignIn(
        title: String = "Sign In Required",
        description: String = "add your data",
        action: @escaping () -> Void
    ) {
        signInPromptTitle = title
        signInPromptDescription = description
        pendingAction = action
        showSignInPrompt = true
    }
    
    func executePendingAction() {
        pendingAction?()
        pendingAction = nil
        showSignInPrompt = false
    }
    
    func dismissPrompt() {
        pendingAction = nil
        showSignInPrompt = false
    }
}