//
//  IdealWeightView.swift
//  BMICalculator — Features/Calculators
//
//  "Ideal" body-weight estimates from the four classic clinical formulas
//  (Devine, Robinson, Hamwi, Miller) via Core `IdealWeightCalculator`. Needs
//  height + sex. Presented deliberately as a RANGE with an explicit note that
//  these are old actuarial/pharmacologic conventions, NOT a personal target.
//
//  HEALTH / AD FIREWALL: no value here is passed to the ad layer.
//

import SwiftUI

struct IdealWeightView: View {

    @State private var input = MetricsInputModel()
    @State private var sex: Sex = .male

    var body: some View {
        MetricsScreen(title: "Ideal weight range") {
            // Height only (weight isn't an input to these formulas).
            BodyInputSection(model: input, includesWeight: false)

            SexPicker(sex: $sex)

            resultCard

            formulaBreakdown

            MetricsDisclaimerFooter()
        }
    }

    // MARK: Result

    private var ideal: IdealBodyWeight {
        IdealWeightCalculator.idealWeights(
            heightCentimeters: input.heightCentimetersMetric,
            sex: sex
        )
    }

    private var resultCard: some View {
        let i = ideal
        let system = input.unitSystem
        let low = MetricsUnit.weightString(kilograms: i.lowestKilograms, system: system)
        let high = MetricsUnit.weightString(kilograms: i.highestKilograms, system: system)
        let average = MetricsUnit.weightString(kilograms: i.averageKilograms, system: system)

        return MetricResultCard(
            title: "Estimated range across four formulas",
            headline: "\(low) – \(high)",
            unit: nil,
            caption: "A spread of estimates, not a single right answer. The midpoint is about \(average).",
            accent: Theme.brand,
            disclaimer: MetricsDisclaimer.idealWeight
        )
    }

    // MARK: Per-formula breakdown

    private var formulaBreakdown: some View {
        let i = ideal
        let system = input.unitSystem
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("By formula")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                row("Devine", i.devine, system)
                row("Robinson", i.robinson, system)
                row("Hamwi", i.hamwi, system)
                row("Miller", i.miller, system)

                Text("These formulas only apply above about 5 ft and were designed for clinical dosing, not as wellness goals.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ name: String, _ kg: Double, _ system: UnitSystem) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 8)
            Text(MetricsUnit.weightString(kilograms: kg, system: system))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityValue(MetricsUnit.weightString(kilograms: kg, system: system))
    }
}

// MARK: - Preview

#Preview("Ideal weight") {
    NavigationStack {
        IdealWeightView()
    }
    .environment(HealthKitService())
}
