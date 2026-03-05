import SwiftUI
import UIKit

// enum AppRoute {
//    case schedule
//    case events
//    case gpa
//    case settings
//    case islandSmasher
// }

struct HomeView: View { // Assuming this is an older/unused view. If still used, ensure its AppRoute doesn't clash.
    @EnvironmentObject private var viewModel: EventViewModel
    @State private var showSplash = true // This state seems to be managed elsewhere now
    @State private var showMenu = false
    @State private var showingSchedule = false
    
    var body: some View {
        Text("This is the old HomeView, MainContentView is likely active.")
    }
}

// ... (CardView and Previews if they are specific to this old HomeView)
struct CardView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

#Preview {
    HomeView().environmentObject(EventViewModel())
}