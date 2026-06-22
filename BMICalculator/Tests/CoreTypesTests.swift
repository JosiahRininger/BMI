//
//  CoreTypesTests.swift
//  BMICalculatorTests
//
//  Coverage for the Core value types not exercised by the engine math tests:
//  stone conversions, UnitSystem / BMICategory / HealthStandard metadata,
//  BMIResult helpers, and BMIRecord convenience accessors.
//

import Testing
import Foundation
@testable import BMICalculator

private func near(_ a: Double, _ b: Double, _ tol: Double = 0.0001) -> Bool { abs(a - b) < tol }

// MARK: - Stone conversions

@Suite("Stone conversions")
struct StoneConversionTests {

    @Test("10 stone is 140 lb → 63.503 kg")
    func tenStone() {
        #expect(near(BMICalculator.kilograms(fromStone: 10), 140 * BMICalculator.kilogramsPerPound))
        #expect(near(BMICalculator.kilograms(fromStone: 10), 63.5029318, 0.0001))
    }

    @Test("11 stone 7 lb is 161 lb")
    func stonePlusPounds() {
        #expect(near(BMICalculator.kilograms(fromStone: 11, pounds: 7), 161 * BMICalculator.kilogramsPerPound))
    }

    @Test("kg → stone+pounds splits whole stone and a 0..<14 remainder")
    func kgToStone() {
        let r = BMICalculator.stoneAndPounds(fromKilograms: BMICalculator.kilograms(fromStone: 10, pounds: 7))
        #expect(r.stone == 10)
        #expect(near(r.pounds, 7, 0.001))
    }

    @Test("Zero kilograms is zero stone, zero pounds")
    func zeroKg() {
        let r = BMICalculator.stoneAndPounds(fromKilograms: 0)
        #expect(r.stone == 0)
        #expect(near(r.pounds, 0))
    }

    @Test("stone↔kg round-trips for a spread of weights")
    func roundTrip() {
        for kg in [48.0, 63.5, 70.0, 95.3, 120.0] {
            let st = BMICalculator.stoneAndPounds(fromKilograms: kg)
            let back = BMICalculator.kilograms(fromStone: Double(st.stone), pounds: st.pounds)
            #expect(near(back, kg, 0.0001))
        }
    }

    @Test("Remainder pounds always stay in 0..<14")
    func remainderBounds() {
        for kg in stride(from: 40.0, through: 130.0, by: 3.7) {
            let r = BMICalculator.stoneAndPounds(fromKilograms: kg)
            #expect(r.pounds >= 0)
            #expect(r.pounds < BMICalculator.poundsPerStone)
        }
    }
}

// MARK: - UnitSystem

@Suite("UnitSystem metadata")
struct UnitSystemTests {

    @Test("Display names")
    func displayNames() {
        #expect(UnitSystem.metric.displayName == "Metric")
        #expect(UnitSystem.imperial.displayName == "Imperial")
        #expect(UnitSystem.stone.displayName == "Stone")
    }

    @Test("Weight unit labels")
    func weightLabels() {
        #expect(UnitSystem.metric.weightUnitLabel == "kg")
        #expect(UnitSystem.imperial.weightUnitLabel == "lb")
        #expect(UnitSystem.stone.weightUnitLabel == "st")
    }

    @Test("Height unit labels: only metric uses cm; both imperial systems use ft / in")
    func heightLabels() {
        #expect(UnitSystem.metric.heightUnitLabel == "cm")
        #expect(UnitSystem.imperial.heightUnitLabel == "ft / in")
        #expect(UnitSystem.stone.heightUnitLabel == "ft / in")
    }

    @Test("usesImperialHeight is true for everything except metric")
    func usesImperialHeight() {
        #expect(UnitSystem.metric.usesImperialHeight == false)
        #expect(UnitSystem.imperial.usesImperialHeight)
        #expect(UnitSystem.stone.usesImperialHeight)
    }

