//
//  EdgeCaseTests3.swift
//  BMICalculatorTests
//
//  Third batch: metrics-unit conversions, the ideal-weight formula set, and a
//  few more routing / hex / energy boundaries.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import BMICalculator

private func close(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) < tol }

// MARK: - MetricsUnit conversions

@Suite("MetricsUnit conversions")
struct MetricsUnitTests {

    @Test("Length: cm ↔ in via the exact factor")
    func length() {
        #expect(close(MetricsUnit.centimeters(fromDisplay: 34, system: .imperial), 34 * 2.54))
        #expect(close(MetricsUnit.displayLength(fromCentimeters: 86, system: .imperial), 86 / 2.54))
        #expect(MetricsUnit.centimeters(fromDisplay: 90, system: .metric) == 90)
        #expect(MetricsUnit.lengthLabel(.metric) == "cm")
        #expect(MetricsUnit.lengthLabel(.imperial) == "in")
        #expect(MetricsUnit.lengthLabel(.stone) == "in")
    }

    @Test("Weight: kg → display per unit")
    func weight() {
        #expect(close(MetricsUnit.displayWeight(fromKilograms: 70, system: .metric), 70))
        #expect(close(MetricsUnit.displayWeight(fromKilograms: 70, system: .imperial), BMICalculator.pounds(fromKilograms: 70)))
        #expect(close(MetricsUnit.displayWeight(fromKilograms: 70, system: .stone), BMICalculator.pounds(fromKilograms: 70) / 14, 0.01))
    }

    @Test("Weight round-trips display→kg→display")
    func weightRoundTrip() {
        for system in UnitSystem.allCases {
            let display = MetricsUnit.displayWeight(fromKilograms: 80, system: system)
            let kg = MetricsUnit.kilograms(fromDisplay: display, system: system)
            #expect(close(kg, 80, 0.001))
        }
    }

    @Test("Weight string carries the value and unit, with per-unit precision")
    func weightString() {
        let metric = MetricsUnit.weightString(kilograms: 70, system: .metric)
        #expect(metric.contains("70") && metric.contains("kg"))
        let imperial = MetricsUnit.weightString(kilograms: 70, system: .imperial)
        #expect(imperial.contains("lb"))
        // Imperial uses 0 fraction digits.
        #expect(imperial.contains("154"))
    }
}

// MARK: - Ideal weight formula set

@Suite("Ideal weight formula set")
struct IdealWeightFormulaTests {

    @Test("Male at 180 cm: each classic formula matches its hand value")
    func maleValues() {
        let iw = IdealWeightCalculator.idealWeights(heightCentimeters: 180, sex: .male)
        // over = 70.866 - 60 = 10.866 inches above 5 ft
        #expect(close(iw.devine, 74.99, 0.02))    // 50 + 2.3*over
        #expect(close(iw.robinson, 72.65, 0.02))  // 52 + 1.9*over
        #expect(close(iw.hamwi, 77.34, 0.02))     // 48 + 2.7*over
        #expect(close(iw.miller, 71.52, 0.02))    // 56.2 + 1.41*over
    }

    @Test("Female base constants apply at exactly 5 ft")
    func femaleBase() {
        let iw = IdealWeightCalculator.idealWeights(heightCentimeters: 152.4, sex: .female)
        #expect(close(iw.devine, 45.5))
        #expect(close(iw.robinson, 49.0))
        #expect(close(iw.hamwi, 45.5))
        #expect(close(iw.miller, 53.1))
    }

    @Test("Summary stats are internally consistent")
    func summary() {
        let iw = IdealWeightCalculator.idealWeights(heightCentimeters: 175, sex: .female)
        #expect(iw.lowestKilograms == iw.all.min())
        #expect(iw.highestKilograms == iw.all.max())
        #expect(close(iw.averageKilograms, iw.all.reduce(0, +) / 4))
        #expect(iw.lowestKilograms <= iw.averageKilograms)
        #expect(iw.averageKilograms <= iw.highestKilograms)
    }
}

// MARK: - Energy boundaries

@Suite("Energy boundaries")
struct EnergyBoundaryTests {

    @Test("Mifflin-St Jeor at age 0 drops the age term")
    func ageZero() {
        // 10*70 + 6.25*175 - 0 + 5 = 1798.75 (male)
        #expect(close(EnergyCalculator.mifflinStJeorBMR(weightKilograms: 70, heightCentimeters: 175, ageYears: 0, sex: .male), 1798.75))
    }

    @Test("TDEE is monotonic in the activity factor")
    func tdeeMonotonic() {
        let bmr = 1700.0
        let values = ActivityLevel.allCases.map { EnergyCalculator.tdee(bmr: bmr, activity: $0) }
        #expect(values == values.sorted())
        #expect(values.first == bmr * 1.2)
    }
}

// MARK: - Routing & hex extras

@Suite("Routing and hex extras")
struct RoutingHexExtraTests {

    @Test("Triple-slash and host forms both route")
    func tripleSlash() {
        #expect(AppRoute(url: URL(string: "bmicalculator:///history")!) == .history)
        #expect(AppRoute(url: URL(string: "bmicalculator://history")!) == .history)
    }

    @Test("A 3-digit hex is unsupported and falls back to black")
    func threeDigitHex() {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 0
        UIColor(Color(hex: "#FFF")).getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(close(Double(r), 0) && close(Double(g), 0) && close(Double(b), 0))
        #expect(close(Double(a), 1))
    }

    @Test("Hex parsing ignores surrounding whitespace")
    func whitespaceHex() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: "  #FF0000  ")).getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(close(Double(r), 1) && close(Double(g), 0) && close(Double(b), 0))
    }
}
