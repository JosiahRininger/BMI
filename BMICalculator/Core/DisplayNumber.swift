//
//  DisplayNumber.swift
//  BMICalculator
//
//  Core engine — Foundation only. Locale-aware number formatting for everything
//  a person reads (BMI values, weights, changes), so Spanish, Portuguese, and
//  French show a decimal comma ("22,5") and English a decimal point ("22.5").
//
//  Never use `String(format: "%.1f")` for user-facing numbers: it always prints
//  a period. Machine formats (the CSV export) keep their own POSIX formatting.
//

import Foundation

// MARK: - DisplayNumber

public enum DisplayNumber {

    /// A fixed-decimal number for display, e.g. `22.5` → "22.5" (en) or "22,5"
    /// (es, pt-BR, fr). No grouping separators: body values never need them and
    /// "1.234" would read as a decimal in some locales.
    public static func decimal(_ value: Double, places: Int = 1, locale: Locale = .current) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(places))
                .grouping(.never)
                .locale(locale)
        )
    }

    /// A signed change for display, e.g. "+0.4", "-1.2", or "0.0" when the
    /// value rounds to zero (never "+0.0" or "-0.0").
    public static func signedDecimal(_ value: Double, places: Int = 1, locale: Locale = .current) -> String {
        let scale = pow(10, Double(places))
        let rounded = (value * scale).rounded() / scale
        guard rounded != 0 else { return decimal(0, places: places, locale: locale) }
        return rounded.formatted(
            .number
                .precision(.fractionLength(places))
                .grouping(.never)
                .sign(strategy: .always())
                .locale(locale)
        )
    }
}
