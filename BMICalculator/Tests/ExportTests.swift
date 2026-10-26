//
//  ExportTests.swift
//  BMICalculatorTests
//
//  CSV (free) and the doctor summary PDF (Pro): correct units, safe CSV,
//  correct date ranges and stats, pagination, and the "discuss with your
//  doctor" line on every page.
//

import Testing
import Foundation
import PDFKit
@testable import BMICalculator

private let base = Date(timeIntervalSince1970: 1_790_000_000)   // Sep 21, 2026

private func entry(_ dayOffset: Int, bmi: Double, kg: Double = 70, m: Double = 1.75) -> ExportEntry {
    ExportEntry(date: base.addingTimeInterval(Double(dayOffset) * 86_400), bmi: bmi,
                weightKilograms: kg, heightMeters: m)
}

// MARK: - Units

@Suite("Export unit formatting")
struct ExportUnitsTests {

    @Test("Metric weight and height")
    func metric() {
        #expect(ExportUnits.weight(72.44, in: .metric) == "72.4 kg")
        #expect(ExportUnits.height(1.754, in: .metric) == "175 cm")
    }

    @Test("Imperial weight and height")
    func imperial() {
        #expect(ExportUnits.weight(70, in: .imperial) == "154.3 lb")
        #expect(ExportUnits.height(1.75, in: .imperial) == "5 ft 9 in")
    }

    @Test("Stone weight carries pounds, and rounding never shows 14 lb")
    func stone() {
        #expect(ExportUnits.weight(70, in: .stone) == "11 st 0.3 lb")
        // 13.96 lb over 10 st rounds up to the next stone, not "10 st 14.0 lb".
        let kg = BMICalculator.kilograms(fromPounds: 10 * 14 + 13.96)
        #expect(ExportUnits.weight(kg, in: .stone) == "11 st 0.0 lb")
    }

    @Test("Height rounding never shows 12 inches")
    func heightRollover() {
        let meters = (5 * 12 + 11.7) * 2.54 / 100
        #expect(ExportUnits.height(meters, in: .imperial) == "6 ft 0 in")
    }

    @Test("Weight change is signed and in the chosen unit")
    func weightChange() {
        #expect(ExportUnits.weightChange(-1.44, in: .metric) == "-1.4 kg")
        #expect(ExportUnits.weightChange(0.5, in: .imperial) == "+1.1 lb")
        #expect(ExportUnits.weightChange(0.01, in: .metric) == "0.0 kg")
    }

    @Test("Non-finite values show a dash instead of nan")
    func nonFinite() {
        #expect(ExportUnits.weight(.nan, in: .metric) == "–")
        #expect(ExportUnits.height(.infinity, in: .imperial) == "–")
    }
}

// MARK: - CSV

@Suite("CSV export")
struct CSVExportTests {

    private let utc = TimeZone(identifier: "UTC")!

