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

    /// A person-first, non-judgmental title for the category, localized.
    public var title: String {
        switch self {
        case .underweight:
            return String(localized: "Underweight", comment: "BMI category name (WHO/CDC adult category). Person-first, non-shaming.")
        case .healthy:
            return String(localized: "Healthy weight", comment: "BMI category name (WHO/CDC adult category). Person-first, non-shaming.")
        case .overweight:
            return String(localized: "Overweight", comment: "BMI category name (WHO/CDC adult category). Person-first, non-shaming.")
        case .obesityI:
            return String(localized: "Obesity (class 1)", comment: "BMI category name (WHO/CDC adult category, BMI 30 to under 35). Person-first, non-shaming.")
        case .obesityII:
            return String(localized: "Obesity (class 2)", comment: "BMI category name (WHO/CDC adult category, BMI 35 to under 40). Person-first, non-shaming.")
        case .obesityIII:
            return String(localized: "Obesity (class 3)", comment: "BMI category name (WHO/CDC adult category, BMI 40 and above). Person-first, non-shaming.")
        }
    }

    /// The English category name, never localized. Used only by the CSV export,
    /// whose format (English column names, POSIX numbers) stays stable for
    /// spreadsheets and re-imports in every language.
    public var englishTitle: String {
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
        displayRange(locale: .current)
    }

    /// ``displayRange`` with numbers formatted for `locale` (a decimal comma in
    /// es, pt-BR, and fr). The symbols (<, –, ≥) are universal, so the shape is
    /// not translated.
    public func displayRange(locale: Locale) -> String {
        func n(_ value: Double) -> String {
            DisplayNumber.decimal(value, places: value == value.rounded() ? 0 : 1, locale: locale)
        }
        switch self {
        case .underweight: return "< \(n(18.5))"
        case .healthy:     return "\(n(18.5)) – < \(n(25))"
        case .overweight:  return "\(n(25)) – < \(n(30))"
        case .obesityI:    return "\(n(30)) – < \(n(35))"
        case .obesityII:   return "\(n(35)) – < \(n(40))"
        case .obesityIII:  return "≥ \(n(40))"
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
