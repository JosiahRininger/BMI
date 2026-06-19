//
//  WaistHeightView.swift
//  BMICalculator — Features/Calculators
//
//  Waist-to-height ratio (WHtR) — a quick central-adiposity screen. Needs only
//  waist and height; sex is not part of the formula, so there's no sex picker
//  here. Uses Core `RatioCalculator` and the NICE NG246 bands.
//
//  HEALTH / AD FIREWALL: no value here is passed to the ad layer.
//

import SwiftUI

struct WaistHeightView: View {

    @State private var input = MetricsInputModel()

    /// Waist circumference in the person's display unit (cm or in).
    @State private var waist: Double = 86

    private var waistRange: ClosedRange<Double> {
        input.unitSystem == .metric ? 30...200 : 12...80
    }

    var body: some View {
        MetricsScreen(title: "Waist-to-height") {
            // Height only.
            BodyInputSection(model: input, includesWeight: false)

            MeasurementField(
                title: "Waist",
                systemImage: "figure.walk",
                value: $waist,
                range: waistRange,
                unitLabel: MetricsUnit.lengthLabel(input.unitSystem)
            )

            resultCard

            bandsCard

            MetricsDisclaimerFooter()
        }
        .onChange(of: input.unitSystem) { old, new in
            guard old != new else { return }
            let cm = MetricsUnit.centimeters(fromDisplay: waist, system: old)
            waist = (MetricsUnit.displayLength(fromCentimeters: cm, system: new) * 10).rounded() / 10
        }
    }

    // MARK: Result

    private var resultCard: some View {
        let heightCm = input.heightCentimetersMetric
        let waistCm = MetricsUnit.centimeters(fromDisplay: waist, system: input.unitSystem)
        let ratio = RatioCalculator.waistToHeightRatio(
            waistCentimeters: waistCm,
            heightCentimeters: heightCm
        )
        let category = RatioCalculator.category(forWHtR: ratio)

        return MetricResultCard(
            title: "Waist ÷ height",
            headline: ratio.formatted(.number.precision(.fractionLength(2))),
            unit: nil,
            caption: "A good rule of thumb: keep your waist to less than half your height (under 0.5).",
            accent: color(for: category),
            badge: category.title,
            rows: [
                MetricResultRow("Band range", category.displayRange)
            ],
            disclaimer: MetricsDisclaimer.waistHeight
        )
    }

    // MARK: Bands reference

    private var bandsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bands (NICE NG246)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)

                ForEach(CentralAdiposityCategory.allCases) { category in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(color(for: category))
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)
                        Text(category.title)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(category.displayRange)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(category.title)
                    .accessibilityValue(category.displayRange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Band colors
    //
    // Reuse the app's status palette so the bands read consistently with the
    // rest of the app without redefining any DesignSystem tokens.
    private func color(for category: CentralAdiposityCategory) -> Color {
        switch category {
        case .possibleUnderweight: return Theme.brand
        case .healthy:             return Theme.positive
        case .increasedRisk:       return Theme.warning
        case .highRisk:            return Theme.critical
        }
    }
}

// MARK: - Preview

#Preview("Waist-to-height") {
    NavigationStack {
        WaistHeightView()
    }
    .environment(HealthKitService())
}
