//
//  BMICategory.swift
//  BMICalculator
//
//  Core engine — Foundation only.
//

import Foundation

// MARK: - BMICategory

/// A BMI classification band.
///
/// Copy is intentionally person-first and non-judgmental
/// (e.g. "a person with obesity", never "you are obese").
///
/// Note: the Asian (WHO action-point) standard maps everything at or above
/// 27.5 into `obesityI`; it does not distinguish classes II / III. Those two
/// cases are only produced by the `.standard` classification.
public enum BMICategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case underweight
    case healthy
    case overweight
    case obesityI
    case obesityII
    case obesityIII

    /// Stable identity for use in SwiftUI `ForEach` / `Picker`.
    public var id: String { rawValue }

    // MARK: Display

    /// A person-first, non-judgmental title for the category.
    public var title: String {
        switch self {
        case .underweight: return "Underweight"
        case .healthy:     return "Healthy weight"
        case .overweight:  return "Overweight"
        case .obesityI:    return "Obesity (class 1)"
        case .obesityII:   return "Obesity (class 2)"
        case .obesityIII:  return "Obesity (class 3)"
        }
    }

    /// The half-open BMI range this category covers, formatted for display.
    ///
    /// Ranges are universal across standards in their textual form; the
    /// numeric boundaries actually applied depend on `HealthStandard` and
    /// live in `BMICalculator.category(forBMI:standard:)`.
    public var displayRange: String {
        switch self {
        case .underweight: return "< 18.5"
        case .healthy:     return "18.5 – < 25"
        case .overweight:  return "25 – < 30"
        case .obesityI:    return "30 – < 35"
        case .obesityII:   return "35 – < 40"
        case .obesityIII:  return "≥ 40"
        }
    }

    /// Whether this category represents a band with elevated health risk.
    ///
    /// Useful for non-judgmental UI emphasis without implying diagnosis.
    public var isElevatedRisk: Bool {
        switch self {
        case .underweight, .overweight, .obesityI, .obesityII, .obesityIII:
            return true
        case .healthy:
            return false
        }
    }
}
