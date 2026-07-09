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

    // MARK: Weight display

    /// This system's smallest displayed weight increment: 1 kg, 1 lb, or 0.1 st.
    public var weightDisplayStep: Double {
        switch self {
        case .metric, .imperial: return 1
        case .stone: return 0.1
        }
    }

    /// Converts a canonical kilogram weight into this system's compact display
    /// weight: kilograms, pounds, or **decimal** stone (e.g. 11.4 st). This is
    /// the same decimal form the calculator uses for entry, not stone+pounds.
    public func displayWeight(fromKilograms kilograms: Double) -> Double {
        switch self {
        case .metric:   return kilograms
        case .imperial: return BMICalculator.pounds(fromKilograms: kilograms)
        case .stone:    return BMICalculator.pounds(fromKilograms: kilograms) / BMICalculator.poundsPerStone
        }
    }

    /// Formats a canonical-kilogram weight range as a compact, unit-aware string
    /// for this system, e.g. `"59–79 kg"`, `"130–174 lb"`, `"9.3–12.4 st"`.
    ///
    /// Endpoints are rounded **inward** (lower up, upper down) to
    /// ``weightDisplayStep`` so both shown values stay inside the source range —
    /// important when the range is a health band with an *exclusive* upper bound.
    ///
    /// Returns `nil` when inward rounding inverts the range, i.e. the band is
    /// narrower than one display step. That only happens at non-physical heights
    /// (a person under ~1 ft), where no whole-unit weight lands strictly inside
    /// the band; showing nothing is correct rather than a nonsensical range.
    public func weightRangeString(fromKilograms kilogramRange: Range<Double>) -> String? {
        let step = weightDisplayStep
        let rawLower = displayWeight(fromKilograms: kilogramRange.lowerBound)
        let rawUpper = displayWeight(fromKilograms: kilogramRange.upperBound)

        let lower = (rawLower / step).rounded(.up) * step
        var upper = (rawUpper / step).rounded(.down) * step
        // The band's upper bound is exclusive; if flooring landed exactly on it,
        // step back one increment so the shown value is genuinely inside.
        if upper >= rawUpper { upper -= step }
        // Inward rounding inverted the range → the band is sub-step-wide; there is
        // no representable in-band value at this resolution, so show nothing.
        guard lower <= upper else { return nil }

        switch self {
        case .metric, .imperial:
            return "\(Int(lower.rounded()))–\(Int(upper.rounded())) \(weightUnitLabel)"
        case .stone:
            return String(format: "%.1f–%.1f %@", lower, upper, weightUnitLabel)
        }
    }
}
