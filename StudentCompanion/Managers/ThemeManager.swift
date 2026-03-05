import SwiftUI

// MARK: - Appearance Mode
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark" 
    case system = "System"
    
    var id: String { rawValue }
    
    var displayName: String { rawValue }
}

// MARK: - Theme System
enum AppTheme: String, CaseIterable, Identifiable {
    case forest = "Forest"
    case ice = "Ice"
    case fire = "Fire"
    case prime = "Prime"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var alternateIconName: String? {
        switch self {
        case .forest:
            return "ForestThemeIcon"
        case .ice:
            return "IceThemeIcon"
        case .fire:
            return "FireThemeIcon"
        case .prime:
            return "PrimeThemeIcon"
        }
    }
    
    var primaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 95/255, green: 135/255, blue: 105/255, alpha: 1.0)
                } else {
                    return UIColor(red: 134/255, green: 167/255, blue: 137/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 95/255, green: 135/255, blue: 155/255, alpha: 1.0)
                } else {
                    return UIColor(red: 134/255, green: 167/255, blue: 187/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 155/255, green: 95/255, blue: 105/255, alpha: 1.0)
                } else {
                    return UIColor(red: 187/255, green: 134/255, blue: 147/255, alpha: 1.0)
                }
            })
        case .prime:
            // Dark Ruby (#70000E) - slightly lighter in dark mode for better visibility
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 140/255, green: 20/255, blue: 30/255, alpha: 1.0)
                } else {
                    return UIColor(red: 112/255, green: 0/255, blue: 14/255, alpha: 1.0)
                }
            })
        }
    }
    
    var secondaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 115/255, green: 145/255, blue: 125/255, alpha: 1.0)
                } else {
                    return UIColor(red: 178/255, green: 200/255, blue: 186/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 115/255, green: 145/255, blue: 165/255, alpha: 1.0)
                } else {
                    return UIColor(red: 178/255, green: 200/255, blue: 220/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 165/255, green: 115/255, blue: 125/255, alpha: 1.0)
                } else {
                    return UIColor(red: 220/255, green: 178/255, blue: 186/255, alpha: 1.0)
                }
            })
        case .prime:
            // Catacomb Walls (#DCD7D4) with darker variation for dark mode
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 160/255, green: 155/255, blue: 152/255, alpha: 1.0)
                } else {
                    return UIColor(red: 220/255, green: 215/255, blue: 212/255, alpha: 1.0)
                }
            })
        }
    }
    
    var tertiaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 135/255, green: 155/255, blue: 145/255, alpha: 1.0)
                } else {
                    return UIColor(red: 210/255, green: 227/255, blue: 200/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 135/255, green: 155/255, blue: 175/255, alpha: 1.0)
                } else {
                    return UIColor(red: 200/255, green: 227/255, blue: 240/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 175/255, green: 135/255, blue: 145/255, alpha: 1.0)
                } else {
                    return UIColor(red: 240/255, green: 210/255, blue: 200/255, alpha: 1.0)
                }
            })
        case .prime:
            // Crème White (#C5B79D) with darker variation for dark mode
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 165/255, green: 153/255, blue: 135/255, alpha: 1.0)
                } else {
                    return UIColor(red: 197/255, green: 183/255, blue: 157/255, alpha: 1.0)
                }
            })
        }
    }
    
    var quaternaryColor: Color {
        switch self {
        case .forest:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 65/255, green: 75/255, blue: 70/255, alpha: 1.0)
                } else {
                    return UIColor(red: 235/255, green: 243/255, blue: 232/255, alpha: 1.0)
                }
            })
        case .ice:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 65/255, green: 75/255, blue: 85/255, alpha: 1.0)
                } else {
                    return UIColor(red: 232/255, green: 243/255, blue: 252/255, alpha: 1.0)
                }
            })
        case .fire:
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 85/255, green: 65/255, blue: 70/255, alpha: 1.0)
                } else {
                    return UIColor(red: 252/255, green: 235/255, blue: 232/255, alpha: 1.0)
                }
            })
        case .prime:
            // Meteorite for dark mode, Cultured Pearl for light mode
            return Color(UIColor { traitCollection in
                if traitCollection.userInterfaceStyle == .dark {
                    return UIColor(red: 44/255, green: 41/255, blue: 41/255, alpha: 1.0)
                } else {
                    return UIColor(red: 245/255, green: 244/255, blue: 242/255, alpha: 1.0)
                }
            })
        }
    }
    
    // MARK: - Dark Mode Hue Colors
    
    /// Enhanced hue color for dark mode widgets - creates a strong, visible glow effect
    var darkModeHue: Color {
        switch self {
        case .forest:
            return Color(red: 120/255, green: 200/255, blue: 140/255)
        case .ice:
            return Color(red: 100/255, green: 180/255, blue: 220/255)
        case .fire:
            return Color(red: 220/255, green: 120/255, blue: 140/255)
        case .prime:
            // Bright Ruby glow
            return Color(red: 200/255, green: 60/255, blue: 70/255)
        }
    }
    
    /// Shadow color for dark mode widgets - much more prominent
    var darkModeShadowColor: Color {
        switch self {
        case .forest:
            return Color(red: 120/255, green: 200/255, blue: 140/255)
        case .ice:
            return Color(red: 100/255, green: 180/255, blue: 220/255)
        case .fire:
            return Color(red: 220/255, green: 120/255, blue: 140/255)
        case .prime:
            // Bright Ruby shadow
            return Color(red: 200/255, green: 60/255, blue: 70/255)
        }
    }
    
    /// Bright accent hue for prominent elements in dark mode
    var darkModeAccentHue: Color {
        switch self {
        case .forest:
            return Color(red: 140/255, green: 220/255, blue: 160/255)
        case .ice:
            return Color(red: 120/255, green: 200/255, blue: 240/255)
        case .fire:
            return Color(red: 240/255, green: 140/255, blue: 160/255)
        case .prime:
            // Very bright Ruby accent
            return Color(red: 240/255, green: 80/255, blue: 90/255)
        }
    }
    
    /// Background fill for better contrast in dark mode
    var darkModeBackgroundFill: Color {
        switch self {
        case .forest:
            return Color(red: 25/255, green: 35/255, blue: 28/255)
        case .ice:
            return Color(red: 20/255, green: 30/255, blue: 40/255)
        case .fire:
            return Color(red: 35/255, green: 25/255, blue: 30/255)
        case .prime:
            // Meteorite charcoal (#2C2929)
            return Color(red: 44/255, green: 41/255, blue: 41/255)
        }
    }
}

