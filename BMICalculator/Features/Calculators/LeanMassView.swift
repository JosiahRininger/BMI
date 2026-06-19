//
//  LeanMassView.swift
//  BMICalculator — Features/Calculators
//
//  Lean body mass (LBM) estimates from the Boer, James, and Hume formulas via
//  Core `LeanMassCalculator`. Needs weight + height + sex. Presented as a RANGE
//  across the three formulas, with a note that they are estimates.
//
//  HEALTH / AD FIREWALL: no value here is passed to the ad layer.
//

import SwiftUI

struct LeanMassView: View {

    @State private var input = MetricsInputModel()
    @State private var sex: Sex = .male

    var body: some View {
        MetricsScreen(title: "Lean body mass") {
            BodyInputSection(model: input)

            SexPicker(sex: $sex)

            resultCard

            formulaBreakdown

            MetricsDisclaimerFooter()
        }
    }

    // MARK: Estimates

    private var estimates: (boer: Double, james: Double, hume: Double) {
        let w = input.weightKilograms
        let h = input.heightCentimetersMetric
        return (
            LeanMassCalculator.boer(weightKilograms: w, heightCentimeters: h, sex: sex),
            LeanMassCalculator.james(weightKilograms: w, heightCentimeters: h, sex: sex),
            LeanMassCalculator.hume(weightKilograms: w, heightCentimeters: h, sex: sex)
        )
    }

    // MARK: Result

    private var resultCard: some View {
        let e = estimates
        let values = [e.boer, e.james, e.hume]
        let system = input.unitSystem
        let low = MetricsUnit.weightString(kilograms: values.min() ?? e.boer, system: system)
        let high = MetricsUnit.weightString(kilograms: values.max() ?? e.boer, system: system)

        let weightKg = input.weightKilograms
        let bodyFatPercent = weightKg > 0
            ? (1 - e.boer / weightKg) * 100
            : 0

        return MetricResultCard(
            title: "Estimated lean mass (range)",
            headline: "\(low) – \(high)",
            unit: nil,
            caption: "Roughly the non-fat part of your body (muscle, bone, organs, water).",
            accent: Theme.brand,
            rows: bodyFatPercent.isFinite && bodyFatPercent > 0 && bodyFatPercent < 100
                ? [MetricResultRow("Implied body fat (Boer)", "\(bodyFatPercent.formatted(.number.precision(.fractionLength(0))))%")]
                : [],
            disclaimer: MetricsDisclaimer.leanMass
        )
    }

    // MARK: Per-formula breakdown

    private var formulaBreakdown: some View {
        let e = estimates
        let system = input.unitSystem
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("By formula")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                row("Boer", e.boer, system)
                row("James", e.james, system)
                row("Hume", e.hume, system)

                Text("Boer is the most widely used; the three rarely agree exactly, which is why we show a range.")
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

#Preview("Lean mass") {
    NavigationStack {
        LeanMassView()
    }
    .environment(HealthKitService())
}