    @Test("Header, one row per valid entry, oldest first, CRLF line endings")
    func shape() {
        let entries = [entry(2, bmi: 23.0), entry(0, bmi: 23.4), entry(1, bmi: .nan)]
        let csv = HistoryCSV.make(entries: entries, standard: .standard, timeZone: utc)
        let lines = csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }
        #expect(lines.count == 3)   // header + 2 valid rows (the NaN row is skipped)
        #expect(lines[0] == "\"Date\",\"Time\",\"BMI\",\"Category\",\"Weight (kg)\",\"Weight (lb)\",\"Height (cm)\",\"Height (in)\",\"Cutoffs\"")
        #expect(lines[1].contains("\"23.4\""))   // oldest first
        #expect(lines[2].contains("\"23.0\""))
        #expect(csv.hasSuffix("\r\n"))
    }

    @Test("Every unit is included, with POSIX decimals")
    func units() {
        let csv = HistoryCSV.make(entries: [entry(0, bmi: 22.9, kg: 70, m: 1.75)], standard: .standard, timeZone: utc)
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row == "\"2026-09-21\",\"14:13\",\"22.9\",\"Healthy weight\",\"70.0\",\"154.3\",\"175.0\",\"68.9\",\"WHO/CDC\"")
    }

    @Test("Categories follow the chosen cutoffs")
    func cutoffs() {
        let csv = HistoryCSV.make(entries: [entry(0, bmi: 24.0)], standard: .asian, timeZone: utc)
        let row = csv.components(separatedBy: "\r\n")[1]
        #expect(row.contains("\"Overweight\""))
        #expect(row.hasSuffix("\"WHO Asian\""))
    }

    @Test("Fields are quoted, quotes doubled, and formula starters neutralized")
    func escaping() {
        #expect(HistoryCSV.field("plain") == "\"plain\"")
        #expect(HistoryCSV.field("say \"hi\"") == "\"say \"\"hi\"\"\"")
        #expect(HistoryCSV.field("=1+1") == "\"'=1+1\"")
        #expect(HistoryCSV.field("+cmd") == "\"'+cmd\"")
        #expect(HistoryCSV.field("-2") == "\"'-2\"")
        #expect(HistoryCSV.field("@SUM(A1)") == "\"'@SUM(A1)\"")
        #expect(HistoryCSV.field("\tx") == "\"'\tx\"")
        #expect(HistoryCSV.field("a,b") == "\"a,b\"")
    }

    @Test("An empty history exports just the header")
    func empty() {
        let csv = HistoryCSV.make(entries: [], standard: .standard, timeZone: utc)
        #expect(csv.components(separatedBy: "\r\n").filter { !$0.isEmpty }.count == 1)
    }

    @Test("The file name is dated")
    func fileName() {
        #expect(HistoryCSV.fileName(now: base).hasPrefix("BMI-History-2026-09-"))
        #expect(HistoryCSV.fileName(now: base).hasSuffix(".csv"))
    }
}

// MARK: - Doctor summary model

@Suite("Doctor summary")
struct DoctorSummaryTests {

    private let entries = [
        entry(0, bmi: 24.6, kg: 75.3),
        entry(10, bmi: 24.2, kg: 74.1),
        entry(20, bmi: 23.9, kg: 73.2),
        entry(40, bmi: 23.5, kg: 72.0),
    ]

    @Test("Only entries inside the chosen dates are included, oldest first")
    func filtering() {
        let interval = DateInterval(start: base.addingTimeInterval(5 * 86_400), end: base.addingTimeInterval(30 * 86_400))
        let summary = DoctorSummary(allEntries: entries.reversed(), interval: interval, unitSystem: .metric, standard: .standard)
        #expect(summary.entries.map(\.bmi) == [24.2, 23.9])
    }

    @Test("Stats: average, range, and changes")
    func stats() {
        let interval = DateInterval(start: base.addingTimeInterval(-86_400), end: base.addingTimeInterval(60 * 86_400))
        let summary = DoctorSummary(allEntries: entries, interval: interval, unitSystem: .metric, standard: .standard)
        #expect(summary.entries.count == 4)
        #expect(abs((summary.averageBMI ?? 0) - 24.05) < 0.0001)
        #expect(summary.lowestBMI == 23.5)
        #expect(summary.highestBMI == 24.6)
        #expect(summary.bmiChange == -1.1)
        #expect(abs((summary.weightChangeKilograms ?? 0) - (-3.3)) < 0.0001)
    }

    @Test("One entry has no change; no entries is empty")
    func edgeCases() {
        let one = DoctorSummary(allEntries: [entries[0]], interval: DateInterval(start: base, duration: 86_400),
                                unitSystem: .metric, standard: .standard)
        #expect(one.bmiChange == nil)
        #expect(one.weightChangeKilograms == nil)
        let none = DoctorSummary(allEntries: [], interval: DateInterval(start: base, duration: 86_400),
                                 unitSystem: .metric, standard: .standard)
        #expect(none.isEmpty)
        #expect(none.averageBMI == nil)
    }

    @Test("The method note states the formula and the selected cutoffs, adults only")
    func methodNote() {
        let interval = DateInterval(start: base, duration: 86_400)
        let standard = DoctorSummary(allEntries: [], interval: interval, unitSystem: .metric, standard: .standard)
        let asian = DoctorSummary(allEntries: [], interval: interval, unitSystem: .metric, standard: .asian)
        #expect(standard.methodNote.contains("weight (kg) ÷ height (m)²"))
        #expect(standard.methodNote.contains("18.5 to under 25"))
        #expect(asian.methodNote.contains("18.5 to under 23"))
        #expect(standard.methodNote.contains("adults only"))
    }