    @Test("Three cases, all raw-value round-trippable")
    func cases() {
        #expect(UnitSystem.allCases.count == 3)
        for u in UnitSystem.allCases {
            #expect(UnitSystem(rawValue: u.rawValue) == u)
            #expect(u.id == u.rawValue)
        }
    }
}

// MARK: - BMICategory metadata

@Suite("BMICategory metadata")
struct BMICategoryMetadataTests {

    @Test("Only the healthy band is not elevated risk")
    func elevatedRisk() {
        #expect(BMICategory.healthy.isElevatedRisk == false)
        for c in BMICategory.allCases where c != .healthy {
            #expect(c.isElevatedRisk, "\(c) should be elevated risk")
        }
    }

    @Test("Every category has a non-empty title and display range")
    func displayStrings() {
        for c in BMICategory.allCases {
            #expect(!c.title.isEmpty)
            #expect(!c.displayRange.isEmpty)
            #expect(c.id == c.rawValue)
        }
        #expect(BMICategory.healthy.title == "Healthy weight")
        #expect(BMICategory.healthy.displayRange == "18.5 – < 25")
        #expect(BMICategory.obesityIII.displayRange == "≥ 40")
    }
}

// MARK: - HealthStandard

@Suite("HealthStandard")
struct HealthStandardTests {

    @Test("Raw values are stable and round-trippable")
    func rawValues() {
        #expect(HealthStandard.standard.rawValue == "standard")
        #expect(HealthStandard.asian.rawValue == "asian")
        for s in HealthStandard.allCases {
            #expect(HealthStandard(rawValue: s.rawValue) == s)
        }
    }
}

// MARK: - BMIResult helpers

@Suite("BMIResult helpers")
struct BMIResultHelperTests {

    @Test("roundedToOneDecimal rounds half away from zero, including negatives")
    func rounding() {
        #expect(BMIResult.roundedToOneDecimal(2.05) == 2.1)
        #expect(BMIResult.roundedToOneDecimal(31.65) == 31.7)
        #expect(BMIResult.roundedToOneDecimal(-22.857) == -22.9)
    }

    @Test("rounded defaults to a 1-decimal rounding of value")
    func defaultRounded() {
        let r = BMIResult(value: 22.857, category: .healthy, standard: .standard)
        #expect(r.rounded == 22.9)
    }

    @Test("An explicit rounded value overrides the default")
    func explicitRounded() {
        let r = BMIResult(value: 22.857, category: .healthy, standard: .standard, rounded: 23.0)
        #expect(r.rounded == 23.0)
    }

    @Test("displayString always shows exactly one decimal place")
    func displayString() {
        #expect(BMIResult(value: 30, category: .obesityI, standard: .standard).displayString == "30.0")
        #expect(BMIResult(value: 18.5, category: .healthy, standard: .standard).displayString == "18.5")
    }
}

// MARK: - BMIRecord convenience

@Suite("BMIRecord convenience")
struct BMIRecordConvenienceTests {

    private func record(bmi: Double, unit: String = "metric") -> BMIRecord {
        BMIRecord(date: .now, bmi: bmi, weightKilograms: 70, heightMeters: 1.75, unitSystemRaw: unit)
    }

    @Test("unitSystem decodes the stored raw value; bad values fall back to metric")
    func unitSystemDecode() {
        #expect(record(bmi: 22, unit: "imperial").unitSystem == .imperial)
        #expect(record(bmi: 22, unit: "stone").unitSystem == .stone)
        #expect(record(bmi: 22, unit: "garbage").unitSystem == .metric)
    }

    @Test("category respects the chosen standard")
    func category() {
        #expect(record(bmi: 22).category(standard: .standard) == .healthy)
        // 24 is healthy under standard but overweight under the Asian action points.
        #expect(record(bmi: 24).category(standard: .standard) == .healthy)
        #expect(record(bmi: 24).category(standard: .asian) == .overweight)
    }

    @Test("roundedBMI rounds to one decimal")
    func roundedBMI() {
        #expect(record(bmi: 22.857).roundedBMI == 22.9)
    }
}
