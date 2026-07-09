//
//  BMICalculatorTests.swift
//  BMICalculatorTests
//
//  Boundary-focused tests for the Core engine using the Swift Testing
//  framework. Category boundaries are half-open: a value exactly on a
//  boundary belongs to the HIGHER category.
//

import Testing
import Foundation
import SwiftData
@testable import BMICalculator

// MARK: - Standard category boundaries

@Suite("Standard category boundaries")
struct StandardCategoryBoundaryTests {

    @Test("Just below 18.5 is underweight")
    func underweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 18.49) == .underweight)
    }

    @Test("Exactly 18.5 is healthy")
    func healthyLowerEdge() {
        #expect(BMICalculator.category(forBMI: 18.5) == .healthy)
    }

    @Test("Just below 25 is healthy")
    func healthyUpperEdge() {
        #expect(BMICalculator.category(forBMI: 24.99) == .healthy)
    }

    @Test("Exactly 25.0 is overweight")
    func overweightLowerEdge() {
        #expect(BMICalculator.category(forBMI: 25.0) == .overweight)
    }

    @Test("Just below 30 is overweight")
    func overweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 29.99) == .overweight)
    }

    @Test("Exactly 30.0 is obesity class 1")
    func obesityILowerEdge() {
        #expect(BMICalculator.category(forBMI: 30.0) == .obesityI)
    }

    @Test("Just below 35 is obesity class 1")
    func obesityIUpperEdge() {
        #expect(BMICalculator.category(forBMI: 34.99) == .obesityI)
    }

    @Test("Exactly 35.0 is obesity class 2")
    func obesityIILowerEdge() {
        #expect(BMICalculator.category(forBMI: 35.0) == .obesityII)
    }

    @Test("Just below 40 is obesity class 2")
    func obesityIIUpperEdge() {
        #expect(BMICalculator.category(forBMI: 39.99) == .obesityII)
    }

    @Test("Exactly 40.0 is obesity class 3")
    func obesityIIILowerEdge() {
        #expect(BMICalculator.category(forBMI: 40.0) == .obesityIII)
    }

    @Test("Well above 40 is obesity class 3")
    func obesityIIIDeep() {
        #expect(BMICalculator.category(forBMI: 55.2) == .obesityIII)
    }

    @Test("Zero BMI is underweight")
    func zeroIsUnderweight() {
        #expect(BMICalculator.category(forBMI: 0) == .underweight)
    }
}

// MARK: - Asian (WHO action point) category boundaries

@Suite("Asian category boundaries")
struct AsianCategoryBoundaryTests {

    @Test("Just below 18.5 is underweight")
    func underweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 18.49, standard: .asian) == .underweight)
    }

    @Test("Exactly 18.5 is healthy")
    func healthyLowerEdge() {
        #expect(BMICalculator.category(forBMI: 18.5, standard: .asian) == .healthy)
    }

    @Test("Just below 23 is healthy")
    func healthyUpperEdge() {
        #expect(BMICalculator.category(forBMI: 22.9, standard: .asian) == .healthy)
    }

    @Test("Exactly 23.0 is overweight")
    func overweightLowerEdge() {
        #expect(BMICalculator.category(forBMI: 23.0, standard: .asian) == .overweight)
    }

    @Test("Just below 27.5 is overweight")
    func overweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 27.4, standard: .asian) == .overweight)
    }

    @Test("Exactly 27.5 is obesity class 1")
    func obesityILowerEdge() {
        #expect(BMICalculator.category(forBMI: 27.5, standard: .asian) == .obesityI)
    }

    @Test("Asian standard never produces class 2 or 3")
    func asianNeverHigherClasses() {
        // Even a very high BMI maps to obesityI under the Asian overlay.
        #expect(BMICalculator.category(forBMI: 45.0, standard: .asian) == .obesityI)
        #expect(BMICalculator.category(forBMI: 60.0, standard: .asian) == .obesityI)
    }
}

// MARK: - Core BMI math

@Suite("BMI computation")
struct BMIComputationTests {

    @Test("Known metric value: 70 kg at 1.75 m ≈ 22.86")
    func knownMetric() {
        let value = BMICalculator.bmi(weightKilograms: 70, heightMeters: 1.75)
        #expect(abs(value - 22.857) < 0.001)
        #expect(BMICalculator.category(forBMI: value) == .healthy)
    }

