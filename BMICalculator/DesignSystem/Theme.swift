//
//  Theme.swift
//  BMICalculator — DesignSystem
//
//  The single source of truth for the app's color palette: the brand color,
//  semantic foreground/background tokens, and the mapping from a `BMICategory`
//  to its band color. Every value supports both light and dark appearances via
//  dynamic `UIColor` providers so the palette adapts automatically.
//
//  Depends on `BMICategory` from Core (same module target — no extra import).
//

import SwiftUI

// MARK: - Hex Color Initializer

extension Color {

    /// Creates a `Color` from a 6- or 8-digit hex string.
    ///
    /// Accepts optional `#` prefix. 6 digits are treated as `RRGGBB` (opaque),
    /// 8 digits as `RRGGBBAA`. Falls back to opaque black on a malformed string
    /// so the UI never crashes on a typo.
    ///
    /// - Parameter hex: e.g. `"#19BEF4"`, `"19BEF4"`, or `"19BEF4FF"`.
    init(hex: String) {
        let raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var int: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch raw.count {
        case 8: // RRGGBBAA
            (r, g, b, a) = (int >> 24 & 0xFF, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        case 6: // RRGGBB
            (r, g, b, a) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF, 255)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Dynamic (Light/Dark) Color Helper

extension Color {

    /// Builds a `Color` that resolves to `light` in light mode and `dark` in
    /// dark mode. Implemented through `UIColor`'s dynamic provider so the color
    /// stays correct even when used outside a SwiftUI environment (e.g. in a
    /// `CAGradientLayer` or shared with the widget).
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Brand Palette

/// Static, app-wide color tokens. Use these instead of literal colors so the
/// palette can evolve in one place.
enum Theme {

    // MARK: Brand

    /// Primary brand accent, `#19BEF4` — the app's single, consistent identity
    /// color. Identical in light and dark so brand recognition stays constant.
    static let brand = Color(hex: "#19BEF4")

    /// A slightly deeper brand tint for pressed/active states and gradients.
    static let brandDeep = Color(hex: "#0E9BCB")

    /// A soft brand tint suitable for fills behind brand-colored content.
    static let brandSoft = Color.dynamic(
        light: Color(hex: "#19BEF4").opacity(0.12),
        dark: Color(hex: "#19BEF4").opacity(0.22)
    )

    /// A two-stop brand gradient for hero elements and primary buttons.
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [brand, brandDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Semantic Surfaces

    /// App background. Near-white in light mode, true-ish black in dark.
    static let background = Color.dynamic(
        light: Color(hex: "#F5F8FA"),
        dark: Color(hex: "#0B0F12")
    )

    /// Elevated surface for cards and sheets.
    static let surface = Color.dynamic(
        light: Color(hex: "#FFFFFF"),
        dark: Color(hex: "#161B20")
    )

    /// A secondary surface for nested or recessed content.
    static let surfaceSecondary = Color.dynamic(
        light: Color(hex: "#EEF2F5"),
        dark: Color(hex: "#1F262D")
    )

    /// Hairline separators and card borders.
    static let separator = Color.dynamic(
        light: Color(hex: "#D8DEE4"),
        dark: Color(hex: "#2C343C")
    )

    // MARK: Semantic Text

    /// Primary text color.
    static let textPrimary = Color.dynamic(
        light: Color(hex: "#0B1620"),
        dark: Color(hex: "#F2F6F9")
    )

    /// Secondary / supporting text color.
    static let textSecondary = Color.dynamic(
        light: Color(hex: "#56636E"),
        dark: Color(hex: "#A6B2BD")
    )

    /// Text drawn on top of the brand color or category bands.
    static let textOnBrand = Color.white

    // MARK: Status

    /// Generic positive / healthy accent (matches the healthy band).
    static let positive = Color(hex: "#2FAF5A")

    /// Generic warning accent (matches the overweight band).
    static let warning = Color(hex: "#F2A53A")

    /// Generic critical accent (matches the highest obesity band).
    static let critical = Color(hex: "#E23B3B")
}

// MARK: - BMICategory Band Colors

extension BMICategory {

    /// The band color for this category, used by the gauge, result cards, and
    /// badges. Colors follow the brand spec:
    ///
    /// - underweight: blue
    /// - healthy: green
    /// - overweight: yellow/orange
    /// - obesity I/II/III: escalating orange → red
    ///
    /// Each value is appearance-aware: dark mode uses slightly brighter,
    /// more saturated tones so the bands read well on a dark surface.
    var bandColor: Color {
        switch self {
        case .underweight:
            // Brand-aligned blue, distinct from the saturated brand accent.
            return .dynamic(
                light: Color(hex: "#3AA9E0"),
                dark: Color(hex: "#5BC0F5")
            )
        case .healthy:
            return .dynamic(
                light: Color(hex: "#2FAF5A"),
                dark: Color(hex: "#46C56F")
            )
        case .overweight:
            return .dynamic(
                light: Color(hex: "#F2A53A"),
                dark: Color(hex: "#FFB84D")
            )
        case .obesityI:
            return .dynamic(
                light: Color(hex: "#EE8A2E"),
                dark: Color(hex: "#FF9E3D")
            )
        case .obesityII:
            return .dynamic(
                light: Color(hex: "#E8602B"),
                dark: Color(hex: "#FF7847")
            )
        case .obesityIII:
            return .dynamic(
                light: Color(hex: "#E23B3B"),
                dark: Color(hex: "#FF5C5C")
            )
        }
    }

    /// An SF Symbol that conveys the category *without relying on color*, for
    /// color-blind safety. Paired with the band color anywhere a band is shown
    /// purely as a swatch (gauge legend, category dot, etc.). The shapes escalate
    /// with risk so they're distinguishable in monochrome.
    var bandSymbolName: String {
        switch self {
        case .underweight: return "arrow.down.circle.fill"
        case .healthy:     return "checkmark.circle.fill"
        case .overweight:  return "exclamationmark.circle.fill"
        case .obesityI:    return "exclamationmark.triangle.fill"
        case .obesityII:   return "exclamationmark.triangle.fill"
        case .obesityIII:  return "exclamationmark.octagon.fill"
        }
    }

    /// A muted fill derived from the band color, for backgrounds behind
    /// category labels and chips.
    var bandSoftColor: Color {
        .dynamic(
            light: bandColorLight.opacity(0.16),
            dark: bandColorDark.opacity(0.26)
        )
    }

    /// A readable foreground color to place on top of `bandSoftColor`.
    var bandOnSoftColor: Color {
        .dynamic(
            light: bandColorLight,
            dark: bandColorDark
        )
    }

    // MARK: Internal raw light/dark stops (kept private to the extension)

    private var bandColorLight: Color {
        switch self {
        case .underweight: return Color(hex: "#3AA9E0")
        case .healthy:     return Color(hex: "#2FAF5A")
        case .overweight:  return Color(hex: "#F2A53A")
        case .obesityI:    return Color(hex: "#EE8A2E")
        case .obesityII:   return Color(hex: "#E8602B")
        case .obesityIII:  return Color(hex: "#E23B3B")
        }
    }

    private var bandColorDark: Color {
        switch self {
        case .underweight: return Color(hex: "#5BC0F5")
        case .healthy:     return Color(hex: "#46C56F")
        case .overweight:  return Color(hex: "#FFB84D")
        case .obesityI:    return Color(hex: "#FF9E3D")
        case .obesityII:   return Color(hex: "#FF7847")
        case .obesityIII:  return Color(hex: "#FF5C5C")
        }
    }
}
