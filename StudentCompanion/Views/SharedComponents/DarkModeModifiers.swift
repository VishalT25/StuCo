import SwiftUI

// MARK: - Adaptive Dark Mode Enhancement Modifiers with Intensity Control

extension View {
    /// Applies adaptive card-style dark mode enhancement with intensity control - ONLY IN DARK MODE
    @ViewBuilder
    func adaptiveCardDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 12) -> some View {
        self.modifier(AdaptiveCardDarkModeModifier(theme: theme, intensity: intensity, cornerRadius: cornerRadius))
    }
    
    /// Applies adaptive fab dark mode enhancement with intensity control - ONLY IN DARK MODE
    @ViewBuilder
    func adaptiveFabDarkModeHue(using theme: AppTheme, intensity: Double) -> some View {
        self.modifier(AdaptiveFabDarkModeModifier(theme: theme, intensity: intensity))
    }
    
    /// Applies adaptive button dark mode enhancement with intensity control - ONLY IN DARK MODE
    @ViewBuilder
    func adaptiveButtonDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 8) -> some View {
        self.modifier(AdaptiveButtonDarkModeModifier(theme: theme, intensity: intensity, cornerRadius: cornerRadius))
    }
    
    /// Applies adaptive section header dark mode enhancement with intensity control - ONLY IN DARK MODE
    @ViewBuilder
    func adaptiveSectionDarkModeHue(using theme: AppTheme, intensity: Double) -> some View {
        self.modifier(AdaptiveSectionDarkModeModifier(theme: theme, intensity: intensity))
    }
    
    /// Applies adaptive widget-specific dark mode enhancement with intensity control - ONLY IN DARK MODE
    @ViewBuilder
    func adaptiveWidgetDarkModeHue(using theme: AppTheme, intensity: Double, cornerRadius: CGFloat = 16) -> some View {
        self.modifier(AdaptiveWidgetDarkModeModifier(theme: theme, intensity: intensity, cornerRadius: cornerRadius))
    }
}

// MARK: - Adaptive Modifiers that check color scheme

struct AdaptiveCardDarkModeModifier: ViewModifier {
    let theme: AppTheme
    let intensity: Double
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.3 * intensity),
                                    theme.darkModeBackgroundFill.opacity(0.2 * intensity),
                                    theme.darkModeHue.opacity(0.1 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue.opacity(0.6 * intensity),
                                            theme.darkModeHue.opacity(0.5 * intensity)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 0.5 + (2 * intensity)
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.4 * intensity),
                            radius: 6 + (12 * intensity),
                            x: 0,
                            y: 3 + (6 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.2 * intensity),
                            radius: 3 + (7 * intensity),
                            x: 0,
                            y: 2 + (3 * intensity)
                        )
                }
            }
    }
}

struct AdaptiveFabDarkModeModifier: ViewModifier {
    let theme: AppTheme
    let intensity: Double
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.2 * intensity),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 30
                            )
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue.opacity(intensity),
                                            theme.darkModeHue.opacity(0.8 * intensity),
                                            theme.darkModeAccentHue.opacity(0.6 * intensity)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1 + (3 * intensity)
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.5 * intensity),
                            radius: 10 + (20 * intensity),
                            x: 0,
                            y: 5 + (10 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.4 * intensity),
                            radius: 8 + (17 * intensity),
                            x: 0,
                            y: 4 + (8 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.2 * intensity),
                            radius: 5 + (10 * intensity),
                            x: 0,
                            y: 2 + (6 * intensity)
                        )
                }
            }
    }
}

struct AdaptiveButtonDarkModeModifier: ViewModifier {
    let theme: AppTheme
    let intensity: Double
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius)
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
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(theme.darkModeAccentHue.opacity(0.5 * intensity), lineWidth: 1 + (2 * intensity))
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.3 * intensity),
                            radius: 4 + (8 * intensity),
                            x: 0,
                            y: 2 + (4 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.2 * intensity),
                            radius: 2 + (6 * intensity),
                            x: 0,
                            y: 1 + (3 * intensity)
                        )
                }
            }
    }
}

struct AdaptiveSectionDarkModeModifier: ViewModifier {
    let theme: AppTheme
    let intensity: Double
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.2 * intensity),
                                    theme.darkModeHue.opacity(0.05 * intensity),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.2 * intensity),
                            radius: 2 + (6 * intensity),
                            x: 0,
                            y: 1 + (3 * intensity)
                        )
                }
            }
    }
}

