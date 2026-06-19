//
//  MetricsInputControls.swift
//  BMICalculator — Features/Calculators
//
//  Shared, reusable UI pieces for the "More metrics" calculators (TDEE, body
//  fat, waist-to-height, ideal weight, lean mass, frame size). These intentionally
//  mirror the look of the main Calculator's `LabeledInputRow` / glass styling so
//  the new screens feel native to the app, while staying entirely inside
//  Features/Calculators/ (Core, DesignSystem, and other features are untouched).
//
//  All inputs are captured in the person's chosen unit system and converted to
//  the Core API's canonical metric (kg / cm) at calculation time. Every result
//  screen also surfaces a person-first screening disclaimer.
//
//  HEALTH / AD FIREWALL (App Store Guideline 5.1.3): nothing in these screens —
//  no height, weight, circumference, body-fat, energy, or other health value —
//  is ever passed to the ad SDK or used for ad targeting. These screens never
//  touch the ad layer at all.
//

import SwiftUI

// MARK: - Metrics Disclaimer Copy

/// Person-first, non-judgmental screening-tool disclaimers for the adjacent
/// calculators. Kept separate from the BMI-specific `Disclaimer.full` (defined in
/// Settings) because these metrics carry their own caveats, but they share the
/// same framing: an estimate, not a diagnosis; talk to a healthcare provider.
enum MetricsDisclaimer {

    /// The persistent footer shown on the "More metrics" hub.
    static let hub = "These are screening estimates, not diagnoses. They can be off for athletes, older adults, during pregnancy, and across body types. For anything about your health, talk to a healthcare provider."

    /// A one-line caveat for the energy (BMR / TDEE) result.
    static let energy = "These calorie figures are estimates, not a diagnosis or a prescription. Needs vary day to day — talk to a healthcare provider or dietitian before making big changes."

    /// A one-line caveat for the US Navy body-fat result.
    static let bodyFat = "A circumference estimate, not a diagnosis, and accurate to only about ±3–4 points versus a clinical scan. Talk to a healthcare provider."

    /// A one-line caveat for the waist-to-height result.
    static let waistHeight = "A screening estimate of central adiposity, not a diagnosis. Talk to a healthcare provider about what it means for you."

    /// A one-line caveat for the ideal-weight result.
    static let idealWeight = "These are old clinical/actuarial formulas shown as a range of estimates — not a personal target or a diagnosis. A healthy weight is individual; talk to a healthcare provider."

    /// A one-line caveat for the lean-mass result.
    static let leanMass = "Estimates from body-composition formulas, shown as a range — not a measurement or a diagnosis. Talk to a healthcare provider."

    /// A one-line caveat for the body-frame result.
    static let frameSize = "A rough actuarial heuristic, not a measurement or a diagnosis. Use it only as loose context."
}

// MARK: - MetricsDisclaimerFooter

/// The persistent person-first disclaimer footer used across the metrics screens.
struct MetricsDisclaimerFooter: View {
    var text: String = MetricsDisclaimer.hub

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - SexPicker

/// A segmented control for biological sex, required by the sex-specific formulas.
/// Person-first label; the explanation that some formulas need it lives near the
/// result.
struct SexPicker: View {
    @Binding var sex: Sex

    var body: some View {
        LabeledInputRow(title: "Sex", systemImage: "person") {
            Picker("Sex", selection: $sex) {
                ForEach(Sex.allCases) { sex in
                    Text(sex.title).tag(sex)
                }
            }
            .pickerStyle(.segmented)
            .tint(Theme.brand)
        }
        .accessibilityHint("Some formulas use sex-specific coefficients.")
    }
}

// MARK: - AgeField

/// Whole-year age entry via a bounded wheel, used by the energy calculator.
struct AgeField: View {
    @Binding var years: Int
    var range: ClosedRange<Int> = 13...100

    private var options: [Int] { Array(range.lowerBound...range.upperBound) }

    var body: some View {
        LabeledInputRow(title: "Age", systemImage: "calendar") {
            Picker("Age in years", selection: $years) {
                ForEach(options, id: \.self) { year in
                    Text("\(year) yr").tag(year)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
        .accessibilityLabel("Age")
        .accessibilityValue("\(years) years")
    }
}

// MARK: - ActivityLevelPicker

/// A menu picker for the activity multiplier used to turn BMR into TDEE.
struct ActivityLevelPicker: View {
    @Binding var activity: ActivityLevel

    var body: some View {
        LabeledInputRow(title: "Activity level", systemImage: "figure.walk") {
            Menu {
                Picker("Activity level", selection: $activity) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(activity.subtitle)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.brand)
                }
                .contentShape(Rectangle())
            }
        }
        .accessibilityLabel("Activity level")
        .accessibilityValue("\(activity.title), \(activity.subtitle)")
    }
}

// MARK: - MeasurementField

/// A generic length-measurement entry (neck, waist, hip, wrist), shown in cm or
/// inches depending on the unit system. The binding stays in the *display* unit;
/// callers convert to centimetres for the Core API via `MetricsUnit`.
struct MeasurementField: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unitLabel: String

