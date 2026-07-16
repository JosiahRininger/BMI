//
//  EdgeCaseTests2.swift
//  BMICalculatorTests
//
//  Second batch of edge-case coverage: the unified Spotlight id, saved-preference
//  accessors that the widget/Spotlight/intent now share, extended streak and
//  profile boundaries, and exporter content.
//

import Testing
import Foundation
import SwiftData
@testable import BMICalculator

private func near(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) < tol }

// MARK: - Deterministic Spotlight id

@Suite("Deterministic Spotlight id")
struct DeterministicIDTests {

    private let date = Date(timeIntervalSince1970: 1000)

    @Test("Id uses the integer bmi*10 suffix (matches intent donations)")
    func format() {
        #expect(BMIResultEntity.deterministicID(bmi: 24.1, date: date) == "bmi-1000-241")
        #expect(BMIResultEntity.deterministicID(bmi: 24.0, date: date) == "bmi-1000-240")
        #expect(BMIResultEntity.deterministicID(bmi: 18.5, date: date) == "bmi-1000-185")
        #expect(BMIResultEntity.deterministicID(bmi: 100.0, date: date) == "bmi-1000-1000")
    }

    @Test("Same inputs produce the same id; different BMIs differ")
    func stableAndDistinct() {
        #expect(BMIResultEntity.deterministicID(bmi: 24.1, date: date) == BMIResultEntity.deterministicID(bmi: 24.1, date: date))
        #expect(BMIResultEntity.deterministicID(bmi: 24.1, date: date) != BMIResultEntity.deterministicID(bmi: 24.2, date: date))
    }
}

// MARK: - Saved-preference accessors

@Suite("Saved preference accessors")
struct SavedPreferenceTests {

    @Test("savedStandard decodes the persisted value and falls back to standard")
    func savedStandard() {
        // Isolated suite so parallel tests mutating .standard can't race this.
        let defaults = UserDefaults(suiteName: "test.savedStandard.\(UUID().uuidString)")!
        defaults.set("asian", forKey: "app.healthStandard")
        #expect(CalculatorViewModel.savedStandard(from: defaults) == .asian)
        defaults.set("standard", forKey: "app.healthStandard")
        #expect(CalculatorViewModel.savedStandard(from: defaults) == .standard)
        defaults.removeObject(forKey: "app.healthStandard")
        #expect(CalculatorViewModel.savedStandard(from: defaults) == .standard)   // fallback
    }

    @Test("savedUnitSystem decodes the persisted value and falls back to metric")
    func savedUnit() {
        let defaults = UserDefaults(suiteName: "test.savedUnit.\(UUID().uuidString)")!
        defaults.set("imperial", forKey: "app.unitSystem")
        #expect(CalculatorViewModel.savedUnitSystem(from: defaults) == .imperial)
        defaults.set("stone", forKey: "app.unitSystem")
        #expect(CalculatorViewModel.savedUnitSystem(from: defaults) == .stone)
        defaults.removeObject(forKey: "app.unitSystem")
        #expect(CalculatorViewModel.savedUnitSystem(from: defaults) == .metric)
    }

    @Test("A record categorizes differently under the Asian standard at BMI 24")
    func standardAffectsCategory() {
        let record = BMIRecord(date: .now, bmi: 24, weightKilograms: 74, heightMeters: 1.75, unitSystemRaw: "metric")
        #expect(record.category(standard: .standard) == .healthy)
        #expect(record.category(standard: .asian) == .overweight)
    }
}
