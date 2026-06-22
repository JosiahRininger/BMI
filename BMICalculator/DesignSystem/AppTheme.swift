//
//  AppTheme.swift
//  BMICalculator — DesignSystem
//
//  Selectable accent palettes. `.classic` is the original brand blue and the
//  free default; the rest are a BMI Pro perk. The chosen theme drives the
//  app-wide accent through `Theme.brand` (see Theme.swift), so picking one
//  recolors buttons, the gauge, charts, and highlights everywhere at once.
//
//  Each palette is a two-stop accent (a primary plus a deeper companion for
//  gradients and pressed states) chosen to read on both light and dark
//  surfaces. The category band colors (healthy/overweight/…) are deliberately
//  NOT themed — those carry meaning and must stay consistent.
//

import SwiftUI

/// An accent palette the person can choose. `RawValue` is a stable string so it
/// persists cleanly in `UserDefaults`.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case classic
    case ocean
    case teal
    case indigo
    case violet
    case rose
    case amber
    case forest
    case graphite

    var id: String { rawValue }

    /// The free default. Everything else requires Pro.
    static let free: AppTheme = .classic

    /// Whether unlocking this palette requires BMI Pro.
    var isPro: Bool { self != .classic }

    /// Human-readable name for the picker and accessibility.
    var displayName: String {
        switch self {
        case .classic:  return "Classic Blue"
        case .ocean:    return "Ocean"
        case .teal:     return "Teal"
        case .indigo:   return "Indigo"
        case .violet:   return "Violet"
        case .rose:     return "Rose"
        case .amber:    return "Amber"
        case .forest:   return "Forest"
        case .graphite: return "Graphite"
        }
    }

    /// Primary accent color.
    var accent: Color { Color(hex: accentHex) }

    /// A deeper companion stop for gradients and pressed/active states.
    var accentDeep: Color { Color(hex: accentDeepHex) }

    /// A two-stop gradient for hero elements and primary buttons.
    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep],
                       startPoint: .topLeading,
                       endPoint: .bottomTrailing)
    }

    // MARK: Raw stops

    private var accentHex: String {
        switch self {
        case .classic:  return "#19BEF4"
        case .ocean:    return "#3B82F6"
        case .teal:     return "#14B8A6"
        case .indigo:   return "#6366F1"
        case .violet:   return "#A855F7"
        case .rose:     return "#F43F5E"
        case .amber:    return "#E0930A"
        case .forest:   return "#22C55E"
        case .graphite: return "#64748B"
        }
    }

    private var accentDeepHex: String {
        switch self {
        case .classic:  return "#0E9BCB"
        case .ocean:    return "#1D4ED8"
        case .teal:     return "#0D9488"
        case .indigo:   return "#4F46E5"
        case .violet:   return "#7E22CE"
        case .rose:     return "#E11D48"
        case .amber:    return "#B7740A"
        case .forest:   return "#16A34A"
        case .graphite: return "#475569"
        }
    }
}