class ThemeManager: ObservableObject {
    @Published var currentTheme: AppTheme = .forest
    @Published var appearanceMode: AppearanceMode = .system
    @Published var darkModeHueIntensity: Double = 0.5 // New intensity slider (0.0 to 1.0)

    private var isChangingIcon = false // Track if icon change is in progress

    init() {
        // Load saved theme
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
        
        // Load saved appearance mode
        if let savedAppearance = UserDefaults.standard.string(forKey: "selectedAppearance"),
           let appearance = AppearanceMode(rawValue: savedAppearance) {
            appearanceMode = appearance
        }
        
        // Load saved hue intensity
        let savedIntensity = UserDefaults.standard.double(forKey: "darkModeHueIntensity")
        if savedIntensity > 0 {
            darkModeHueIntensity = savedIntensity
        }
        
        // Apply appearance mode
        applyAppearanceMode()
    }
    
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.rawValue, forKey: "selectedTheme")

        // Change icon - simple, no retries, just guard against duplicates
        changeAppIcon(to: theme.alternateIconName)
    }

    private func changeAppIcon(to iconName: String?) {
        // Get current icon name
        let currentIconName = UIApplication.shared.alternateIconName

        // Only change if actually different
        guard currentIconName != iconName else {
            print("🎨 ThemeManager: Icon already set to '\(iconName ?? "Primary")', no change needed")
            return
        }

        // Check if app supports alternate icons
        guard UIApplication.shared.supportsAlternateIcons else {
            print("❌ ThemeManager: Device doesn't support alternate icons")
            return
        }

        // CRITICAL: Guard against duplicate calls (prevents EAGAIN error)
        guard !isChangingIcon else {
            print("⚠️ ThemeManager: Icon change already in progress, skipping duplicate request")
            return
        }

        // Mark as in progress
        isChangingIcon = true

        print("🎨 ThemeManager: Changing icon from '\(currentIconName ?? "Primary")' to '\(iconName ?? "Primary")'")

        // Call iOS API
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ ThemeManager: Icon change failed: \(error.localizedDescription)")
                } else {
                    print("✅ ThemeManager: Icon changed successfully to '\(iconName ?? "Primary")'")
                }

                // Reset flag
                self?.isChangingIcon = false
            }
        }
    }
    
    func setAppearanceMode(_ mode: AppearanceMode) {
        appearanceMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "selectedAppearance")
        applyAppearanceMode()
    }
    
    func setDarkModeHueIntensity(_ intensity: Double) {
        darkModeHueIntensity = intensity
        UserDefaults.standard.set(intensity, forKey: "darkModeHueIntensity")
    }
    
    private func applyAppearanceMode() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            switch self.appearanceMode {
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
}

