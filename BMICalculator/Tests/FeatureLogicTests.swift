//
//  FeatureLogicTests.swift
//  BMICalculatorTests
//
//  Coverage for two feature-level units: MetricsInputModel (the metrics screens'
//  unit conversion, mirroring the calculator) and HistoryExporter (the Pro CSV /
//  PDF export — deterministic CSV content + a real PDF file on disk).
//

import Testing
import Foundation
import SwiftUI
@testable import BMICalculator

// MARK: - Metrics circumference defaults

@Suite("Metrics circumference defaults")
@MainActor
struct MetricsDefaultsTests {

    @Test("Default circumferences render to sensible INCH magnitudes in imperial")
    func sensibleInImperial() {
        // Regression: a raw cm literal (86) shown as inches read absurdly ("86 in").
        let waist = MetricsUnit.displayLength(fromCentimeters: MetricsDefaults.waistCentimeters, system: .imperial)
        #expect(waist > 30 && waist < 40)      // ~33.9 in, NOT 86
        let neck = MetricsUnit.displayLength(fromCentimeters: MetricsDefaults.neckCentimeters, system: .imperial)
        #expect(neck > 12 && neck < 18)        // ~15 in
        let hip = MetricsUnit.displayLength(fromCentimeters: MetricsDefaults.hipCentimeters, system: .imperial)
        #expect(hip > 30 && hip < 42)          // ~37.8 in
        let wrist = MetricsUnit.displayLength(fromCentimeters: MetricsDefaults.wristCentimeters, system: .imperial)
        #expect(wrist > 5 && wrist < 9)        // ~6.7 in
    }

    @Test("Defaults are unchanged in metric (already centimetres)")
    func unchangedInMetric() {
        #expect(MetricsUnit.displayLength(fromCentimeters: MetricsDefaults.waistCentimeters, system: .metric) == 86)
        #expect(MetricsUnit.displayLength(fromCentimeters: MetricsDefaults.wristCentimeters, system: .metric) == 17)
    }

    @Test("lengthBinding shows a sensible imperial value and writes back to centimetres")
    func lengthBindingRoundTrip() {
        var cm = MetricsDefaults.waistCentimeters
        let binding = MetricsUnit.lengthBinding(
            centimeters: Binding(get: { cm }, set: { cm = $0 }),
            system: .imperial
        )
        #expect(binding.wrappedValue > 30 && binding.wrappedValue < 40)   // ~33.9 in
        binding.wrappedValue = 34                                         // user types 34 in
        #expect(abs(cm - 86.36) < 0.01)                                   // stored as 34 * 2.54 cm
        #expect(abs(binding.wrappedValue - 34.0) < 0.05)                  // reads back ~34
    }

    @Test("Seeded body-fat defaults give a plausible figure, not the ~53% the bug produced")
    func seededBodyFatPlausible() {
        // Canonical defaults (neck 38, waist 86 cm) at the model's default 170 cm.
        let percent = BodyFatCalculator.usNavyBodyFatPercent(
            sex: .male, heightCentimeters: 170,
            neckCentimeters: MetricsDefaults.neckCentimeters,
            waistCentimeters: MetricsDefaults.waistCentimeters
        )
        #expect(percent != nil)
        #expect((10.0...30.0).contains(percent ?? 0))   // ~18.7%, not ~53%
    }
}

// MARK: - MetricsInputModel

@Suite("MetricsInputModel conversion")
@MainActor
struct MetricsInputModelTests {

    @Test("Metric defaults: 70 kg / 170 cm")
    func defaults() {
        let m = MetricsInputModel(unitSystem: .metric)
        #expect(m.weight == 70)
        #expect(abs(m.weightKilograms - 70) < 0.0001)
        #expect(abs(m.heightCentimetersMetric - 170) < 0.0001)
    }

    @Test("Switching units preserves the represented body within rounding")
    func unitSwitchPreservesBody() {
        let m = MetricsInputModel(unitSystem: .metric)
        m.unitSystem = .imperial
        #expect(abs(m.weightKilograms - 70) < 0.3)   // 0.1-lb rounding
        m.unitSystem = .stone
        #expect(abs(m.weightKilograms - 70) < 0.6)   // 0.1-st rounding
        m.unitSystem = .metric
        #expect(abs(m.weightKilograms - 70) < 0.6)
    }

    @Test("Weight ranges mirror the calculator's per-unit bounds")
    func weightRanges() {
        #expect(MetricsInputModel(unitSystem: .metric).weightRange == 2...400)
        #expect(MetricsInputModel(unitSystem: .imperial).weightRange == 4...880)
        #expect(MetricsInputModel(unitSystem: .stone).weightRange == 0.5...63)
    }
}

// MARK: - HistoryExporter

@Suite("History export")
@MainActor
struct HistoryExporterTests {

    private func sample() -> [BMIRecord] {
        [
            BMIRecord(date: Date(timeIntervalSince1970: 1_700_000_000), bmi: 22.0,
                      weightKilograms: 67.4, heightMeters: 1.75, unitSystemRaw: "metric"),
            BMIRecord(date: Date(timeIntervalSince1970: 1_700_600_000), bmi: 26.5,
                      weightKilograms: 81.2, heightMeters: 1.75, unitSystemRaw: "metric"),
        ]
    }

    @Test("CSV has the documented header and one row per record")
    func csvShape() throws {
        let url = try #require(HistoryExporter.csvFileURL(records: sample(), standard: .standard))
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.first == "Date,BMI,Category,Weight (kg),Height (m)")
        #expect(lines.count == 3)   // header + 2 records
    }

    @Test("CSV cells carry the rounded BMI and the quoted category title")
    func csvContent() throws {
        let url = try #require(HistoryExporter.csvFileURL(records: sample(), standard: .standard))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("22.0"))
        #expect(text.contains("\"Healthy weight\""))   // bmi 22 under .standard
        #expect(text.contains("\"Overweight\""))       // bmi 26.5 under .standard
    }

    @Test("CSV category column honors the chosen standard")
    func csvHonorsStandard() throws {
        // bmi 24 is Healthy under .standard but Overweight under .asian.
        let records = [BMIRecord(date: .now, bmi: 24, weightKilograms: 74, heightMeters: 1.75, unitSystemRaw: "metric")]
        let asian = try #require(HistoryExporter.csvFileURL(records: records, standard: .asian))
        #expect(try String(contentsOf: asian, encoding: .utf8).contains("\"Overweight\""))
    }

    @Test("Empty history still produces a header-only CSV")
    func csvEmpty() throws {
        let url = try #require(HistoryExporter.csvFileURL(records: [], standard: .standard))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text == "Date,BMI,Category,Weight (kg),Height (m)")
    }

    @Test("PDF export writes a real file to disk")
    func pdfFile() throws {
        let url = try #require(HistoryExporter.pdfFileURL(records: sample(), standard: .standard))
        #expect(FileManager.default.fileExists(atPath: url.path))
        let size = (try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        #expect(size > 0)
    }
}
