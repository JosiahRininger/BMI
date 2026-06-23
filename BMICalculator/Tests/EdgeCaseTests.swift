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

// MARK: - Lean mass physical bounds

@Suite("Lean mass physical bounds")
struct LeanMassBoundsTests {

    @Test("Negative raw lean mass clamps to 0")
    func clampsNegative() {
        // james(200,150,male) raw = 1.1*200 - 128*(200/150)^2 ≈ -7.56
        #expect(LeanMassCalculator.james(weightKilograms: 200, heightCentimeters: 150, sex: .male) == 0)
    }

    @Test("Lean mass exceeding body weight clamps to body weight")
    func clampsToWeight() {
        // boer(2,250,male) raw ≈ 48.4 → clamp to 2
        #expect(LeanMassCalculator.boer(weightKilograms: 2, heightCentimeters: 250, sex: .male) == 2)
    }

    @Test("Non-positive weight or height yields 0")
    func guardsZero() {
        #expect(LeanMassCalculator.boer(weightKilograms: 0, heightCentimeters: 180, sex: .male) == 0)
        #expect(LeanMassCalculator.hume(weightKilograms: 80, heightCentimeters: 0, sex: .male) == 0)
        #expect(LeanMassCalculator.james(weightKilograms: -10, heightCentimeters: 180, sex: .female) == 0)
    }

    @Test("Normal estimates are unchanged by the clamp")
    func normalUnchanged() {
        #expect(approx(LeanMassCalculator.boer(weightKilograms: 80, heightCentimeters: 180, sex: .male), 61.42))
    }

    @Test("Across a grid of realistic inputs, 0 ≤ lean mass ≤ body weight")
    func invariant() {
        for w in [2.0, 50, 80, 200, 400] {
            for h in [50.0, 150, 180, 250] {
                for sex in Sex.allCases {
                    for v in [LeanMassCalculator.boer(weightKilograms: w, heightCentimeters: h, sex: sex),
                              LeanMassCalculator.james(weightKilograms: w, heightCentimeters: h, sex: sex),
                              LeanMassCalculator.hume(weightKilograms: w, heightCentimeters: h, sex: sex)] {
                        #expect(v >= 0 && v <= w, "lean mass \(v) out of [0,\(w)] for h=\(h) sex=\(sex)")
                    }
                }
            }
        }
    }
}

// MARK: - Domain guards (body fat, WHtR, frame, ideal weight)

@Suite("Calculator domain guards")
struct DomainGuardTests {

    @Test("US Navy body fat returns nil out of domain")
    func bodyFatDomain() {
        #expect(BodyFatCalculator.usNavyBodyFatPercent(sex: .male, heightCentimeters: 0, neckCentimeters: 38, waistCentimeters: 90) == nil)
        #expect(BodyFatCalculator.usNavyBodyFatPercent(sex: .male, heightCentimeters: 180, neckCentimeters: 40, waistCentimeters: 40) == nil) // waist == neck
        #expect(BodyFatCalculator.usNavyBodyFatPercent(sex: .female, heightCentimeters: 165, neckCentimeters: 32, waistCentimeters: 80, hipCentimeters: nil) == nil)
        #expect(BodyFatCalculator.usNavyBodyFatPercent(sex: .female, heightCentimeters: 165, neckCentimeters: 32, waistCentimeters: 80, hipCentimeters: 100) != nil)
    }

    @Test("Waist-to-height ratio guards a zero height")
    func whtrZeroHeight() {
        #expect(RatioCalculator.waistToHeightRatio(waistCentimeters: 80, heightCentimeters: 0) == 0)
    }

    @Test("WHtR category handles values below the lowest band")
    func whtrLowBand() {
        #expect(RatioCalculator.category(forWHtR: -1) == .possibleUnderweight)
        #expect(RatioCalculator.category(forWHtR: 0) == .possibleUnderweight)
    }

    @Test("Frame size guards a non-positive wrist")
    func frameZeroWrist() {
        #expect(FrameSizeCalculator.frame(heightCentimeters: 180, wristCentimeters: 0, sex: .male) == .medium)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 180, wristCentimeters: -5, sex: .female) == .medium)
    }

    @Test("Ideal weight clamps the per-inch term to zero below 5 ft")
    func idealWeightClamp() {
        let short = IdealWeightCalculator.idealWeights(heightCentimeters: 100, sex: .male)
        #expect(approx(short.devine, 50))   // over-60 term clamped to 0
        let zero = IdealWeightCalculator.idealWeights(heightCentimeters: 0, sex: .female)
        #expect(approx(zero.devine, 45.5))
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

    @Test("MetricsInputModel applies the same weight clamp")
    func metricsModelClamp() {
        let m = MetricsInputModel(unitSystem: .stone)
        m.weight = 63
        m.unitSystem = .imperial
        #expect(m.weightKilograms.isFinite)
        #expect(m.weight <= 880)
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

// MARK: - Profile name uniqueness

@Suite("Profile name uniqueness")
@MainActor
struct ProfileNameTests {

    private func freshStore() -> ProfileStore {
        ProfilePreferences.setActiveID(nil)
        return ProfileStore(container: PersistenceController.inMemory())
    }

    @Test("Case-insensitive duplicate names are rejected on add")
    func rejectsDuplicateAdd() {
        let store = freshStore()
        #expect(store.addProfile(name: "Alex", isPro: true) != nil)
        #expect(store.addProfile(name: "alex", isPro: true) == nil)   // duplicate
        #expect(store.profiles.count == 2)                            // Me + Alex
    }

    @Test("Renaming to another profile's name is a no-op")
    func rejectsDuplicateRename() {
        let store = freshStore()
        let alex = store.addProfile(name: "Alex", isPro: true)!
        store.rename(alex, to: "me")                                  // matches default "Me"
        #expect(store.profiles.first(where: { $0.id == alex.id })?.name == "Alex")
    }

    @Test("Renaming a profile to its own name (different case) is allowed")
    func allowsSelfRename() {
        let store = freshStore()
        let alex = store.addProfile(name: "Alex", isPro: true)!
        store.rename(alex, to: "ALEX")
        #expect(store.profiles.first(where: { $0.id == alex.id })?.name == "ALEX")
    }
}

// MARK: - Share sparkline shape

@Suite("Share sparkline shape")
struct SparklineShapeTests {

    private let rect = CGRect(x: 0, y: 0, width: 300, height: 220)

    @Test("An all-equal trend draws a centered flat line, not pinned to the bottom")
    func allEqualCentered() {
        let path = Sparkline(values: [25, 25, 25]).path(in: rect)
        #expect(approx(path.boundingRect.midY, rect.midY, 0.5))
        #expect(path.boundingRect.height < 0.5)                       // flat
    }

    @Test("A single value centers at midY")
    func singleValue() {
        let path = Sparkline(values: [25]).path(in: rect)
        #expect(approx(path.boundingRect.midY, rect.midY, 0.5))
    }

    @Test("A varying trend spans the full height (min at bottom, max at top)")
    func varyingSpansHeight() {
        let path = Sparkline(values: [10, 20]).path(in: rect)
        #expect(approx(path.boundingRect.minY, 0, 0.5))
        #expect(approx(path.boundingRect.maxY, rect.height, 0.5))
    }

    @Test("An empty trend produces an empty path")
    func emptyTrend() {
        #expect(Sparkline(values: []).path(in: rect).isEmpty)
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
