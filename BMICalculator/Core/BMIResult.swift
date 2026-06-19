//
//  BMIResult.swift
//  BMICalculator
//
//  Core engine — Foundation only.
//

import Foundation

// MARK: - BMIResult

/// The outcome of a BMI calculation: the full-precision value, its category
/// under the chosen standard, and a display-rounded convenience value.
public struct BMIResult: Hashable, Codable, Sendable {

    /// Full-precision BMI (kg / m²). Use this for storage and further math.
    public let value: Double

    /// The classification band for `value` under `standard`.
    public let category: BMICategory

    /// The standard whose cutoffs produced `category`.
    public let standard: HealthStandard

    /// `value` rounded to one decimal place, for display.
    public var rounded: Double

    // MARK: Init

    /// Creates a result. `rounded` defaults to `value` rounded to one decimal.
    /// - Parameters:
    ///   - value: Full-precision BMI.
    ///   - category: The classification band.
    ///   - standard: The standard used to classify.
    ///   - rounded: Optional explicit display value; defaults to a 1-decimal
    ///     rounding of `value`.
    public init(
        value: Double,
        category: BMICategory,
        standard: HealthStandard,
        rounded: Double? = nil
    ) {
        self.value = value
        self.category = category
        self.standard = standard
        self.rounded = rounded ?? BMIResult.roundedToOneDecimal(value)
    }

    // MARK: Helpers

    /// Rounds a BMI value to one decimal place using round-half-away-from-zero.
    public static func roundedToOneDecimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// A display-ready string for `rounded`, always showing one decimal place
    /// (e.g. `22.0`, `31.7`).
    public var displayString: String {
        String(format: "%.1f", rounded)
    }
}
