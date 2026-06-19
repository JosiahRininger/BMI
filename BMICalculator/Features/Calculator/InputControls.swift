//
//  InputControls.swift
//  BMICalculator
//
//  Reusable input controls for the Calculator screen: the unit-system segmented
//  toggle, the health-standard overlay toggle, and adaptive weight/height entry
//  that reshapes itself for metric vs. imperial.
//
//  Styling consumes the shared DesignSystem where available, but every control
//  carries its own iOS 26 Liquid Glass path with a pre-26 material fallback so
//  the feature compiles and looks correct on iOS 18+.
//

import SwiftUI

// MARK: - Brand Palette (feature-local mirror of DesignSystem)
//
// DesignSystem (sibling module) owns the canonical brand tokens. These local
// constants mirror the contracted brand blue (#19BEF4) so the Calculator
// compiles independently; swap to `DesignSystem.brandBlue` once that symbol is
// finalized.

enum CalcPalette {
    /// Brand blue #19BEF4 (sRGB 0.098, 0.745, 0.957).
    static let brandBlue = Color(.sRGB, red: 0.098, green: 0.745, blue: 0.957, opacity: 1)
}

// MARK: - UnitSystemToggle

/// Segmented control switching between metric and imperial. Person-first,
/// non-judgmental, with a clear haptic-light feel.
struct UnitSystemToggle: View {
    @Binding var unitSystem: UnitSystem

    var body: some View {
        Picker("Unit system", selection: $unitSystem) {
            ForEach(UnitSystem.allCases) { system in
                Text(system.displayName).tag(system)
            }
        }
        .pickerStyle(.segmented)
        .tint(CalcPalette.brandBlue)
        .accessibilityLabel("Measurement units")
    }
}

// MARK: - HealthStandardToggle

/// Lets a person choose the universal cutoffs or the WHO Asian action points.
/// Kept compact and clearly labeled; the explanation lives near the result.
struct HealthStandardToggle: View {
    @Binding var standard: HealthStandard

    var body: some View {
        Picker("Health standard", selection: $standard) {
            Text("Standard").tag(HealthStandard.standard)
            Text("Asian").tag(HealthStandard.asian)
        }
        .pickerStyle(.segmented)
        .tint(CalcPalette.brandBlue)
        .accessibilityLabel("BMI standard")
        .accessibilityHint("Standard uses universal cutoffs. Asian uses WHO Asian action points.")
    }
}

// MARK: - WeightField