struct AdaptiveWidgetDarkModeModifier: ViewModifier {
    let theme: AppTheme
    let intensity: Double
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.4 * intensity),
                                    theme.darkModeBackgroundFill.opacity(0.3 * intensity),
                                    theme.darkModeHue.opacity(0.1 * intensity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue.opacity(intensity),
                                            theme.darkModeHue.opacity(0.8 * intensity),
                                            theme.darkModeAccentHue.opacity(0.6 * intensity)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1 + (3 * intensity)
                                )
                        )
                        .shadow(
                            color: theme.darkModeShadowColor.opacity(0.5 * intensity),
                            radius: 8 + (17 * intensity),
                            x: 0,
                            y: 4 + (11 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.4 * intensity),
                            radius: 6 + (14 * intensity),
                            x: 0,
                            y: 3 + (7 * intensity)
                        )
                        .shadow(
                            color: theme.darkModeAccentHue.opacity(0.2 * intensity),
                            radius: 4 + (8 * intensity),
                            x: 0,
                            y: 2 + (4 * intensity)
                        )
                }
            }
    }
}

// MARK: - Legacy Strong Modifiers (kept for backwards compatibility)

extension View {
    /// Applies a MUCH STRONGER card-style dark mode enhancement - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func cardDarkModeHue(using theme: AppTheme, cornerRadius: CGFloat = 12) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.darkModeBackgroundFill.opacity(0.8),
                                theme.darkModeBackgroundFill.opacity(0.6),
                                theme.darkModeHue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        theme.darkModeAccentHue.opacity(0.9),
                                        theme.darkModeHue.opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .shadow(
                        color: theme.darkModeShadowColor.opacity(0.8),
                        radius: 18,
                        x: 0,
                        y: 9
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.5),
                        radius: 10,
                        x: 0,
                        y: 5
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.3),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
            }
    }
    
    /// Applies enhanced dark mode styling for floating action buttons - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func fabDarkModeHue(using theme: AppTheme) -> some View {
        self
            .background {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                theme.darkModeBackgroundFill.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 30
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        theme.darkModeAccentHue,
                                        theme.darkModeHue,
                                        theme.darkModeAccentHue
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(
                        color: theme.darkModeShadowColor,
                        radius: 30,
                        x: 0,
                        y: 15
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.8),
                        radius: 25,
                        x: 0,
                        y: 12
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.6),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.4),
                        radius: 15,
                        x: 0,
                        y: 8
                    )
            }
    }
    
    /// Applies MUCH STRONGER dark mode enhancement for buttons - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func buttonDarkModeHue(using theme: AppTheme, cornerRadius: CGFloat = 8) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.darkModeBackgroundFill.opacity(0.7),
                                theme.darkModeBackgroundFill.opacity(0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(theme.darkModeAccentHue.opacity(0.8), lineWidth: 3)
                    )
                    .shadow(
                        color: theme.darkModeShadowColor.opacity(0.7),
                        radius: 12,
                        x: 0,
                        y: 6
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.5),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
    }
    
    /// Applies section header dark mode enhancement - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func sectionDarkModeHue(using theme: AppTheme) -> some View {
        self
            .background {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.darkModeBackgroundFill.opacity(0.4),
                                theme.darkModeHue.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.4),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
    }
    
    /// Applies widget-specific dark mode enhancement - ALWAYS VISIBLE VERSION
    @ViewBuilder
    func widgetDarkModeHue(using theme: AppTheme, cornerRadius: CGFloat = 16) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.darkModeBackgroundFill.opacity(0.9),
                                theme.darkModeBackgroundFill.opacity(0.7),
                                theme.darkModeHue.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        theme.darkModeAccentHue,
                                        theme.darkModeHue,
                                        theme.darkModeAccentHue.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(
                        color: theme.darkModeShadowColor.opacity(0.9),
                        radius: 25,
                        x: 0,
                        y: 15
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.7),
                        radius: 20,
                        x: 0,
                        y: 10
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.5),
                        radius: 15,
                        x: 0,
                        y: 8
                    )
                    .shadow(
                        color: theme.darkModeAccentHue.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                    )
            }
    }
}

// MARK: - Environment-aware modifiers using @Environment
extension View {
    /// Helper to conditionally apply dark mode effects based on color scheme
    @ViewBuilder
    func conditionalDarkModeHue(using theme: AppTheme, cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 17.0, *) {
            self.modifier(DarkModeConditionalModifier(theme: theme, cornerRadius: cornerRadius))
        } else {
            self.widgetDarkModeHue(using: theme, cornerRadius: cornerRadius)
        }
    }
}

@available(iOS 17.0, *)
struct DarkModeConditionalModifier: ViewModifier {
    let theme: AppTheme
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.darkModeBackgroundFill.opacity(0.9),
                                    theme.darkModeBackgroundFill.opacity(0.7),
                                    theme.darkModeHue.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            theme.darkModeAccentHue,
                                            theme.darkModeHue,
                                            theme.darkModeAccentHue.opacity(0.7)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 4
                                )
                        )
                        .shadow(color: theme.darkModeShadowColor.opacity(0.9), radius: 25, x: 0, y: 15)
                        .shadow(color: theme.darkModeAccentHue.opacity(0.7), radius: 20, x: 0, y: 10)
                        .shadow(color: theme.darkModeAccentHue.opacity(0.5), radius: 15, x: 0, y: 8)
                        .shadow(color: theme.darkModeAccentHue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
            }
    }
}