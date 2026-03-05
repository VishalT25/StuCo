import SwiftUI

struct MenuView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Binding var isShowing: Bool
    @Binding var selectedRoute: AppRoute?
    @State private var happyFaceClickCount = 0

    var body: some View {
        ZStack {
            HStack {
                MenuContentView(isShowing: $isShowing, selectedRoute: $selectedRoute)
                    .environmentObject(themeManager)
                    .environmentObject(supabaseService)
                
                Spacer()
            }
        }
    }
}

struct MenuContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var supabaseService: SupabaseService
    @Binding var isShowing: Bool
    @Binding var selectedRoute: AppRoute?
    @State private var happyFaceClickCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User Profile Section (if authenticated)
            if supabaseService.isAuthenticated {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 40, height: 40)
                            Text((displayName.prefix(1)).uppercased())
                                .font(.forma(.headline, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.forma(.body, weight: .semibold))
                                .foregroundColor(.white)
                            Text(supabaseService.currentUser?.email ?? "")
                                .font(.forma(.caption))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        // Add Sync Status Indicator
                        SyncStatusIndicator()
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    
                    Divider()
                        .background(Color.white.opacity(0.3))
                        .padding(.horizontal, 24)
                }
            }
            
            menuItem(.schedule, icon: "calendar", title: "Schedule")
            menuItem(.events, icon: "star.fill", title: "Reminders")
            menuItem(.gpa, icon: "graduationcap", title: "Courses")
            menuItem(.resources, icon: "book.fill", title: "Resources")
            menuItem(.settings, icon: "gear", title: "Settings")
            
            Spacer() // Pushes the emoji to the bottom
            
            Button {
                happyFaceClickCount += 1
                if happyFaceClickCount >= 3 {
                    happyFaceClickCount = 0
                    selectedRoute = .islandSmasherGame
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isShowing = false
                    }
                }
            } label: {
                HStack {
                    Text("😀")
                        .font(.forma(.title))
                    if happyFaceClickCount > 0 {
                        Text("(\(happyFaceClickCount)/3)")
                            .font(.forma(.caption))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 24)
            }
            // END: Easter egg trigger
        }
        .frame(width: 250)
        .frame(maxHeight: .infinity)
        .background(themeManager.currentTheme.primaryColor)
        .shadow(radius: 10)
    }
    
    private var displayName: String {
        supabaseService.userProfile?.displayName ?? "User"
    }
    
    private func menuItem(_ route: AppRoute, icon: String, title: String) -> some View {
        Button {
            selectedRoute = route
            withAnimation(.easeInOut(duration: 0.3)) {
                isShowing = false
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.forma(.headline))
                Text(title)
                    .font(.forma(.headline))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .background(selectedRoute == route ? Color.white.opacity(0.2) : Color.clear)
        }
    }
}