// MARK: - Environment Keys
//
// Infrastructure for reducing @EnvironmentObject ThemeManager injection.
// Views that only read theme colors can use lightweight @Environment keys
// instead of injecting the full ObservableObject.
//
// Usage in a root view that already observes ThemeManager:
//   .environment(\.appTheme, themeManager.currentTheme)
//   .environment(\.darkModeHueIntensity, themeManager.darkModeHueIntensity)
//
// Usage in read-only leaf views (replaces @EnvironmentObject injection):
//   @Environment(\.appTheme) private var theme
//   @Environment(\.darkModeHueIntensity) private var hueIntensity
//
// Note: Keep @EnvironmentObject ThemeManager for views that call
//       setTheme(_:), setAppearanceMode(_:), or setDarkModeHueIntensity(_:).

struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .forest
}

struct DarkModeHueIntensityKey: EnvironmentKey {
    static let defaultValue: Double = 0.5
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }

    var darkModeHueIntensity: Double {
        get { self[DarkModeHueIntensityKey.self] }
        set { self[DarkModeHueIntensityKey.self] = newValue }
    }
}

// MARK: - Dark Mode Enhancement Modifier
extension View {
    /// Applies adaptive dark mode styling with theme-matching hues and intensity control
    @ViewBuilder
    func adaptiveDarkModeEnhanced(using theme: AppTheme, intensity: Double, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.3 * intensity),
                                    theme.darkModeBackgroundFill.opacity(0.2 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue.opacity(intensity),
                                            theme.darkModeHue.opacity(0.8 * intensity)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1 + (2 * intensity)
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.4 * intensity),
                            radius: 8 + (12 * intensity),
                            x: 0,
                            y: 4 + (6 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.3 * intensity),
                            radius: 4 + (8 * intensity),
                            x: 0,
                            y: 2 + (4 * intensity)
                        )
                }
        } else {
            self
        }
    }
    
    /// LEGACY: Applies enhanced dark mode styling with theme-matching hues - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func darkModeEnhanced(using theme: AppTheme, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.8),
                                    theme.darkModeBackgroundFill.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue,
                                            theme.darkModeHue
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 3
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.8),
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.6),
                            radius: 15,
                            x: 0,
                            y: 8
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.4),
                            radius: 10,
                            x: 0,
                            y: 5
                        )
                }
        } else {
            self
        }
    }
    
    /// Adaptive card dark mode enhancement with customizable corner radius
    @ViewBuilder
    func adaptiveCardDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 16, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    theme.darkModeAccentHue.opacity(intensity * 0.6),
                                    theme.darkModeHue.opacity(intensity * 0.4),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1 + (intensity * 1.5)
                        )
                )
                .shadow(
                    color: theme.darkModeShadowColor.opacity(intensity * 0.3),
                    radius: 8 + (intensity * 8),
                    x: 0,
                    y: 4 + (intensity * 4)
                )
        } else {
            self
        }
    }
    
    /// Widget-specific dark mode enhancement for smaller components
    @ViewBuilder
    func adaptiveWidgetDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 12, isEnabled: Bool = true) -> some View {
        if isEnabled {
            self
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            theme.darkModeAccentHue.opacity(intensity * 0.4),
                            lineWidth: 0.5 + (intensity * 1.0)
                        )
                )
                .shadow(
                    color: theme.darkModeShadowColor.opacity(intensity * 0.25),
                    radius: 6 + (intensity * 6),
                    x: 0,
                    y: 3 + (intensity * 3)
                )
        } else {
            self
        }
    }
}
