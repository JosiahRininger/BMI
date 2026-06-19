//
//  BodyFatView.swift
//  BMICalculator — Features/Calculators
//
//  Estimates body-fat percentage with the US Navy circumference method
//  (`BodyFatCalculator.usNavyBodyFatPercent`). Needs height, neck, and waist for
//  everyone, plus hip for females. The Core function returns `nil` when inputs
//  are out of the formula's domain (e.g. waist ≤ neck); we surface that
//  gracefully and non-judgmentally rather than showing a bogus number.
//
//  Inputs are captured in the person's unit system and converted to centimetres
//  before the Core call.
//
//  HEALTH / AD FIREWALL: no value here is passed to the ad layer.
//

import SwiftUI

struct BodyFatView: View {

    @State private var input = MetricsInputModel()
    @State private var sex: Sex = .male

    // Circumferences in the person's *display* unit (cm or in).
    @State private var neck: Double = 38
    @State private var waist: Double = 86
    @State private var hip: Double = 96

    /// Sensible bounds for circumferences, in the active display unit.
    private var circumferenceRange: ClosedRange<Double> {
        input.unitSystem == .metric ? 20...200 : 8...80
    }

    var body: some View {
        MetricsScreen(title: "Body fat estimate") {
            // Only height is needed from the body section (no weight).
            BodyInputSection(model: input, includesWeight: false)

            SexPicker(sex: $sex)

            MeasurementField(
                title: "Neck",
                systemImage: "figure.stand",
                value: $neck,
                range: circumferenceRange,
                unitLabel: lengthLabel
            )

            MeasurementField(
                title: "Waist",
                systemImage: "figure.walk",
                value: $waist,
                range: circumferenceRange,
                unitLabel: lengthLabel
            )

            if sex == .female {
                MeasurementField(
                    title: "Hip",
                    systemImage: "figure.arms.open",
                    value: $hip,
                    range: circumferenceRange,
                    unitLabel: lengthLabel
                )
            }

            measurementTip

            resultSection

            MetricsDisclaimerFooter()
        }
        // When switching unit systems, convert the circumference values so the
        // represented body is unchanged (the body section already converts
        // height/weight; circumferences live here).
        .onChange(of: input.unitSystem) { old, new in
            convertCircumferences(from: old, to: new)
        }
    }

    private var lengthLabel: String { MetricsUnit.lengthLabel(input.unitSystem) }

    // MARK: Tip

    private var measurementTip: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("Measuring tips", systemImage: "lightbulb")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Use a soft tape, snug but not tight. Neck: just below the larynx. Waist: at the navel. Hip: at the widest point. The estimate works best when the waist is larger than the neck.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Result

    @ViewBuilder
    private var resultSection: some View {
        let heightCm = input.heightCentimetersMetric
        let neckCm = MetricsUnit.centimeters(fromDisplay: neck, system: input.unitSystem)
        let waistCm = MetricsUnit.centimeters(fromDisplay: waist, system: input.unitSystem)
        let hipCm = sex == .female
            ? MetricsUnit.centimeters(fromDisplay: hip, system: input.unitSystem)
            : nil

        let percent = BodyFatCalculator.usNavyBodyFatPercent(
            sex: sex,
            heightCentimeters: heightCm,
            neckCentimeters: neckCm,
            waistCentimeters: waistCm,
            hipCentimeters: hipCm
        )

        if let percent, percent.isFinite, percent > 0, percent < 100 {
            MetricResultCard(
                title: "Estimated body fat",
                headline: percent.formatted(.number.precision(.fractionLength(1))),
                unit: "%",
                caption: "US Navy circumference method. Treat it as a ballpark, not an exact figure.",
                accent: Theme.brand,
                disclaimer: MetricsDisclaimer.bodyFat
            )
        } else {
            MetricUnavailableCard(
                title: "We can't estimate this yet",
                message: unavailableMessage
            )
        }
    }

    /// Explains, non-judgmentally, why no estimate could be produced and what to
    /// check — without implying anything is wrong with the person.
    private var unavailableMessage: String {
        if sex == .male {
            return "This method needs your waist measurement to be larger than your neck. Double-check both with a tape measure and try again."
        } else {
            return "This method needs your waist plus hip to be larger than your neck. Double-check your neck, waist, and hip measurements and try again."
        }
    }

    // MARK: Unit conversion for circumferences

    private func convertCircumferences(from old: UnitSystem, to new: UnitSystem) {
        guard old != new else { return }
        func convert(_ v: Double) -> Double {
            let cm = MetricsUnit.centimeters(fromDisplay: v, system: old)
            let display = MetricsUnit.displayLength(fromCentimeters: cm, system: new)
            return (display * 10).rounded() / 10
        }
        neck = convert(neck)
        waist = convert(waist)
        hip = convert(hip)
    }
}

// MARK: - Preview

#Preview("Body fat") {
    NavigationStack {
        BodyFatView()
    }
    .environment(HealthKitService())
}
