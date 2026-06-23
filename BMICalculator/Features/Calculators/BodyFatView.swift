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

    // Circumferences stored canonically in centimetres; displayed/edited in the
    // active unit via MetricsUnit.lengthBinding, so they always render at a
    // sensible magnitude regardless of the saved unit preference (no separate
    // display state to seed or reconcile on appear).
    @State private var neckCm: Double = MetricsDefaults.neckCentimeters
    @State private var waistCm: Double = MetricsDefaults.waistCentimeters
    @State private var hipCm: Double = MetricsDefaults.hipCentimeters

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
                value: MetricsUnit.lengthBinding(centimeters: $neckCm, system: input.unitSystem),
                range: circumferenceRange,
                unitLabel: lengthLabel
            )

            MeasurementField(
                title: "Waist",
                systemImage: "figure.walk",
                value: MetricsUnit.lengthBinding(centimeters: $waistCm, system: input.unitSystem),
                range: circumferenceRange,
                unitLabel: lengthLabel
            )

            if sex == .female {
                MeasurementField(
                    title: "Hip",
                    systemImage: "figure.arms.open",
                    value: MetricsUnit.lengthBinding(centimeters: $hipCm, system: input.unitSystem),
                    range: circumferenceRange,
                    unitLabel: lengthLabel
                )
            }

            measurementTip

            resultSection

            MetricsDisclaimerFooter()
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

        let percent = BodyFatCalculator.usNavyBodyFatPercent(
            sex: sex,
            heightCentimeters: heightCm,
            neckCentimeters: neckCm,
            waistCentimeters: waistCm,
            hipCentimeters: sex == .female ? hipCm : nil
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

}

// MARK: - Preview

#Preview("Body fat") {
    NavigationStack {
        BodyFatView()
    }
    .environment(HealthKitService())
}
