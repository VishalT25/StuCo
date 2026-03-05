import SwiftUI
import UIKit
import CoreText

// MARK: - App Font Family

/// Describes every font family the app knows about.
///
/// **Adding a new family — 3 steps:**
/// 1. Drop the TTF/OTF files into a folder inside `StudentCompanion/` (Xcode auto-discovers them).
/// 2. List each filename under `UIAppFonts` in `Info.plist` so iOS registers them at launch.
/// 3. Add a new `case` here, implement `uiFamilyName` and `fileName(weight:italic:)`,
///    then call `FontManager.shared.setFamily(.yourNewFamily)`.
///
/// **Hotswapping at runtime:**
/// ```swift
/// FontManager.shared.setFamily(.inter)   // takes effect immediately
/// FontManager.shared.setFamily(.system)  // revert to SF Pro
/// ```
enum AppFontFamily: String, CaseIterable, Identifiable {

    // ── Currently active ─────────────────────────────────────────────────
    /// SF Pro — Apple system font, always available, zero setup.
    case system

    // ── Ready to activate (add font files + Info.plist entry to enable) ──
    /// FormaDJR Banner — variable font.
    ///
    /// Files needed:
    /// - `StudentCompanion/Fonts/FormaDJR/FormaDJRBanner-Variable.ttf`
    /// - `StudentCompanion/Fonts/FormaDJR/FormaDJRBanner-Variable-Italic.ttf`
    case formaDJR

    /// Inter — variable font.
    ///
    /// Files needed:
    /// - `StudentCompanion/Fonts/Inter/Inter-Variable.ttf`
    /// - `StudentCompanion/Fonts/Inter/Inter-Variable-Italic.ttf`
    case inter

    // MARK: Metadata

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:   return "SF Pro (System)"
        case .formaDJR: return "FormaDJR Banner"
        case .inter:    return "Inter"
        }
    }

    // MARK: UIKit family name (as registered in Info.plist / CTFont)

    /// The PostScript family name used with UIFont / CTFont.
    /// Return `nil` for `.system` — handled separately.
    var uiFamilyName: String? {
        switch self {
        case .system:   return nil
        case .formaDJR: return "FormaDJR Banner"
        case .inter:    return "Inter"
        }
    }

    // MARK: Availability

    /// `true` if the fonts are registered and UIKit can resolve them.
    var isAvailable: Bool {
        switch self {
        case .system: return true
        default:
            guard let family = uiFamilyName else { return false }
            return !UIFont.fontNames(forFamilyName: family).isEmpty
        }
    }
}

// MARK: - Font Manager

/// Central font controller. Swap the active family at runtime and all
/// `.forma()` call sites instantly reflect the change on the next redraw.
///
/// **Typical usage:**
/// ```swift
/// // In App or SettingsView
/// @StateObject var fontManager = FontManager.shared
///
/// // Swap fonts
/// fontManager.setFamily(.inter)
///
/// // Apply to view tree so changes propagate
/// ContentView().environmentObject(fontManager)
/// ```
///
/// **How `.forma()` picks up changes:**
/// Views automatically re-render when `FontManager.shared.currentFamily` changes
/// because `FontManager` is an `ObservableObject`. Any view that reads
/// `Font.forma(…)` inside a body observed via `@EnvironmentObject` or
/// `.id(fontManager.currentFamily)` will rebuild with the new font.
final class FontManager: ObservableObject {
    static let shared = FontManager()

    @Published private(set) var currentFamily: AppFontFamily

    private static let storageKey = "appFontFamily"

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        let family = AppFontFamily(rawValue: stored) ?? .system
        // Verify stored family is still available; fall back to system if not.
        currentFamily = family.isAvailable ? family : .system
    }

    // MARK: Public API

    /// Switch the active font family. Falls back to `.system` if the family's
    /// fonts aren't registered yet (see `AppFontFamily` docs for setup steps).
    func setFamily(_ family: AppFontFamily) {
        guard family.isAvailable else {
            print("⚠️ FontManager: '\(family.displayName)' fonts are not registered. "
                + "Add font files and UIAppFonts entries to Info.plist first.")
            return
        }
        currentFamily = family
        UserDefaults.standard.set(family.rawValue, forKey: Self.storageKey)
    }

    /// Resolve a `Font` value for the given text style and weight using the
    /// currently active family.
    func resolve(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        switch currentFamily {
        case .system:
            return systemFont(style: style, weight: weight)
        default:
            if let font = customFont(family: currentFamily, style: style, weight: weight) {
                return font
            }
            return systemFont(style: style, weight: weight)
        }
    }

    // MARK: Debugging

    /// Print all font families and weights registered on this device — useful
    /// when diagnosing why a custom font isn't loading.
    func printAvailableFamilies(filter: String? = nil) {
        let families = UIFont.familyNames.sorted()
        print("── Registered font families ──────────────────────")
        for family in families {
            if let f = filter, !family.localizedCaseInsensitiveContains(f) { continue }
            let names = UIFont.fontNames(forFamilyName: family)
            print("  \(family)")
            names.forEach { print("    · \($0)") }
        }
        print("──────────────────────────────────────────────────")
    }

    /// Print availability status of every known `AppFontFamily`.
    func printFamilyStatus() {
        print("── Font family availability ──────────────────────")
        for family in AppFontFamily.allCases {
            let status = family.isAvailable ? "✅ available" : "⛔ not registered"
            let active = family == currentFamily ? " ← active" : ""
            print("  \(family.displayName): \(status)\(active)")
        }
        print("──────────────────────────────────────────────────")
    }

    // MARK: Private helpers

    private func systemFont(style: Font.TextStyle, weight: Font.Weight) -> Font {
        let size = pointSize(for: style)
        let design: Font.Design = (style == .title || style == .title2) ? .rounded : .default
        return .system(size: size, weight: weight, design: design)
    }

    private func customFont(
        family: AppFontFamily,
        style: Font.TextStyle,
        weight: Font.Weight
    ) -> Font? {
        guard let familyName = family.uiFamilyName else { return nil }
        let size = pointSize(for: style)

        // Build a descriptor using family name + weight trait.
        // This works with both static and variable fonts.
        let weightValue = uiWeight(from: weight)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: familyName,
            .traits: [UIFontDescriptor.TraitKey.weight: weightValue]
        ])
        let uiFont = UIFont(descriptor: descriptor, size: size)
        return Font(uiFont as CTFont)
    }

    private func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle:  return 34
        case .title:       return 28
        case .title2:      return 22
        case .title3:      return 20
        case .headline:    return 17
        case .body:        return 17
        case .callout:     return 16
        case .subheadline: return 15
        case .footnote:    return 13
        case .caption:     return 12
        case .caption2:    return 11
        @unknown default:  return 17
        }
    }

    private func uiWeight(from weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: return .ultraLight
        case .thin:       return .thin
        case .light:      return .light
        case .regular:    return .regular
        case .medium:     return .medium
        case .semibold:   return .semibold
        case .bold:       return .bold
        case .heavy:      return .heavy
        case .black:      return .black
        default:          return .regular
        }
    }
}

// MARK: - Font Extension (public API — unchanged)

extension Font {
    /// Returns the correct font for `style` and `weight` using whatever
    /// family `FontManager.shared` currently has active.
    ///
    /// This is the **only** font call site needed throughout the app.
    /// All 1500+ call sites use this signature — swapping families here
    /// affects the entire UI simultaneously.
    static func forma(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        FontManager.shared.resolve(style, weight: weight)
    }
}