    @Test("Non-positive height yields zero, not a crash or NaN")
    func zeroHeightGuard() {
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: 0) == 0)
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: -1.5) == 0)
    }
}

// MARK: - Unit conversions

@Suite("Unit conversions")
struct ConversionTests {

    @Test("215 lb at 5 ft 9 in is ≈ 31.7 BMI (obesity class 1)")
    func imperialEndToEnd() {
        let kg = BMICalculator.kilograms(fromPounds: 215)
        let meters = BMICalculator.meters(fromFeet: 5, inches: 9)
        let result = BMICalculator.result(weightKilograms: kg, heightMeters: meters)

        #expect(abs(result.rounded - 31.7) < 0.05)
        #expect(result.category == .obesityI)
        #expect(result.standard == .standard)
    }

    @Test("Pounds to kilograms uses the exact factor")
    func poundsToKilograms() {
        #expect(abs(BMICalculator.kilograms(fromPounds: 100) - 45.359237) < 0.000001)
    }

    @Test("Kilograms to pounds round-trips")
    func kilogramsToPounds() {
        let kg = BMICalculator.kilograms(fromPounds: 154)
        #expect(abs(BMICalculator.pounds(fromKilograms: kg) - 154) < 0.000001)
    }

    @Test("Feet and inches to meters: 6 ft 0 in ≈ 1.8288 m")
    func feetInchesToMeters() {
        #expect(abs(BMICalculator.meters(fromFeet: 6, inches: 0) - 1.8288) < 0.0001)
    }

    @Test("Feet and inches to meters: 5 ft 9 in ≈ 1.7526 m")
    func feetInchesToMetersFractional() {
        #expect(abs(BMICalculator.meters(fromFeet: 5, inches: 9) - 1.7526) < 0.0001)
    }
}

// MARK: - Result rounding & display

@Suite("Result rounding and display")
struct ResultRoundingTests {

    @Test("Rounded value is one decimal place")
    func roundsToOneDecimal() {
        let result = BMICalculator.result(weightKilograms: 70, heightMeters: 1.75)
        #expect(result.rounded == 22.9)
    }

    @Test("Display string always shows one decimal")
    func displayStringFormatting() {
        let result = BMIResult(value: 22.0, category: .healthy, standard: .standard)
        #expect(result.displayString == "22.0")
    }

    @Test("roundedToOneDecimal helper rounds half away from zero")
    func roundingHelper() {
        #expect(BMIResult.roundedToOneDecimal(31.65) == 31.7)
        #expect(BMIResult.roundedToOneDecimal(22.857) == 22.9)
    }
}

// MARK: - Codable round-trip

@Suite("Codable round-trips")
struct CodableTests {

    @Test("BMIResult survives JSON encode/decode")
    func resultRoundTrips() throws {
        let original = BMICalculator.result(weightKilograms: 80, heightMeters: 1.8, standard: .asian)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BMIResult.self, from: data)
        #expect(decoded == original)
    }

    @Test("Enums encode to their raw values")
    func enumRawValues() {
        #expect(UnitSystem.metric.rawValue == "metric")
        #expect(HealthStandard.asian.rawValue == "asian")
        #expect(BMICategory.obesityIII.rawValue == "obesityIII")
    }
}

// MARK: - Healthy weight range for height

@Suite("Healthy weight range")
struct HealthyWeightRangeTests {

    private func approx(_ a: Double, _ b: Double, _ tol: Double = 0.001) -> Bool { abs(a - b) < tol }

    @Test("Healthy BMI band matches the classifier cutoffs")
    func bandMatchesCutoffs() {
        #expect(HealthStandard.standard.healthyBMIRange == 18.5..<25)
        #expect(HealthStandard.asian.healthyBMIRange == 18.5..<23)
        // The band's endpoints classify exactly as the engine says they do.
        #expect(BMICalculator.category(forBMI: 18.5, standard: .standard) == .healthy)
        #expect(BMICalculator.category(forBMI: 24.99, standard: .standard) == .healthy)
        #expect(BMICalculator.category(forBMI: 25, standard: .standard) == .overweight)
        #expect(BMICalculator.category(forBMI: 23, standard: .asian) == .overweight)
    }

