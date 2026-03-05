import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var scale = 0.7
    @State private var opacity = 0.0
    
    var body: some View {
        ZStack {
            themeManager.currentTheme.primaryColor
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "graduationcap.fill")
                    .font(.forma(.largeTitle))
                    .foregroundColor(.white) // White icon and text should look good on theme colors
                    .scaleEffect(scale)
                
                Text("StuCo")
                    .font(.forma(.title, weight: .bold))
                    .foregroundColor(.white)
            }
            .opacity(opacity)
        }
        .task {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

struct SplashScreenView_Previews: PreviewProvider {
    static var previews: some View {
        SplashScreenView()
            .environmentObject(ThemeManager())
    }
}