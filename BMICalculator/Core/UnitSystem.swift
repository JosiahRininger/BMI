//
//  UnitSystem.swift
//  BMICalculator
//
//  Core engine — Foundation only. No SwiftUI / SwiftData imports so the
//  engine stays testable and shareable with a widget extension.
//

import Foundation

// MARK: - UnitSystem

/// The measurement system a person uses when entering height and weight.
///
/// - `metric`: kilograms and centimeters/meters.
/// - `imperial`: pounds and feet/inches.
/// - `stone`: stone (UK/Ireland body weight, decimal) and feet/inches.
public enum UnitSystem: String, CaseIterable, Codable, Identifiable, Sendable {
    case metric
    case imperial
    case stone

    /// Stable identity for use in SwiftUI `ForEach` / `Picker`.
    public var id: String { rawValue }

    /// Whether this system enters height in feet/inches (vs centimeters).
    public var usesImperialHeight: Bool { self != .metric }

    /// A short, person-facing label for the unit system.
    public var displayName: String {
        switch self {
        case .metric:   return "Metric"
        case .imperial: return "Imperial"
        case .stone:    return "Stone"
        }
    }

    /// The label shown for weight entry in this system.
    public var weightUnitLabel: String {
        switch self {
        case .metric:   return "kg"
        case .imperial: return "lb"
        case .stone:    return "st"
        }
    }

    /// The label shown for height entry in this system.
    public var heightUnitLabel: String {
        switch self {
        case .metric:   return "cm"
        case .imperial, .stone: return "ft / in"
        }
    }
}
