//
//  MetricsInputModel.swift
//  BMICalculator — Features/Calculators
//
//  A small, observable holder for the body inputs the adjacent calculators share
//  with the main BMI calculator: unit system, weight, and height. It reuses the
//  app's `ImperialHeight` value type and the Core conversion helpers so values
//  round-trip exactly like the main `CalculatorViewModel`.
//
//  It also offers an *optional* HealthKit prefill: callers pass a
//  `HealthKitService` and, after the person opts in, we seed weight + height from
//  the most recent samples. Prefill never blocks — if Health is unavailable or
//  denied, we silently keep the manual defaults.
//
//  HEALTH / AD FIREWALL: these values never reach the ad layer.
//

import SwiftUI
import Observation

// MARK: - MetricsInputModel

/// Shared body inputs (unit system + weight + height) for the metrics screens.
///
/// Inputs are stored in the *display* unit currently selected and exposed in
/// canonical metric (kg, cm) via computed helpers, mirroring `CalculatorViewModel`.
@MainActor
@Observable
final class MetricsInputModel {

    // MARK: Unit system

    /// Currently selected unit system; flipping it converts the stored values so
    /// the represented body is unchanged.
    var unitSystem: UnitSystem {
        didSet {
            guard oldValue != unitSystem else { return }
            convert(from: oldValue, to: unitSystem)
        }
    }

    // MARK: Raw inputs (display unit)

    /// Weight in kilograms when metric, pounds when imperial.
    var weight: Double

    /// Height in centimetres (metric path).
    var heightCentimeters: Double

    /// Height in feet + inches (imperial path).
    var imperialHeight: ImperialHeight

    // MARK: Bounds (mirror CalculatorViewModel)

    var weightRange: ClosedRange<Double> {
        switch unitSystem {
        case .metric:   return 2...400      // kg
        case .imperial: return 4...880      // lb
        }
    }
    let heightCentimetersRange: ClosedRange<Double> = 50...250
    let feetRange: ClosedRange<Int> = 1...8
    let inchesRange: ClosedRange<Double> = 0...11.5

    // MARK: Init

    /// Seeds with a neutral mid-range adult (70 kg, 170 cm), matching the main
    /// calculator's defaults. The unit system defaults from the person's saved
    /// preference so the metrics screens open in the same units as the rest of
    /// the app.
    init(unitSystem: UnitSystem? = nil) {
        let resolved = unitSystem ?? Self.savedUnitSystem
        self.unitSystem = resolved

        if resolved == .metric {
            self.weight = 70
        } else {
            self.weight = (BMICalculator.pounds(fromKilograms: 70) * 10).rounded() / 10
        }
        self.heightCentimeters = 170
        self.imperialHeight = ImperialHeight(feet: 5, inches: 7)
    }

