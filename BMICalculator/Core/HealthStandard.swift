//
//  HealthStandard.swift
//  BMICalculator
//
//  Core engine — Foundation only.
//

import Foundation

// MARK: - HealthStandard

/// The set of BMI category cutoffs applied when classifying a value.
///
/// - `standard`: CDC / WHO universal cutoffs (18.5 / 25 / 30 ...).
/// - `asian`: WHO Asian public-health action points overlay
///   (18.5 / 23 / 27.5). These action points lower the overweight and
///   obesity thresholds to reflect cardiometabolic risk at lower BMI in
///   some Asian populations. They do not define obesity classes II / III.
public enum HealthStandard: String, CaseIterable, Codable, Identifiable, Sendable {
    case standard
    case asian

    /// Stable identity for use in SwiftUI `ForEach` / `Picker`.
    public var id: String { rawValue }

    /// A short, person-facing label for the standard.
    public var displayName: String {
        switch self {
        case .standard:
            return String(localized: "Standard (WHO/CDC)", comment: "Name of the universal BMI cutoff set. WHO and CDC are organization acronyms.")
        case .asian:
            return String(localized: "Asian (WHO action points)", comment: "Name of the WHO BMI cutoff set for some Asian populations.")
        }
    }

    /// A brief, non-judgmental explanation of the standard.
    public var explanation: String {
        switch self {
        case .standard:
            return String(localized: "Universal WHO and CDC cutoffs (18.5, 25, 30).", comment: "Explains the standard BMI cutoffs. Use your language's decimal separator in the numbers.")
        case .asian:
            return String(localized: "WHO public-health action points (18.5, 23, 27.5) used to flag cardiometabolic risk at a lower BMI in some Asian populations.", comment: "Explains the Asian BMI cutoffs. Use your language's decimal separator in the numbers.")
        }
    }

    /// The half-open BMI range classified as a healthy weight under this
    /// standard: `18.5 ..< 25` (standard) or `18.5 ..< 23` (Asian).
    ///
    /// This is the single source of truth for the healthy band; it mirrors the
    /// `.healthy` case in ``BMICalculator/category(forBMI:standard:)`` and drives
    /// the healthy-weight-range readout and the shaded chart band.
    public var healthyBMIRange: Range<Double> {
        switch self {
        case .standard: return 18.5..<25
        case .asian:    return 18.5..<23
        }
    }
}