    private var step: Double { 0.5 }

    var body: some View {
        LabeledInputRow(title: title, systemImage: systemImage) {
            HStack(spacing: 12) {
                TextField(title, value: $value, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit())
                    .frame(minWidth: 64)
                    .foregroundStyle(Theme.textPrimary)
                    .onChange(of: value) { _, newValue in
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }

                Text(unitLabel)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 28, alignment: .leading)

                Stepper("Adjust \(title.lowercased())", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(Text(verbatim: String(format: "%.1f %@", value, unitLabel)))
    }
}

// MARK: - MetricsUnit (display ⇄ canonical metric)

/// Small unit helpers shared by the metrics screens. The Core API is metric
/// (kg / cm), so imperial inputs are converted before any Core call.
///
/// Reuses the Core conversion constants/helpers (`BMICalculator.kilograms`,
/// `.meters`, `.metersPerInch`) so there is one source of truth for factors.
enum MetricsUnit {

    /// Length unit label for the active system ("cm" / "in").
    static func lengthLabel(_ system: UnitSystem) -> String {
        system == .metric ? "cm" : "in"
    }

    /// Converts a length entered in the active unit to centimetres.
    static func centimeters(fromDisplay value: Double, system: UnitSystem) -> Double {
        switch system {
        case .metric:   return value
        case .imperial: return value * (BMICalculator.metersPerInch * 100.0) // in → cm
        }
    }

    /// Converts centimetres to the active display unit (for prefill / round-trips).
    static func displayLength(fromCentimeters cm: Double, system: UnitSystem) -> Double {
        switch system {
        case .metric:   return cm
        case .imperial: return cm / (BMICalculator.metersPerInch * 100.0) // cm → in
        }
    }

    /// Converts a weight entered in the active unit to kilograms.
    static func kilograms(fromDisplay value: Double, system: UnitSystem) -> Double {
        switch system {
        case .metric:   return value
        case .imperial: return BMICalculator.kilograms(fromPounds: value)
        }
    }

    /// Converts kilograms to the active display unit.
    static func displayWeight(fromKilograms kg: Double, system: UnitSystem) -> Double {
        switch system {
        case .metric:   return kg
        case .imperial: return BMICalculator.pounds(fromKilograms: kg)
        }
    }

    /// A formatted weight string in the active unit, e.g. "70.5 kg" / "155 lb".
    static func weightString(kilograms kg: Double, system: UnitSystem) -> String {
        let value = displayWeight(fromKilograms: kg, system: system)
        let fractionDigits = system == .metric ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(0...fractionDigits)))
            + " " + system.weightUnitLabel
    }
}

// MARK: - MetricResultCard

/// A clean, glassy result card with a headline figure, optional unit, an optional
/// category chip, optional supporting rows, and a one-line disclaimer. Used by the
/// metrics screens so every result reads consistently.
struct MetricResultCard: View {
    let title: String
    let headline: String
    var unit: String? = nil
    var caption: String? = nil
    var accent: Color = Theme.brand
    var badge: String? = nil
    var rows: [MetricResultRow] = []
    let disclaimer: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(headline)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    if let unit {
                        Text(unit)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(title)
                .accessibilityValue(unit.map { "\(headline) \($0)" } ?? headline)

                if let badge {
                    Text(badge)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(accent)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule(style: .continuous).fill(accent.opacity(0.16))
                        )
                }

                if let caption {
                    Text(caption)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !rows.isEmpty {
                    Divider().overlay(Theme.separator)
                    VStack(spacing: 10) {
                        ForEach(rows) { row in
                            HStack {
                                Text(row.label)
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer(minLength: 12)
                                Text(row.value)
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textPrimary)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(row.label)
                            .accessibilityValue(row.value)
                        }
                    }
                }

                Text(disclaimer)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A single labeled value row inside a `MetricResultCard`.
struct MetricResultRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String

    init(_ label: String, _ value: String) {
        self.label = label
        self.value = value
    }
}

// MARK: - MetricUnavailableCard

/// A non-judgmental card shown when a calculation can't be produced (e.g. the US
/// Navy body-fat formula is out of domain for the entered measurements). Explains
/// what to adjust without implying anything is wrong with the person.
struct MetricUnavailableCard: View {
    let title: String
    let message: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: "questionmark.circle")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Screen Scaffold

/// Shared scaffold for a single-calculator screen: a brand-tinted scrolling
/// surface with consistent padding and an inline navigation title. Keeps each
/// calculator view focused on its own inputs + result.
struct MetricsScreen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                content()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(metricsBackground)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var metricsBackground: some View {
        LinearGradient(
            colors: [Theme.brand.opacity(0.10), Color.clear],
            startPoint: .top,
            endPoint: .center
        )
        .background(Theme.background)
        .ignoresSafeArea()
    }
}
