import SwiftUI

struct AnimatedButton: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let action: () -> Void
    var isPrimary: Bool = true
    var isLoading: Bool = false
    var isDisabled: Bool = false
    
    @StateObject private var themeManager = ThemeManager()
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        isPrimary: Bool = true,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isPrimary = isPrimary
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            if !isLoading && !isDisabled {
                // Haptic feedback
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.impactOccurred()
                action()
            }
        }) {
            HStack(spacing: 12) {
                if let icon = icon, !isLoading {
                    Image(systemName: icon)
                        .font(.forma(.headline, weight: .semibold))
                        .transition(.opacity.combined(with: .scale))
                }
                
                VStack(spacing: 2) {
                    if isLoading {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                                .tint(isPrimary ? .white : themeManager.currentTheme.primaryColor)
                            
                            Text("Please wait...")
                                .font(.forma(.headline, weight: .semibold))
                        }
                    } else {
                        Text(title)
                            .font(.forma(.headline, weight: .semibold))
                        
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.forma(.caption, weight: .medium))
                                .opacity(0.8)
                        }
                    }
                }
                
                Spacer()
                
                if isPrimary && !isLoading {
                    Image(systemName: "arrow.right")
                        .font(.forma(.subheadline, weight: .semibold))
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .foregroundColor(isPrimary ? .white : themeManager.currentTheme.primaryColor)
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if isPrimary {
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor,
                                themeManager.currentTheme.secondaryColor
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color(.systemBackground).opacity(0.1)
                            .background(.ultraThinMaterial)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: isPrimary ? [] : [
                                themeManager.currentTheme.primaryColor.opacity(0.5),
                                themeManager.currentTheme.secondaryColor.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPrimary ? 0 : 1.5
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(isDisabled ? 0.6 : 1.0)
        .shadow(
            color: isPrimary ? themeManager.currentTheme.primaryColor.opacity(0.4) : Color.black.opacity(0.1),
            radius: isPressed ? 8 : 12,
            x: 0,
            y: isPressed ? 4 : 8
        )
        .scaleEffect(pulseAnimation ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: pulseAnimation)
        .onAppear {
            if isPrimary && !isDisabled {
                pulseAnimation = true
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isLoading && !isDisabled {
                        withAnimation(.easeInOut(duration: 0.1)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
        .disabled(isLoading || isDisabled)
    }
}