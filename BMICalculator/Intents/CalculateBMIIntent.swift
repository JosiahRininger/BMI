//
//  CalculateBMIIntent.swift
//  BMICalculator
//
//  An AppIntent that calculates BMI from a weight + height + unit system, usable
//  from Siri, the Shortcuts app, Spotlight, and Action Button. Returns a result
//  value (a `BMIResultEntity`) plus a person-first, non-judgmental dialog and a
//  snippet view.
//
//  Depends on Core: BMICalculator, BMIResult, BMICategory, UnitSystem.
//

import Foundation
import AppIntents
import SwiftUI

// MARK: - UnitSystem + AppEnum

/// Surfaces Core's `UnitSystem` to the Shortcuts/Siri parameter UI without making
/// Core import AppIntents. Cases mirror `UnitSystem` exactly.
extension UnitSystem: AppEnum {

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "Unit System"
    }

    public static var caseDisplayRepresentations: [UnitSystem: DisplayRepresentation] {
        [
            .metric: DisplayRepresentation(title: "Metric (kg, cm)"),
            .imperial: DisplayRepresentation(title: "Imperial (lb, ft/in)")
        ]
    }
}

// MARK: - CalculateBMIIntent

/// Calculates a person's BMI and returns it as a queryable entity plus a spoken /
/// displayed result. Weight and height are entered in the chosen unit system.
struct CalculateBMIIntent: AppIntent {

    // MARK: Intent metadata

    static let title: LocalizedStringResource = "Calculate BMI"

    static let description = IntentDescription(
        "Calculate your Body Mass Index from your weight and height. BMI is a screening tool, not a diagnosis.",
        categoryName: "Health",
        searchKeywords: ["BMI", "body mass index", "weight", "health"]
    )

    /// Run silently when invoked from a button so the calculation completes
    /// without forcing the app open; we still return a dialog + snippet.
    static let openAppWhenRun: Bool = false

    // MARK: Parameters

    @Parameter(
        title: "Unit System",
        description: "Choose metric (kilograms / centimeters) or imperial (pounds / feet & inches).",
        default: .metric
    )
    var unitSystem: UnitSystem

    @Parameter(
        title: "Weight",
        description: "Your weight in kilograms (metric) or pounds (imperial).",
        controlStyle: .field,
        inclusiveRange: (1, 1000)
    )
    var weight: Double

    @Parameter(
        title: "Height",
        description: "Your height in centimeters (metric) or total inches (imperial).",
        controlStyle: .field,
        inclusiveRange: (10, 300)
    )
    var height: Double

    // MARK: Summary (Shortcuts editor sentence)

    static var parameterSummary: some ParameterSummary {
        Summary("Calculate BMI for \(\.$weight) and \(\.$height) in \(\.$unitSystem)")
    }

    // MARK: Perform

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<BMIResultEntity> & ProvidesDialog & ShowsSnippetView {

        // Convert inputs into Core's canonical kilograms + meters.
        let weightKilograms: Double
        let heightMeters: Double

        switch unitSystem {
        case .metric:
            weightKilograms = weight
            heightMeters = height / 100.0   // centimeters → meters
        case .imperial:
            weightKilograms = BMICalculator.kilograms(fromPounds: weight)
            heightMeters = height * 0.0254  // total inches → meters
        }

        // Guard against non-physical input before dividing.
        guard weightKilograms > 0, heightMeters > 0 else {
            throw CalculateBMIError.invalidMeasurements
        }

        let result = BMICalculator.result(
            weightKilograms: weightKilograms,
            heightMeters: heightMeters
        )

        let date = Date()
        let entity = BMIResultEntity(result: result, date: date)

        // Donate this fresh result to Spotlight so it surfaces in system search.
        // HEALTH/AD FIREWALL: Spotlight is local on-device search only — no value
        // is ever forwarded to the ad SDK.
        BMIResultEntity.donate(entities: [entity])

        let dialog = Self.dialog(for: result)
        let snippet = BMIResultSnippetView(entity: entity, disclaimer: Self.disclaimer)

        return .result(value: entity, dialog: dialog, view: snippet)
    }

    // MARK: Dialog

    /// Person-first spoken / displayed summary. Never says "you are <category>".
    static func dialog(for result: BMIResult) -> IntentDialog {
        let bmiText = String(format: "%.1f", result.rounded)
        let categoryPhrase = phrase(for: result.category)
        return IntentDialog("Your BMI is \(bmiText), which falls in the \(categoryPhrase) range. \(disclaimer)")
    }

    /// Non-judgmental phrasing for each category.
    static func phrase(for category: BMICategory) -> String {
        switch category {
        case .underweight:  return "underweight"
        case .healthy:      return "healthy weight"
        case .overweight:   return "overweight"
        case .obesityI:     return "obesity (class 1)"
        case .obesityII:    return "obesity (class 2)"
        case .obesityIII:   return "obesity (class 3)"
        }
    }

    static let disclaimer = "BMI is a screening tool, not a diagnosis. Talk to a healthcare provider."
}

// MARK: - Errors

/// User-presentable errors thrown by `CalculateBMIIntent`.
enum CalculateBMIError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case invalidMeasurements

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .invalidMeasurements:
            return "Please enter a weight and height greater than zero."
        }
    }
}

// MARK: - Snippet View

/// A compact result card shown in the Shortcuts / Siri snippet. Uses Liquid Glass
/// on iOS 26+ and a material fallback below it. Brand blue #19BEF4.
struct BMIResultSnippetView: View {

    let entity: BMIResultEntity
    let disclaimer: String

    private var brandBlue: Color {
        Color(red: 0x19 / 255.0, green: 0xBE / 255.0, blue: 0xF4 / 255.0)
    }

    /// Category band color per brand spec.
    private var bandColor: Color {
        switch entity.category {
        case .underweight:  return brandBlue
        case .healthy:      return Color.green
        case .overweight:   return Color.orange.opacity(0.85)
        case .obesityI:     return Color.orange
        case .obesityII:    return Color(red: 0.95, green: 0.45, blue: 0.10)
        case .obesityIII:   return Color.red
        case .none:         return brandBlue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entity.bmiText)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(brandBlue)
                Text("BMI")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(bandColor)
                    .frame(width: 12, height: 12)
                Text(entity.categoryTitle)
                    .font(.subheadline.weight(.semibold))
                Text(entity.categoryRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(disclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .modifier(SnippetSurface())
    }
}

// MARK: - Snippet surface (Liquid Glass with fallback)

/// Applies a Liquid Glass background on iOS 26+, falling back to a rounded
/// material card on earlier systems. Never hard-requires iOS 26.
private struct SnippetSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
        } else {
            content
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}