    @Test("Range is weight at the band bounds for the height")
    func rangeIsBandTimesHeightSquared() throws {
        let h = 1.8
        let range = try #require(BMICalculator.healthyWeightRangeKilograms(heightMeters: h, standard: .standard))
        #expect(approx(range.lowerBound, 18.5 * h * h))   // 59.94
        #expect(approx(range.upperBound, 25 * h * h))     // 81.0
        // The Asian band tops out lower for the same height.
        let asian = try #require(BMICalculator.healthyWeightRangeKilograms(heightMeters: h, standard: .asian))
        #expect(asian.upperBound < range.upperBound)
    }

    @Test("Endpoints of the kg range land in the healthy band")
    func endpointsClassifyHealthy() throws {
        for h in [1.5, 1.6, 1.7, 1.8, 1.9, 2.0] {
            let range = try #require(BMICalculator.healthyWeightRangeKilograms(heightMeters: h))
            #expect(BMICalculator.category(forBMI: BMICalculator.bmi(weightKilograms: range.lowerBound, heightMeters: h)) == .healthy)
            // Just inside the exclusive upper bound is still healthy.
            #expect(BMICalculator.category(forBMI: BMICalculator.bmi(weightKilograms: range.upperBound - 0.01, heightMeters: h)) == .healthy)
        }
    }

    @Test("Non-physical or non-finite height yields nil")
    func guardsBadHeight() {
        #expect(BMICalculator.healthyWeightRangeKilograms(heightMeters: 0) == nil)
        #expect(BMICalculator.healthyWeightRangeKilograms(heightMeters: -1.7) == nil)
        #expect(BMICalculator.healthyWeightRangeKilograms(heightMeters: .nan) == nil)
        #expect(BMICalculator.healthyWeightRangeKilograms(heightMeters: .infinity) == nil)
    }

    @Test("Metric range formats as whole kilograms, rounded inward")
    func metricFormatting() {
        // h = 1.8: 59.94 … 81.0 kg → lower ceils to 60, upper is an exact
        // boundary so it steps back to 80 (81 would be overweight).
        let range = BMICalculator.healthyWeightRangeKilograms(heightMeters: 1.8)!
        #expect(UnitSystem.metric.weightRangeString(fromKilograms: range) == "60–80 kg")
    }

    @Test("Both shown metric endpoints stay inside the healthy band")
    func formattedEndpointsAreHealthy() throws {
        // Parse "lo–hi kg" back out and confirm each classifies as healthy.
        for cm in stride(from: 150.0, through: 200.0, by: 1.0) {
            let h = cm / 100
            let range = try #require(BMICalculator.healthyWeightRangeKilograms(heightMeters: h))
            let text = try #require(UnitSystem.metric.weightRangeString(fromKilograms: range))
            let nums = text.replacingOccurrences(of: " kg", with: "")
                .split(separator: "–").compactMap { Double($0) }
            #expect(nums.count == 2)
            for kg in nums {
                #expect(BMICalculator.category(forBMI: BMICalculator.bmi(weightKilograms: kg, heightMeters: h)) == .healthy,
                        "\(kg) kg at \(cm) cm should be healthy")
            }
        }
    }

    @Test("Imperial formats as whole pounds; stone as one decimal")
    func imperialAndStoneFormatting() throws {
        let range = try #require(BMICalculator.healthyWeightRangeKilograms(heightMeters: 1.75))
        let lb = try #require(UnitSystem.imperial.weightRangeString(fromKilograms: range))
        #expect(lb.hasSuffix(" lb"))
        #expect(!lb.contains("."))                       // whole pounds
        let st = try #require(UnitSystem.stone.weightRangeString(fromKilograms: range))
        #expect(st.hasSuffix(" st"))
        #expect(st.contains("."))                        // one-decimal stone
    }

    @Test("A sub-step-wide band (non-physical height) yields no range string")
    func degenerateNarrowBandReturnsNil() throws {
        // At ~1 ft in stone/Asian the healthy band is narrower than 0.1 st, so no
        // whole-step weight lands inside it — the readout must hide, not print an
        // out-of-band range. (Guards the CalculatorViewModel/ResultCard row too.)
        let range = try #require(BMICalculator.healthyWeightRangeKilograms(
            heightMeters: BMICalculator.meters(fromFeet: 1, inches: 1), standard: .asian))
        #expect(UnitSystem.stone.weightRangeString(fromKilograms: range) == nil)
    }
}
