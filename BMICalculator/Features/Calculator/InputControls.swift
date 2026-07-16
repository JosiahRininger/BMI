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
    /// The app accent. Follows the chosen Pro theme via `Theme.brand` (defaults
    /// to brand blue #19BEF4) so the Calculator's tints recolor with everything
    /// else. Used only as an accent here — never as a category/band color.
    static var brandBlue: Color { Theme.brand }
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

/// Adaptive weight entry. The number sits in an obviously-tappable field (rounded
/// chrome + edit glyph + focus highlight) so it reads as "tap to type", with a
/// −/+ stepper alongside for fine 0.5-unit nudges.
struct WeightField: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let unitLabel: String

    @FocusState private var isEditing: Bool

    private var step: Double { 0.5 }

    var body: some View {
        LabeledInputRow(title: "Weight", systemImage: "scalemass") {
            HStack(spacing: 12) {
                editableField
                Spacer(minLength: 0)
                Stepper("Adjust weight", value: $value, in: range, step: step)
                    .labelsHidden()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weight")
        .accessibilityValue(Text(verbatim: String(format: "%.1f %@", value, unitLabel)))
        .accessibilityHint("Tap to type a value, or swipe up or down to adjust.")
        // Make the promised swipe gesture real: combining the children into one
        // element drops the Stepper's operability, so wire the increment/decrement
        // back with an adjustable action clamped to the same range and step.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + step, range.upperBound)
            case .decrement: value = max(value - step, range.lowerBound)
            @unknown default: break
            }
        }
    }

    /// The tappable number field. The rounded chrome + edit glyph signal that the
    /// number is editable; tapping anywhere in it opens the number pad.
    private var editableField: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 6) {
            Image(systemName: "square.and.pencil")
                .font(.footnote)
                .foregroundStyle(isEditing ? CalcPalette.brandBlue : .secondary)
                .accessibilityHidden(true)

            TextField("Weight", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(CalcPalette.brandBlue)
                .focused($isEditing)
                .frame(minWidth: 52)
                // Clamp to the valid range only when editing FINISHES. Clamping on
                // every keystroke turned a leading "1" (below the imperial 4 lb
                // floor) into "4", so "185" became "485".
                .onChange(of: isEditing) { _, editing in
                    if !editing {
                        value = min(max(value, range.lowerBound), range.upperBound)
                    }
                }

            Text(unitLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .background(shape.fill(isEditing ? CalcPalette.brandBlue.opacity(0.10)
                                         : Color.primary.opacity(0.05)))
        .overlay(shape.strokeBorder(isEditing ? CalcPalette.brandBlue
                                              : Color.primary.opacity(0.14),
                                    lineWidth: isEditing ? 2 : 1))
        .contentShape(shape)
        // Tapping anywhere in the field (not just the tiny number) focuses it.
        .onTapGesture { isEditing = true }
        .animation(.easeInOut(duration: 0.15), value: isEditing)
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
            ZStack {
                heightSelectionBand
                Picker("Height in centimeters", selection: selection) {
                    ForEach(options, id: \.self) { cm in
                        Text("\(cm) cm").tag(cm)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .clipped()
            }
        }
        .accessibilityLabel("Height")
        .accessibilityValue("\(Int(centimeters.rounded())) centimeters")
        .accessibilityHint("Scroll to change")
    }
}

/// A subtle brand-tinted band behind a wheel's centered row, so the selected
/// value reads as a live, scrollable selection (matches the weight field's active
/// tint). Non-interactive so it never intercepts the wheel's scroll gesture.
private var heightSelectionBand: some View {
    RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(CalcPalette.brandBlue.opacity(0.08))
        .frame(height: 38)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
            ZStack {
                heightSelectionBand
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
        }
        .accessibilityLabel("Height")
        .accessibilityValue("\(height.feet) feet \(inchLabel(height.inches))")
        .accessibilityHint("Scroll to change")
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
        case .imperial, .stone:
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
                .fixedSize(horizontal: false, vertical: true)
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
                .overlay(shape.strokeBorder(Theme.separator.opacity(0.6), lineWidth: 1))
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
