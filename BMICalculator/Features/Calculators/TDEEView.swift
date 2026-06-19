//
//  TDEEView.swift
//  BMICalculator — Features/Calculators
//
//  Estimates basal metabolic rate (BMR) and total daily energy expenditure
//  (TDEE / "maintenance calories") from weight, height, age, sex, and activity
//  level, using the Core `EnergyCalculator` (Mifflin-St Jeor by default, with a
//  Harris-Benedict comparison line).
//
//  Inputs are captured in the person's unit system and converted to metric
//  (kg / cm) before the Core call. Results carry a person-first disclaimer.
//
//  HEALTH / AD FIREWALL: no value here is passed to the ad layer.
//

import SwiftUI

struct TDEEView: View {

    @State private var input = MetricsInputModel()
    @State private var sex: Sex = .male
    @State private var age: Int = 30
    @State private var activity: ActivityLevel = .moderate

    var body: some View {
        MetricsScreen(title: "Calorie needs") {
            BodyInputSection(model: input)

            SexPicker(sex: $sex)
            AgeField(years: $age)
            ActivityLevelPicker(activity: $activity)

            resultCard

            MetricsDisclaimerFooter()
        }
    }

    // MARK: Result

    private var resultCard: some View {
        let weightKg = input.weightKilograms
        let heightCm = input.heightCentimetersMetric

        let energy = EnergyCalculator.energy(
            weightKilograms: weightKg,
            heightCentimeters: heightCm,
            ageYears: age,
            sex: sex,
            activity: activity
        )
        let harrisBenedict = EnergyCalculator.harrisBenedictBMR(
            weightKilograms: weightKg,
            heightCentimeters: heightCm,
            ageYears: age,
            sex: sex
        )

        return MetricResultCard(
            title: "Maintenance calories (TDEE)",
            headline: Self.kcal(energy.tdee),
            unit: "kcal/day",
            caption: "About what you'd burn in a day at your selected activity level.",
            accent: Theme.brand,
            rows: [
                MetricResultRow("BMR (Mifflin-St Jeor)", "\(Self.kcal(energy.bmr)) kcal/day"),
                MetricResultRow("BMR (Harris-Benedict)", "\(Self.kcal(harrisBenedict)) kcal/day"),
                MetricResultRow("Activity factor", "× \(activity.multiplier.formatted(.number.precision(.fractionLength(0...3))))")
            ],
            disclaimer: MetricsDisclaimer.energy
        )
    }

    /// Rounds a calorie figure to the nearest 10 for an honest, non-spurious
    /// level of precision.
    private static func kcal(_ value: Double) -> String {
        let rounded = (value / 10).rounded() * 10
        return rounded.formatted(.number.precision(.fractionLength(0)))
    }
}

// MARK: - Preview

#Preview("TDEE") {
    NavigationStack {
        TDEEView()
    }
    .environment(HealthKitService())
}