    /// The person's saved unit preference (falls back to metric).
    static var savedUnitSystem: UnitSystem {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.unitSystem)
        return UnitSystem(rawValue: raw ?? "") ?? .metric
    }

    // MARK: Canonical metric

    /// Weight in kilograms for the current inputs.
    var weightKilograms: Double {
        switch unitSystem {
        case .metric:   return weight
        case .imperial: return BMICalculator.kilograms(fromPounds: weight)
        }
    }

    /// Height in centimetres for the current inputs.
    var heightCentimetersMetric: Double {
        switch unitSystem {
        case .metric:
            return heightCentimeters
        case .imperial:
            return BMICalculator.meters(fromFeet: imperialHeight.feet,
                                        inches: imperialHeight.inches) * 100.0
        }
    }

    // MARK: HealthKit prefill

    /// Best-effort prefill of weight + height from the most recent HealthKit
    /// samples. Requests authorization contextually, then reads. Never throws and
    /// never blocks the UI: on unavailability / denial / no data it leaves the
    /// current values untouched.
    ///
    /// - Returns: `true` if at least one value was applied, else `false`.
    @discardableResult
    func prefillFromHealth(using service: HealthKitService) async -> Bool {
        guard service.isHealthDataAvailable else { return false }
        // Authorization is contextual; ignore the result of requesting and just
        // attempt the read (reads silently return .empty if not permitted).
        try? await service.requestAuthorization()

        let prefill = await service.latestPrefill()
        guard prefill.hasAnyValue else { return false }

        if let kg = prefill.weightKilograms {
            applyWeight(kilograms: kg)
        }
        if let meters = prefill.heightMeters {
            applyHeight(centimeters: meters * 100.0)
        }
        return true
    }

    /// Applies a kilogram weight into the active display unit.
    private func applyWeight(kilograms kg: Double) {
        switch unitSystem {
        case .metric:
            weight = clampToWeight((kg * 10).rounded() / 10)
        case .imperial:
            weight = clampToWeight((BMICalculator.pounds(fromKilograms: kg) * 10).rounded() / 10)
        }
    }

    /// Applies a centimetre height into the active display representation.
    private func applyHeight(centimeters cm: Double) {
        let clamped = min(max(cm, heightCentimetersRange.lowerBound),
                          heightCentimetersRange.upperBound)
        switch unitSystem {
        case .metric:
            heightCentimeters = clamped.rounded()
        case .imperial:
            imperialHeight = Self.imperial(fromCentimeters: clamped)
        }
    }

    private func clampToWeight(_ value: Double) -> Double {
        min(max(value, weightRange.lowerBound), weightRange.upperBound)
    }

    // MARK: Unit conversion

    private func convert(from old: UnitSystem, to new: UnitSystem) {
        switch (old, new) {
        case (.metric, .imperial):
            weight = (BMICalculator.pounds(fromKilograms: weight) * 10).rounded() / 10
            imperialHeight = Self.imperial(fromCentimeters: heightCentimeters)
        case (.imperial, .metric):
            weight = (BMICalculator.kilograms(fromPounds: weight) * 10).rounded() / 10
            let meters = BMICalculator.meters(fromFeet: imperialHeight.feet,
                                              inches: imperialHeight.inches)
            heightCentimeters = (meters * 100).rounded()
        default:
            break
        }
    }

    /// Splits a centimetre height into whole feet + half-inch-rounded inches.
    private static func imperial(fromCentimeters cm: Double) -> ImperialHeight {
        let totalInches = (cm / 100.0) / BMICalculator.metersPerInch
        let feet = Int(totalInches / 12.0)
        let inches = totalInches - Double(feet) * 12.0
        let roundedInches = (inches * 2).rounded() / 2
        if roundedInches >= 12 {
            return ImperialHeight(feet: feet + 1, inches: 0)
        }
        return ImperialHeight(feet: feet, inches: roundedInches)
    }
}

// MARK: - Shared body-input section

/// The reusable weight + height + unit-toggle block, optionally with a
/// HealthKit prefill affordance. Dropped into any metrics screen that needs body
/// inputs (everything except waist-to-height & frame size, which still need
/// height and so use it too).
struct BodyInputSection: View {

    @Bindable var model: MetricsInputModel

    /// When `true`, shows a "Use Health data" button that prefills weight/height.
    var showsHealthPrefill: Bool = true

    /// Which inputs to render. Frame size & waist-to-height don't need weight.
    var includesWeight: Bool = true

    @Environment(HealthKitService.self) private var healthKit

    @State private var isPrefilling = false

    var body: some View {
        VStack(spacing: 16) {
            UnitSystemToggle(unitSystem: $model.unitSystem)

            if includesWeight {
                WeightField(
                    value: $model.weight,
                    range: model.weightRange,
                    unitLabel: model.unitSystem.weightUnitLabel
                )
            }

            AdaptiveHeightField(
                unitSystem: model.unitSystem,
                centimeters: $model.heightCentimeters,
                imperialHeight: $model.imperialHeight,
                centimetersRange: model.heightCentimetersRange,
                feetRange: model.feetRange,
                inchesRange: model.inchesRange
            )

            if showsHealthPrefill, let healthKit, healthKit.isHealthDataAvailable {
                healthPrefillButton(service: healthKit)
            }
        }
    }

    private func healthPrefillButton(service: HealthKitService) -> some View {
        Button {
            guard !isPrefilling else { return }
            isPrefilling = true
            Task {
                await model.prefillFromHealth(using: service)
                isPrefilling = false
            }
        } label: {
            Label(isPrefilling ? "Reading Health…" : "Use Health data",
                  systemImage: "heart.text.square")
        }
        .buttonStyle(.dsCompactGlass)
        .disabled(isPrefilling)
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHint("Prefills weight and height from your most recent Health samples.")
    }
}
