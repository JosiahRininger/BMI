//
//  EdgeCaseTests4.swift
//  BMICalculatorTests
//
//  Fourth batch: view-model derived canonical values across unit systems, the
//  metrics model's height/weight derivation, and BMIResult construction.
//

import Testing
import Foundation
@testable import BMICalculator

private func close(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) < tol }

// MARK: - CalculatorViewModel derived canonical values

@Suite("Calculator derived values")
@MainActor
struct CalculatorDerivedTests {

    @Test("Metric inputs map straight to canonical kg/m")
    func metric() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        vm.weight = 80
        vm.heightCentimeters = 180
        #expect(close(vm.weightKilograms, 80))
        #expect(close(vm.heightMeters, 1.80))
        #expect(close(vm.previewBMI, 80 / (1.8 * 1.8), 0.001))   // ≈ 24.69
    }

    @Test("Imperial weight converts to kilograms via the exact factor")
    func imperialWeight() {
        let vm = CalculatorViewModel(unitSystem: .imperial)
        vm.weight = 154
        #expect(close(vm.weightKilograms, BMICalculator.kilograms(fromPounds: 154)))
    }

    @Test("Stone weight converts to kilograms")
    func stoneWeight() {
        let vm = CalculatorViewModel(unitSystem: .stone)
        vm.weight = 11
        #expect(close(vm.weightKilograms, BMICalculator.kilograms(fromStone: 11)))
    }

    @Test("Imperial height uses feet + inches")
    func imperialHeight() {
        let vm = CalculatorViewModel(unitSystem: .imperial)
        vm.imperialHeight = ImperialHeight(feet: 6, inches: 0)
        #expect(close(vm.heightMeters, BMICalculator.meters(fromFeet: 6, inches: 0)))   // 1.8288
    }

    @Test("previewBMI equals the engine's BMI for the current inputs")
    func previewMatchesEngine() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        vm.weight = 70
        vm.heightCentimeters = 175
        #expect(close(vm.previewBMI, BMICalculator.bmi(weightKilograms: 70, heightMeters: 1.75), 0.0001))
    }
}

// MARK: - MetricsInputModel derived values

@Suite("Metrics model derived values")
@MainActor
struct MetricsModelDerivedTests {

    @Test("heightCentimetersMetric reflects metric cm directly")
    func metricHeight() {
        let m = MetricsInputModel(unitSystem: .metric)
        m.heightCentimeters = 168
        #expect(close(m.heightCentimetersMetric, 168))
    }

    @Test("heightCentimetersMetric converts imperial feet/inches to cm")
    func imperialHeight() {
        let m = MetricsInputModel(unitSystem: .imperial)
        m.imperialHeight = ImperialHeight(feet: 6, inches: 0)
        #expect(close(m.heightCentimetersMetric, 182.88, 0.1))   // 6 ft = 182.88 cm
    }

    @Test("weightKilograms converts per unit")
    func weight() {
        let imperial = MetricsInputModel(unitSystem: .imperial)
        imperial.weight = 154
        #expect(close(imperial.weightKilograms, BMICalculator.kilograms(fromPounds: 154)))

        let stone = MetricsInputModel(unitSystem: .stone)
        stone.weight = 11
        #expect(close(stone.weightKilograms, BMICalculator.kilograms(fromStone: 11)))
    }
}

// MARK: - BMIResult construction

@Suite("BMIResult construction")
struct BMIResultConstructionTests {

    @Test("rounded defaults to a 1-decimal rounding of value")
    func defaultRounded() {
        let r = BMIResult(value: 24.666, category: .healthy, standard: .standard)
        #expect(r.rounded == 24.7)
        #expect(r.displayString == "24.7")
    }

    @Test("An explicit rounded value is honored")
    func explicitRounded() {
        let r = BMIResult(value: 24.666, category: .healthy, standard: .standard, rounded: 25.0)
        #expect(r.rounded == 25.0)
        #expect(r.displayString == "25.0")
    }

    @Test("Equality covers all stored fields")
    func equality() {
        let a = BMIResult(value: 22.0, category: .healthy, standard: .standard)
        let b = BMIResult(value: 22.0, category: .healthy, standard: .standard)
        let c = BMIResult(value: 22.0, category: .healthy, standard: .asian)
        #expect(a == b)
        #expect(a != c)
    }

    @Test("displayString always shows exactly one decimal across magnitudes")
    func displayMagnitudes() {
        #expect(BMIResult(value: 9, category: .underweight, standard: .standard).displayString == "9.0")
        #expect(BMIResult(value: 100, category: .obesityIII, standard: .standard).displayString == "100.0")
    }
}