    @Test("Titled as a history, never as a medical report")
    func wording() {
        #expect(DoctorSummary.title == "BMI and Weight History")
        #expect(!DoctorSummary.title.lowercased().contains("report"))
        #expect(DoctorSummary.footer.contains("not a diagnosis"))
        #expect(DoctorSummary.footer.contains("doctor"))
    }

    @Test("Date presets: last 30 days spans today and the 29 days before")
    func presets() {
        let now = base.addingTimeInterval(40 * 86_400 + 3_600)
        let custom = DateInterval(start: base, duration: 86_400)
        let month = SummaryRange.month.interval(now: now, entries: entries, custom: custom)
        let calendar = Calendar.current
        #expect(month.start == calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)))
        #expect(month.contains(now))
        let all = SummaryRange.all.interval(now: now, entries: entries, custom: custom)
        #expect(all.start == calendar.startOfDay(for: entries[0].date))
        #expect(SummaryRange.custom.interval(now: now, entries: entries, custom: custom) == custom)
    }
}

// MARK: - Pagination and PDF

@Suite("Doctor summary PDF")
@MainActor
struct DoctorSummaryPDFTests {

    @Test("Pagination: first page holds 14 rows, later pages 34")
    func pages() {
        #expect(DoctorSummaryLayout.pages(rowCount: 0) == [0..<0])
        #expect(DoctorSummaryLayout.pages(rowCount: 14) == [0..<14])
        #expect(DoctorSummaryLayout.pages(rowCount: 15) == [0..<14, 14..<15])
        #expect(DoctorSummaryLayout.pages(rowCount: 48) == [0..<14, 14..<48])
        #expect(DoctorSummaryLayout.pages(rowCount: 49) == [0..<14, 14..<48, 48..<49])
    }

    private func summary(count: Int, units: UnitSystem = .imperial) -> DoctorSummary {
        let entries = (0..<count).map { entry($0, bmi: 25.0 - Double($0) * 0.05, kg: 80 - Double($0) * 0.1) }
        let interval = DateInterval(start: base.addingTimeInterval(-86_400), end: base.addingTimeInterval(Double(count + 1) * 86_400))
        return DoctorSummary(allEntries: entries, interval: interval, unitSystem: units, standard: .standard,
                             generatedAt: base)
    }

    @Test("Renders a real PDF with the right page count, title, units, and page numbers")
    func renders() throws {
        let data = DoctorSummaryPDF.render(summary(count: 20))
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 2)
        let first = try #require(document.page(at: 0)?.string)
        #expect(first.contains("BMI and Weight History"))
        #expect(first.contains("lb"))            // the person's units, not only kg
        #expect(first.contains("ft"))
        #expect(first.contains("Page 1 of 2"))
        let second = try #require(document.page(at: 1)?.string)
        #expect(second.contains("continued"))
        #expect(second.contains("Page 2 of 2"))
    }

    @Test("Every page carries the screening-measure and talk-to-your-doctor line")
    func footerEveryPage() throws {
        let data = DoctorSummaryPDF.render(summary(count: 60, units: .metric))
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 3)
        for index in 0..<document.pageCount {
            let text = try #require(document.page(at: index)?.string)
            #expect(text.contains("not a diagnosis"), "page \(index + 1)")
            #expect(text.contains("doctor"), "page \(index + 1)")
        }
    }

    @Test("An empty range still renders one calm page")
    func emptyRange() throws {
        let data = DoctorSummaryPDF.render(summary(count: 0))
        let document = try #require(PDFDocument(data: data))
        #expect(document.pageCount == 1)
        #expect(document.page(at: 0)?.string?.contains("No entries in this date range") == true)
    }

    @Test("The PDF is US Letter and the file name is dated")
    func pageSizeAndName() throws {
        let data = DoctorSummaryPDF.render(summary(count: 3))
        let document = try #require(PDFDocument(data: data))
        let box = try #require(document.page(at: 0)?.bounds(for: .mediaBox))
        #expect(box.size == CGSize(width: 612, height: 792))
        #expect(summary(count: 3).fileName == "BMI-and-Weight-History-2026-09-21.pdf")
    }
}
