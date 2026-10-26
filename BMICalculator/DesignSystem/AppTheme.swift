//
//  AppTheme.swift
//  BMICalculator — DesignSystem
//
//  Selectable accent palettes, a Pro feature. `.classic` is the original brand
//  blue and stays the default for everyone, so nobody's app changes color
//  unless they choose it. The chosen theme drives the app-wide accent through
//  `Theme.brand` (see Theme.swift): buttons, highlights, and the chart line.
//
//  The category band colors (healthy green, overweight amber, the obesity
//  oranges and red) carry meaning and are deliberately NOT themed. Palettes
//  that could be mistaken for one of them (green, amber, rose) are left out, and
//  `AppThemeTests` checks every accent stays clear of those hues.
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
    case orchid
    case graphite

    var id: String { rawValue }

    /// The default for everyone (free and Pro).
    static let standard: AppTheme = .classic

    /// Whether choosing this palette requires Pro.
    var requiresPro: Bool { self != .classic }

    /// Human-readable name for the picker and accessibility.
    var displayName: String {
        switch self {
        case .classic:  return "Classic Blue"
        case .ocean:    return "Ocean"
        case .teal:     return "Teal"
        case .indigo:   return "Indigo"
        case .violet:   return "Violet"
        case .orchid:   return "Orchid"
        case .graphite: return "Graphite"
        }
    }

    /// Primary accent color.
    var accent: Color { Color(hex: accentHex) }

    /// A deeper companion stop for gradients and pressed/active states.
    var accentDeep: Color { Color(hex: accentDeepHex) }

    // MARK: Raw stops

    var accentHex: String {
        switch self {
        case .classic:  return "#19BEF4"
        case .ocean:    return "#3B82F6"
        case .teal:     return "#14B8A6"
        case .indigo:   return "#6366F1"
        case .violet:   return "#A855F7"
        case .orchid:   return "#D946EF"
        case .graphite: return "#64748B"
        }
    }

    var accentDeepHex: String {
        switch self {
        case .classic:  return "#0E9BCB"
        case .ocean:    return "#1D4ED8"
        case .teal:     return "#0D9488"
        case .indigo:   return "#4F46E5"
        case .violet:   return "#7E22CE"
        case .orchid:   return "#A21CAF"
        case .graphite: return "#475569"
        }
    }
}
