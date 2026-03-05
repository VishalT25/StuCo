import SwiftUI

struct SplashLoadingView: View {
    @StateObject private var splashState = SplashState()
    // EnvironmentObject for viewModel will be passed down from StudentCompanionApp

    var body: some View {
        Group {
            if splashState.isLoading {
                SplashScreenView()
            } else {
                MainContentView() // MainContentView will now manage its own NavigationStack
            }
        }
        .animation(.easeInOut(duration: 0.3), value: splashState.isLoading)
    }
}

class SplashState: ObservableObject {
    @Published var isLoading = true
    
    init() {
        // Simulate some loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { // Faster transition
            withAnimation(.easeInOut(duration: 0.3)) { // Smooth transition
                self.isLoading = false
            }
        }
    }
}