/// Adaptive weight entry. A stepper-backed numeric field with a unit suffix so
/// people can type precisely or nudge in 0.5 increments.
struct WeightField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unitLabel: String

    private var step: Double { 0.5 }

    var body: some View {
        LabeledInputRow(title: "Weight", systemImage: "scalemass") {
            HStack(spacing: 12) {
                TextField("Weight", value: $value, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.title3.monospacedDigit())
                    .frame(minWidth: 64)
                    .onChange(of: value) { _, newValue in
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }

                Text(unitLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                Stepper("Adjust weight", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weight")
        .accessibilityValue(Text(verbatim: String(format: "%.1f %@", value, unitLabel)))
    }
}

// MARK: - MetricHeightField

/// Height entry in centimeters via a bounded wheel picker for fast, low-error
/// input.
struct MetricHeightField: View {
    @Binding var centimeters: Double
    let range: ClosedRange<Double>

    /// Whole-centimeter options within range.
    private var options: [Int] {
        Array(Int(range.lowerBound)...Int(range.upperBound))
    }

    private var selection: Binding<Int> {
        Binding(
            get: { Int(centimeters.rounded()) },
            set: { centimeters = Double($0) }
        )
    }

    var body: some View {
        LabeledInputRow(title: "Height", systemImage: "ruler") {
            Picker("Height in centimeters", selection: selection) {
                ForEach(options, id: \.self) { cm in
                    Text("\(cm) cm").tag(cm)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
            .clipped()
        }
        .accessibilityLabel("Height")
        .accessibilityValue("\(Int(centimeters.rounded())) centimeters")
    }
}

// MARK: - ImperialHeightField

/// Height entry as two side-by-side wheels: feet and inches.
struct ImperialHeightField: View {
    @Binding var height: ImperialHeight
    let feetRange: ClosedRange<Int>
    let inchesRange: ClosedRange<Double>

    private var feetOptions: [Int] {
        Array(feetRange.lowerBound...feetRange.upperBound)
    }

    /// Inches in half-inch increments from 0 up to (but not including) 12.
    private var inchOptions: [Double] {
        stride(from: 0.0, through: 11.5, by: 0.5).map { $0 }
    }

    private var feetSelection: Binding<Int> {
        Binding(get: { height.feet }, set: { height.feet = $0 })
    }

    private var inchesSelection: Binding<Double> {
        Binding(get: { height.inches }, set: { height.inches = $0 })
    }

    var body: some View {
        LabeledInputRow(title: "Height", systemImage: "ruler") {
            HStack(spacing: 0) {
                Picker("Feet", selection: feetSelection) {
                    ForEach(feetOptions, id: \.self) { ft in
                        Text("\(ft) ft").tag(ft)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Inches", selection: inchesSelection) {
                    ForEach(inchOptions, id: \.self) { inch in
                        Text(inchLabel(inch)).tag(inch)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 120)
        }
        .accessibilityLabel("Height")
        .accessibilityValue("\(height.feet) feet \(inchLabel(height.inches))")
    }

    private func inchLabel(_ inch: Double) -> String {
        // Show whole inches without a trailing .0, halves as "x.5 in".
        if inch == inch.rounded() {
            return "\(Int(inch)) in"
        }
        return String(format: "%.1f in", inch)
    }
}

// MARK: - AdaptiveHeightField

/// Chooses the right height control for the active unit system.
struct AdaptiveHeightField: View {
    let unitSystem: UnitSystem
    @Binding var centimeters: Double
    @Binding var imperialHeight: ImperialHeight
    let centimetersRange: ClosedRange<Double>
    let feetRange: ClosedRange<Int>
    let inchesRange: ClosedRange<Double>

    var body: some View {
        switch unitSystem {
        case .metric:
            MetricHeightField(centimeters: $centimeters, range: centimetersRange)
        case .imperial:
            ImperialHeightField(height: $imperialHeight,
                                feetRange: feetRange,
                                inchesRange: inchesRange)
        }
    }
}

// MARK: - LabeledInputRow

/// A glassy container wrapping a labeled control. Centralizes the row chrome so
/// every input looks consistent. Liquid Glass on iOS 26, material fallback
/// below.
struct LabeledInputRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calcGlassRow()
    }
}

// MARK: - Glass Row Modifier

private struct CalcGlassRow: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.08), lineWidth: 1))
        }
    }
}

extension View {
    /// Applies the Calculator's input-row glass treatment with a pre-iOS-26
    /// material fallback.
    func calcGlassRow() -> some View { modifier(CalcGlassRow()) }
}

// MARK: - Previews

#Preview("Metric inputs") {
    @Previewable @State var unit: UnitSystem = .metric
    @Previewable @State var standard: HealthStandard = .standard
    @Previewable @State var weight: Double = 70
    @Previewable @State var cm: Double = 170
    @Previewable @State var imperial = ImperialHeight(feet: 5, inches: 7)

    return ScrollView {
        VStack(spacing: 16) {
            UnitSystemToggle(unitSystem: $unit)
            HealthStandardToggle(standard: $standard)
            WeightField(value: $weight, range: 2...400, unitLabel: unit.weightUnitLabel)
            AdaptiveHeightField(
                unitSystem: unit,
                centimeters: $cm,
                imperialHeight: $imperial,
                centimetersRange: 50...250,
                feetRange: 1...8,
                inchesRange: 0...11.5
            )
        }
        .padding()
    }
}

#Preview("Imperial inputs") {
    @Previewable @State var unit: UnitSystem = .imperial
    @Previewable @State var weight: Double = 154
    @Previewable @State var cm: Double = 170
    @Previewable @State var imperial = ImperialHeight(feet: 5, inches: 7)

    return ScrollView {
        VStack(spacing: 16) {
            UnitSystemToggle(unitSystem: $unit)
            WeightField(value: $weight, range: 4...880, unitLabel: unit.weightUnitLabel)
            AdaptiveHeightField(
                unitSystem: unit,
                centimeters: $cm,
                imperialHeight: $imperial,
                centimetersRange: 50...250,
                feetRange: 1...8,
                inchesRange: 0...11.5
            )
        }
        .padding()
    }
}
