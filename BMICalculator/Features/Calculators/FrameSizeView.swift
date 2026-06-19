//
//  FrameSizeView.swift
//  BMICalculator — Features/Calculators
//
//  Body frame size (small / medium / large) from the wrist r-value
//  (height ÷ wrist circumference) via Core `FrameSizeCalculator`. Needs height,
//  wrist, and sex. This is the least rigorous metric in the set — a Metropolitan
//  Life actuarial heuristic — so it's framed descriptively, not diagnostically.
//
//  HEALTH / AD FIREWALL: no value here is passed to the ad layer.
//

import SwiftUI

struct FrameSizeView: View {

    @State private var input = MetricsInputModel()
    @State private var sex: Sex = .male

    /// Wrist circumference in the person's display unit (cm or in).
    @State private var wrist: Double = 17

    private var wristRange: ClosedRange<Double> {
        input.unitSystem == .metric ? 10...25 : 4...10
    }

    var body: some View {
        MetricsScreen(title: "Body frame size") {
            // Height only.
            BodyInputSection(model: input, includesWeight: false)

            SexPicker(sex: $sex)

            MeasurementField(
                title: "Wrist",
                systemImage: "hand.raised",
                value: $wrist,
                range: wristRange,
                unitLabel: MetricsUnit.lengthLabel(input.unitSystem)
            )

            measurementTip

            resultCard

            MetricsDisclaimerFooter()
        }
        .onChange(of: input.unitSystem) { old, new in
            guard old != new else { return }
            let cm = MetricsUnit.centimeters(fromDisplay: wrist, system: old)
            wrist = (MetricsUnit.displayLength(fromCentimeters: cm, system: new) * 10).rounded() / 10
        }
    }

    // MARK: Tip

    private var measurementTip: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 6) {
                Label("Where to measure", systemImage: "lightbulb")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Wrap a tape around your wrist just below the wrist bone, on the hand you write with.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Result

    private var resultCard: some View {
        let wristCm = MetricsUnit.centimeters(fromDisplay: wrist, system: input.unitSystem)
        let frame = FrameSizeCalculator.frame(
            heightCentimeters: input.heightCentimetersMetric,
            wristCentimeters: wristCm,
            sex: sex
        )

        return MetricResultCard(
            title: "Estimated frame",
            headline: frame.title,
            unit: nil,
            caption: "Based on the ratio of your height to your wrist size. It's loose context, not a measurement.",
            accent: Theme.brand,
            badge: "\(frame.title) frame",
            disclaimer: MetricsDisclaimer.frameSize
        )
    }
}

// MARK: - Preview

#Preview("Frame size") {
    NavigationStack {
        FrameSizeView()
    }
    .environment(HealthKitService())
}
