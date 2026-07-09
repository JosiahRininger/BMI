//
//  EdgeCaseTests.swift
//  BMICalculatorTests
//
//  Degenerate-input and boundary coverage from a first-run bug hunt: non-finite
//  values, domain guards, conversion clamping, profile-name uniqueness, and the
//  share sparkline shape. These lock in the hardening fixes so the same classes
//  can't regress.
//

import Testing
import Foundation
import SwiftUI
import SwiftData
@testable import BMICalculator

private func approx(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) < tol }

// MARK: - Engine: non-finite & degenerate inputs

@Suite("Engine degenerate inputs")
struct EngineDegenerateTests {

    @Test("bmi returns 0 for non-finite or non-physical input")
    func bmiGuards() {
        #expect(BMICalculator.bmi(weightKilograms: .nan, heightMeters: 1.75) == 0)
        #expect(BMICalculator.bmi(weightKilograms: .infinity, heightMeters: 1.75) == 0)
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: 0) == 0)
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: -1.5) == 0)
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: .nan) == 0)
    }

    @Test("bmi clamps a non-finite quotient from finite-but-extreme inputs")
    func bmiOverflowUnderflow() {
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: 1e-200) == 0)            // height² underflows
        #expect(BMICalculator.bmi(weightKilograms: .greatestFiniteMagnitude, heightMeters: 0.0001) == 0)
    }

    @Test("bmi stays correct for the normal case")
    func bmiNormal() {
        #expect(approx(BMICalculator.bmi(weightKilograms: 70, heightMeters: 1.75), 22.857, 0.001))
    }

    @Test("category never reads a non-finite value as severe obesity")
    func categoryNonFinite() {
        #expect(BMICalculator.category(forBMI: .nan) != .obesityIII)
        #expect(BMICalculator.category(forBMI: .infinity) != .obesityIII)
        #expect(BMICalculator.category(forBMI: .nan) == .healthy)
    }

    @Test("A negative finite BMI reads as underweight, not obesity")
    func categoryNegative() {
        #expect(BMICalculator.category(forBMI: -5) == .underweight)
    }

    @Test("result() of a non-finite input yields a clean 0.0, never literal nan/inf text")
    func resultNonFinite() {
        let r = BMICalculator.result(weightKilograms: .nan, heightMeters: 1.75)
        #expect(r.value == 0)
        #expect(r.category == .underweight)
        #expect(r.displayString == "0.0")
    }
}

// MARK: - Stone conversion crash guards

@Suite("Stone conversion crash guards")
struct StoneCrashGuardTests {

    @Test("stoneAndPounds traps nothing on non-finite or huge input")
    func guards() {
        #expect(BMICalculator.stoneAndPounds(fromKilograms: .nan).stone == 0)
        #expect(BMICalculator.stoneAndPounds(fromKilograms: .infinity).stone == 0)
        #expect(BMICalculator.stoneAndPounds(fromKilograms: -.infinity).stone == 0)
        #expect(BMICalculator.stoneAndPounds(fromKilograms: 1e308).stone == 0)
        let nan = BMICalculator.stoneAndPounds(fromKilograms: .nan)
        #expect(nan.stone == 0 && nan.pounds == 0)
    }

    @Test("Normal stone split still works")
    func normal() {
        let r = BMICalculator.stoneAndPounds(fromKilograms: BMICalculator.kilograms(fromStone: 11, pounds: 7))
        #expect(r.stone == 11)
        #expect(approx(r.pounds, 7, 0.001))
    }
}

// MARK: - Unit conversion clamping on toggle

@Suite("Unit conversion clamping")
@MainActor
struct ConversionClampTests {

    @Test("Max stone weight clamps into the imperial range on toggle")
    func stoneToImperialCeiling() {
        let vm = CalculatorViewModel(unitSystem: .stone)
        vm.weight = 63                       // stone ceiling
        vm.unitSystem = .imperial            // 63 st ≈ 882 lb, above the 880 floor
        #expect(vm.weight <= 880)
    }

    @Test("Max stone weight clamps into the metric range on toggle")
    func stoneToMetricCeiling() {
        let vm = CalculatorViewModel(unitSystem: .stone)
        vm.weight = 63
        vm.unitSystem = .metric              // 63 st ≈ 400 kg
        #expect(vm.weight <= 400)
    }

    @Test("A tall imperial height clamps into the metric wheel's range")
    func tallHeightClampsToWheel() {
        let vm = CalculatorViewModel(unitSystem: .imperial)
        vm.imperialHeight = ImperialHeight(feet: 8, inches: 5)   // ≈ 257 cm
        vm.unitSystem = .metric
        #expect(vm.heightCentimeters <= 250)                    // a selectable wheel option
        #expect(vm.heightCentimeters >= 50)
    }

    @Test("A full unit round-trip preserves the represented body")
    func roundTrip() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        vm.weight = 70
        let kg0 = vm.weightKilograms
        vm.unitSystem = .imperial
        vm.unitSystem = .metric
        #expect(approx(vm.weightKilograms, kg0, 0.6))
    }
}

// MARK: - Conversion identities

@Suite("Conversion identities")
struct ConversionIdentityTests {

    @Test("11 stone equals 154 pounds in kilograms")
    func stoneEqualsPounds() {
        #expect(approx(BMICalculator.kilograms(fromStone: 11), BMICalculator.kilograms(fromPounds: 154), 1e-9))
    }

    @Test("Zero feet/inches is zero meters; 39.3701 in ≈ 1 m")
    func feetInches() {
        #expect(BMICalculator.meters(fromFeet: 0, inches: 0) == 0)
        #expect(approx(BMICalculator.meters(fromFeet: 0, inches: 39.3701), 1.0, 0.0001))
    }

    @Test("Pounds↔kilograms round-trips exactly")
    func poundsRoundTrip() {
        for lb in [4.0, 154, 880] {
            #expect(approx(BMICalculator.pounds(fromKilograms: BMICalculator.kilograms(fromPounds: lb)), lb, 1e-9))
        }
    }
}
