import SwiftUI

struct ThemeSelectorView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showPaywall = false
    
    var body: some View {
        NavigationView {
            List {
                // Appearance Mode Section
                Section {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button {
                            themeManager.setAppearanceMode(mode)
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(appearanceIconColor(for: mode).opacity(0.15))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: appearanceIcon(for: mode))
                                        .foregroundColor(appearanceIconColor(for: mode))
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.displayName)
                                        .font(.forma(.body, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(appearanceDescription(for: mode))
                                        .font(.forma(.subheadline))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if themeManager.appearanceMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.forma(.body))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Appearance Mode")
                        .font(.forma(.footnote, weight: .medium))
                } footer: {
                    Text("Choose how the app appears on your device.")
                        .font(.forma(.caption))
                }
                
                // Theme Section
                Section {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            // Check if theme requires Pro access
                            if isThemeLocked(theme) {
                                showPaywall = true
                            } else {
                                themeManager.setTheme(theme)
                            }
                        } label: {
                            HStack(spacing: 16) {
                                // Theme preview circles
                                HStack(spacing: -8) {
                                    Circle()
                                        .fill(theme.primaryColor)
                                        .frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    Circle()
                                        .fill(theme.secondaryColor)
                                        .frame(width: 16, height: 16)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                                    Circle()
                                        .fill(theme.tertiaryColor)
                                        .frame(width: 12, height: 12)
                                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                                }
                                .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(theme.displayName)
                                        .font(.forma(.body, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Text(themeTagline(for: theme))
                                        .font(.forma(.subheadline))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()

                                if themeManager.currentTheme == theme {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.forma(.body))
                                        .foregroundColor(theme.primaryColor)
                                } else if isThemeLocked(theme) {
                                    Image(systemName: "lock.fill")
                                        .font(.forma(.body))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Color Theme")
                        .font(.forma(.footnote, weight: .medium))
                } footer: {
                    Text("Dark mode widgets will have enhanced hues that match your selected theme.")
                        .font(.forma(.caption))
                }
                
                // Dark Mode Enhancement Preview & Settings (only show in dark mode)
                if shouldShowDarkModeSection {
                    Section {
                        VStack(spacing: 16) {
                            Text("Dark Mode Enhancement Preview")
                                .font(.forma(.headline, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 16) {
                                ForEach(AppTheme.allCases) { theme in
                                    VStack(spacing: 8) {
                                        Text(theme.displayName)
                                            .font(.forma(.caption, weight: .medium))
                                            .foregroundColor(.primary)
                                        
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.clear)
                                            .frame(width: 60, height: 40)
                                            .adaptiveWidgetDarkModeHue(using: theme, intensity: themeManager.darkModeHueIntensity, cornerRadius: 12)
                                            .overlay(
                                                Image(systemName: "star.fill")
                                                    .font(.forma(.caption))
                                                    .foregroundColor(theme.primaryColor)
                                            )
                                    }
                                }
                            }
                            
                            Text("Widgets and cards will have subtle hues and glows in dark mode")
                                .font(.forma(.footnote))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } header: {
                        Text("Live Preview")
                            .font(.forma(.footnote, weight: .medium))
                    }
                    
                    // Dark Mode Hue Intensity Section (only in dark mode)
                    Section {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Dark Mode Hue Intensity")
                                    .font(.forma(.body, weight: .semibold))
                                Spacer()
                                Text("\(Int(themeManager.darkModeHueIntensity * 100))%")
                                    .font(.forma(.subheadline))
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { themeManager.darkModeHueIntensity },
                                    set: { themeManager.setDarkModeHueIntensity($0) }
                                ),
                                in: 0.0...1.0,
                                step: 0.05
                            )
                            .tint(themeManager.currentTheme.primaryColor)
                            
                            HStack {
                                Text("Subtle")
                                    .font(.forma(.caption))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("Vibrant")
                                    .font(.forma(.caption))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Dark Mode Effects")
                            .font(.forma(.footnote, weight: .medium))
                    } footer: {
                        Text("Adjust how prominent the theme hues appear in dark mode throughout the app.")
                            .font(.forma(.caption))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Themes & Appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.forma(.body))
                }
            }
            .sheet(isPresented: $showPaywall) {
                CustomPaywallView(isPresented: $showPaywall)
            }
        }
    }

    // MARK: - Helper Methods

    /// Check if a theme requires Pro access
    private func isThemeLocked(_ theme: AppTheme) -> Bool {
        // Forest is free, all other themes require Pro
        if theme == .forest {
            return false
        }
        return !purchaseManager.hasProAccess
    }
    
    /// Determines if dark mode sections should be shown based on current appearance settings
    private var shouldShowDarkModeSection: Bool {
        switch themeManager.appearanceMode {
        case .dark:
            return true
        case .light:
            return false
        case .system:
            return colorScheme == .dark
        }
    }
    
    private func appearanceIcon(for mode: AppearanceMode) -> String {
        switch mode {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .system:
            return "circle.righthalf.filled"
        }
    }
    
    private func appearanceIconColor(for mode: AppearanceMode) -> Color {
        switch mode {
        case .light:
            return .orange
        case .dark:
            return .indigo
        case .system:
            return .blue
        }
    }
    
    private func appearanceDescription(for mode: AppearanceMode) -> String {
        switch mode {
        case .light:
            return "Always use light appearance"
        case .dark:
            return "Always use dark appearance"
        case .system:
            return "Match system settings"
        }
    }

    private func themeTagline(for theme: AppTheme) -> String {
        switch theme {
        case .forest:
            return "Earthy greens with tranquil neutrals — balanced and focus‑friendly."
        case .ice:
            return "Crisp, frosty blues with airy contrast — cool and calming."
        case .fire:
            return "Warm coral and berry hues — bold, energetic, and motivating."
        case .prime:
            return "Modern and materialistic — sleek and sophisticated."
        }
    }
}

#Preview {
    ThemeSelectorView()
        .environmentObject(ThemeManager())
}
