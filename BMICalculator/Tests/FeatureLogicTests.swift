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
@testable import BMICalculator

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
        #expect(MetricsInputModel(unitSystem: .stone).weightRange == 0.3...63)
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
