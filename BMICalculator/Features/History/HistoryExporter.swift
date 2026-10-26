//
//  HistoryExporter.swift
//  BMICalculator — Features/History
//
//  Local-first export of saved history:
//   • CSV (free for everyone): the person's own data in every unit, so it's a
//     backup and a way out. Nobody's history is held hostage.
//   • The doctor summary PDF (Pro): "BMI and Weight History", a calm record
//     for an appointment, in the person's own units, with the method, the
//     cutoffs, and a "discuss with your doctor" line on every page.
//
//  Everything is generated on-device into a temporary file. Nothing leaves the
//  device until the person shares it through the system share sheet; nothing
//  is written to iCloud (Guideline 5.1.3). The summary is a record, not a
//  diagnosis: no "medical report" wording.
//

import SwiftUI
import Charts
import UniformTypeIdentifiers

// MARK: - Export row

/// A plain, Sendable snapshot of one saved entry, so exports never hold
/// SwiftData objects across threads.
struct ExportEntry: Sendable, Equatable {
    let date: Date
    let bmi: Double
    let weightKilograms: Double
    let heightMeters: Double

    init(date: Date, bmi: Double, weightKilograms: Double, heightMeters: Double) {
        self.date = date
        self.bmi = bmi
        self.weightKilograms = weightKilograms
        self.heightMeters = heightMeters
    }

    init(_ record: BMIRecord) {
        self.init(date: record.date, bmi: record.bmi,
                  weightKilograms: record.weightKilograms, heightMeters: record.heightMeters)
    }

    func category(_ standard: HealthStandard) -> BMICategory {
        BMICalculator.category(forBMI: bmi, standard: standard)
    }

    var isValid: Bool {
        bmi.isFinite && weightKilograms.isFinite && heightMeters.isFinite
    }
}

// MARK: - Unit formatting

/// Formats weight and height in the person's chosen units for exports.
enum ExportUnits {

    static func weight(_ kilograms: Double, in system: UnitSystem) -> String {
        guard kilograms.isFinite else { return "–" }
        switch system {
        case .metric:
            return String(format: "%.1f kg", kilograms)
        case .imperial:
            return String(format: "%.1f lb", BMICalculator.pounds(fromKilograms: kilograms))
        case .stone:
            let pounds = BMICalculator.pounds(fromKilograms: kilograms)
            var stone = Int(pounds / BMICalculator.poundsPerStone)
            var remainder = ((pounds - Double(stone) * BMICalculator.poundsPerStone) * 10).rounded() / 10
            if remainder >= BMICalculator.poundsPerStone {
                stone += 1
                remainder -= BMICalculator.poundsPerStone
            }
            return String(format: "%d st %.1f lb", stone, remainder)
        }
    }

    static func height(_ meters: Double, in system: UnitSystem) -> String {
        guard meters.isFinite else { return "–" }
        switch system {
        case .metric:
            return String(format: "%.0f cm", meters * 100)
        case .imperial, .stone:
            let totalInches = meters * 100 / 2.54
            var feet = Int(totalInches / Double(BMICalculator.inchesPerFoot))
            var inches = (totalInches - Double(feet * BMICalculator.inchesPerFoot)).rounded()
            if inches >= Double(BMICalculator.inchesPerFoot) {
                feet += 1
                inches -= Double(BMICalculator.inchesPerFoot)
            }
            return String(format: "%d ft %.0f in", feet, inches)
        }
    }

    /// A signed weight change in the chosen units (e.g. "-1.4 kg", "+0.6 lb").
    static func weightChange(_ deltaKilograms: Double, in system: UnitSystem) -> String {
        guard deltaKilograms.isFinite else { return "–" }
        let value: Double
        let unit: String
        switch system {
        case .metric:
            value = deltaKilograms; unit = "kg"
        case .imperial, .stone:
            value = BMICalculator.pounds(fromKilograms: deltaKilograms); unit = "lb"
        }
        let rounded = (value * 10).rounded() / 10
        return rounded == 0 ? "0.0 \(unit)" : String(format: "%+.1f %@", rounded, unit)
    }
}

// MARK: - CSV (free)

enum HistoryCSV {

    static let header = ["Date", "Time", "BMI", "Category", "Weight (kg)", "Weight (lb)",
                         "Height (cm)", "Height (in)", "Cutoffs"]

    /// Builds the CSV text, oldest entry first. Every field is quoted and any
    /// field that a spreadsheet could treat as a formula is neutralized.
    static func make(entries: [ExportEntry], standard: HealthStandard,
                     timeZone: TimeZone = .current) -> String {
        let dateFormatter = posixFormatter("yyyy-MM-dd", timeZone: timeZone)
        let timeFormatter = posixFormatter("HH:mm", timeZone: timeZone)
        let cutoffs = standard == .asian ? "WHO Asian" : "WHO/CDC"

        var lines = [header.map(field).joined(separator: ",")]
        for entry in entries.filter(\.isValid).sorted(by: { $0.date < $1.date }) {
            let row = [
                dateFormatter.string(from: entry.date),
                timeFormatter.string(from: entry.date),
                number(entry.bmi, places: 1),
                entry.category(standard).title,
                number(entry.weightKilograms, places: 1),
                number(BMICalculator.pounds(fromKilograms: entry.weightKilograms), places: 1),
                number(entry.heightMeters * 100, places: 1),
                number(entry.heightMeters * 100 / 2.54, places: 1),
                cutoffs
            ]
            lines.append(row.map(field).joined(separator: ","))
        }
        // CRLF line endings are the CSV norm (RFC 4180) and open cleanly in
        // Numbers, Excel, and Google Sheets.
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// Quotes a field, doubles embedded quotes, and prefixes an apostrophe when
    /// the field starts with a character a spreadsheet would run as a formula
    /// (`=`, `+`, `-`, `@`, tab, carriage return). Numbers we write are never
    /// negative, so no real value is altered.
    static func field(_ raw: String) -> String {
        var value = raw
        if let first = value.first, "=+-@\t\r".contains(first) {
            value = "'" + value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    static func fileName(now: Date = .now) -> String {
        "BMI-History-\(posixFormatter("yyyy-MM-dd", timeZone: .current).string(from: now)).csv"
    }

    private static func number(_ value: Double, places: Int) -> String {
        String(format: "%.\(places)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func posixFormatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}

/// A shareable CSV that's only built when the person actually shares it.
struct CSVExport: Transferable {
    let entries: [ExportEntry]
    let standard: HealthStandard

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { export in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(HistoryCSV.fileName())
            let text = HistoryCSV.make(entries: export.entries, standard: export.standard)
            try Data(text.utf8).write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

// MARK: - Doctor summary model (Pro)

/// The date range presets offered for the summary.
enum SummaryRange: String, CaseIterable, Identifiable {
    case month, quarter, year, all, custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .month:   return "Last 30 days"
        case .quarter: return "Last 90 days"
        case .year:    return "Last year"
        case .all:     return "All"
        case .custom:  return "Custom"
        }
    }

    /// The interval for a preset (custom is supplied by the caller).
    func interval(now: Date, entries: [ExportEntry], custom: DateInterval) -> DateInterval {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        func lastDays(_ days: Int) -> DateInterval {
            let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
            return DateInterval(start: start, end: endOfToday)
        }
        switch self {
        case .month:   return lastDays(30)
        case .quarter: return lastDays(90)
        case .year:    return lastDays(365)
        case .all:
            let first = entries.map(\.date).min() ?? now
            let latest = max(entries.map(\.date).max() ?? now, now)
            return DateInterval(start: calendar.startOfDay(for: first),
                                end: max(endOfToday, latest))
        case .custom:  return custom
        }
    }
}

/// Everything the PDF shows, computed once (pure, unit-tested).
struct DoctorSummary: Equatable {
    let entries: [ExportEntry]          // oldest first, within the range
    let interval: DateInterval
    let unitSystem: UnitSystem
    let standard: HealthStandard
    let generatedAt: Date

    init(allEntries: [ExportEntry], interval: DateInterval, unitSystem: UnitSystem,
         standard: HealthStandard, generatedAt: Date = .now) {
        self.entries = allEntries
            .filter { $0.isValid && interval.contains($0.date) }
            .sorted { $0.date < $1.date }
        self.interval = interval
        self.unitSystem = unitSystem
        self.standard = standard
        self.generatedAt = generatedAt
    }

    var isEmpty: Bool { entries.isEmpty }
    var first: ExportEntry? { entries.first }
    var latest: ExportEntry? { entries.last }

    var averageBMI: Double? {
        guard !entries.isEmpty else { return nil }
        return entries.map(\.bmi).reduce(0, +) / Double(entries.count)
    }
    var lowestBMI: Double? { entries.map(\.bmi).min() }
    var highestBMI: Double? { entries.map(\.bmi).max() }

    /// Latest minus first BMI (one decimal), when there are two or more entries.
    var bmiChange: Double? {
        guard entries.count >= 2, let first, let latest else { return nil }
        return ((latest.bmi - first.bmi) * 10).rounded() / 10
    }

    /// Latest minus first weight in kilograms.
    var weightChangeKilograms: Double? {
        guard entries.count >= 2, let first, let latest else { return nil }
        return latest.weightKilograms - first.weightKilograms
    }

    /// The method note printed on the first page.
    var methodNote: String {
        let cutoffs: String
        switch standard {
        case .standard:
            cutoffs = "Adult categories (WHO/CDC): underweight below 18.5, healthy weight 18.5 to under 25, overweight 25 to under 30, obesity 30 and above (class 1: 30 to under 35, class 2: 35 to under 40, class 3: 40 and above)."
        case .asian:
            cutoffs = "Adult categories (WHO Asian action points): underweight below 18.5, healthy weight 18.5 to under 23, overweight 23 to under 27.5, higher risk 27.5 and above."
        }
        return "BMI = weight (kg) ÷ height (m)². \(cutoffs) Entries were recorded in BMI Calculator. Categories apply to adults only."
    }

    /// A dated file name, e.g. "BMI-and-Weight-History-2026-10-26.pdf".
    var fileName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "BMI-and-Weight-History-\(formatter.string(from: generatedAt)).pdf"
    }

    static let title = "BMI and Weight History"
    static let footer = "BMI is a screening measure, not a diagnosis. Please discuss these results with your doctor or care team."
}

// MARK: - PDF layout

/// Splits the summary's rows into pages so the PDF can print "Page n of N".
struct DoctorSummaryLayout: Equatable {
    /// Rows that fit on the first page (below the summary, chart, and method).
    static let firstPageRows = 14
    /// Rows that fit on each later page.
    static let laterPageRows = 34

    /// Row index ranges per page. Always at least one page.
    static func pages(rowCount: Int) -> [Range<Int>] {
        guard rowCount > firstPageRows else { return [0..<max(rowCount, 0)] }
        var pages = [0..<firstPageRows]
        var start = firstPageRows
        while start < rowCount {
            let end = min(start + laterPageRows, rowCount)
            pages.append(start..<end)
            start = end
        }
        return pages
    }
}

// MARK: - PDF rendering

enum DoctorSummaryPDF {

    /// US Letter at 72 dpi.
    static let pageSize = CGSize(width: 612, height: 792)

    /// Renders the summary to PDF data. Pages are SwiftUI views drawn as
    /// vector content, so text stays sharp and selectable.
    @MainActor
    static func render(_ summary: DoctorSummary) -> Data {
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, [
                kCGPDFContextTitle as String: DoctorSummary.title,
                kCGPDFContextCreator as String: "BMI Calculator"
              ] as CFDictionary) else {
            return Data()
        }

        let pages = DoctorSummaryLayout.pages(rowCount: summary.entries.count)
        for (index, rows) in pages.enumerated() {
            let page = DoctorSummaryPageView(
                summary: summary,
                rows: rows,
                pageNumber: index + 1,
                pageCount: pages.count
            )
            .frame(width: pageSize.width, height: pageSize.height)
            .environment(\.colorScheme, .light)

            let renderer = ImageRenderer(content: page)
            renderer.proposedSize = ProposedViewSize(pageSize)
            context.beginPDFPage(nil)
            renderer.render { _, draw in
                draw(context)
            }
            context.endPDFPage()
        }
        context.closePDF()
        return data as Data
    }

    /// Renders and writes the PDF to a temporary file.
    @MainActor
    static func fileURL(for summary: DoctorSummary) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(summary.fileName)
        do {
            try render(summary).write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - PDF page view

/// One page of the summary. Plain, high-contrast, print-friendly.
private struct DoctorSummaryPageView: View {
    let summary: DoctorSummary
    let rows: Range<Int>
    let pageNumber: Int
    let pageCount: Int

    private let ink = Color(white: 0.1)
    private let muted = Color(white: 0.38)
    private let rule = Color(white: 0.82)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if pageNumber == 1 {
                firstPageHeader
            } else {
                Text("\(DoctorSummary.title), continued")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                    .padding(.bottom, 10)
            }

            if summary.isEmpty {
                Text("No entries in this date range.")
                    .font(.system(size: 11))
                    .foregroundStyle(muted)
                    .padding(.top, 8)
            } else {
                table
            }

            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 48)
        .padding(.top, 44)
        .padding(.bottom, 32)
        .frame(width: DoctorSummaryPDF.pageSize.width, height: DoctorSummaryPDF.pageSize.height, alignment: .topLeading)
        .background(Color.white)
    }

    // MARK: First page

    private var firstPageHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(DoctorSummary.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(ink)
                Text("Entries from \(dateText(summary.interval.start)) to \(dateText(displayEnd)) · Prepared \(dateText(summary.generatedAt))")
                    .font(.system(size: 10))
                    .foregroundStyle(muted)
            }

            if !summary.isEmpty {
                summaryGrid
                SummaryChart(entries: summary.entries, standard: summary.standard)
                    .frame(height: 170)
            }

            Text(summary.methodNote)
                .font(.system(size: 8.5))
                .foregroundStyle(muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)
        }
        .padding(.bottom, 8)
    }

    /// The interval end is exclusive (start of the next day); print the last day.
    private var displayEnd: Date {
        summary.interval.end.addingTimeInterval(-1)
    }

    private var summaryGrid: some View {
        let units = summary.unitSystem
        let items: [(String, String)] = [
            ("Entries", "\(summary.entries.count)"),
            ("Latest BMI", summary.latest.map { String(format: "%.1f", $0.bmi) } ?? "–"),
            ("Latest weight", summary.latest.map { ExportUnits.weight($0.weightKilograms, in: units) } ?? "–"),
            ("Height", summary.latest.map { ExportUnits.height($0.heightMeters, in: units) } ?? "–"),
            ("BMI change", summary.bmiChange.map { $0 == 0 ? "0.0" : String(format: "%+.1f", $0) } ?? "–"),
            ("Weight change", summary.weightChangeKilograms.map { ExportUnits.weightChange($0, in: units) } ?? "–"),
            ("Average BMI", summary.averageBMI.map { String(format: "%.1f", $0) } ?? "–"),
            ("BMI range", rangeText),
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading),
                                   GridItem(.flexible(), alignment: .leading),
                                   GridItem(.flexible(), alignment: .leading),
                                   GridItem(.flexible(), alignment: .leading)],
                         alignment: .leading, spacing: 8) {
            ForEach(items, id: \.0) { item in
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.0)
                        .font(.system(size: 8.5))
                        .foregroundStyle(muted)
                    Text(item.1)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ink)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 6).stroke(rule, lineWidth: 0.75))
    }

    private var rangeText: String {
        guard let low = summary.lowestBMI, let high = summary.highestBMI else { return "–" }
        return String(format: "%.1f to %.1f", low, high)
    }

    // MARK: Table

    private var table: some View {
        VStack(alignment: .leading, spacing: 0) {
            tableRow(["Date", "Time", "Weight", "Height", "BMI", "Category"], header: true)
            Rectangle().fill(rule).frame(height: 0.75)
            ForEach(Array(rows), id: \.self) { index in
                let entry = summary.entries[index]
                tableRow([
                    dateText(entry.date),
                    entry.date.formatted(date: .omitted, time: .shortened),
                    ExportUnits.weight(entry.weightKilograms, in: summary.unitSystem),
                    ExportUnits.height(entry.heightMeters, in: summary.unitSystem),
                    String(format: "%.1f", entry.bmi),
                    entry.category(summary.standard).title
                ], header: false)
            }
        }
    }

    private func tableRow(_ cells: [String], header: Bool) -> some View {
        let widths: [CGFloat] = [92, 60, 92, 70, 44, 158]
        return HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { index in
                Text(cells[index])
                    .font(.system(size: header ? 9 : 9.5, weight: header ? .semibold : .regular))
                    .foregroundStyle(header ? muted : ink)
                    .lineLimit(1)
                    .frame(width: widths[index], alignment: .leading)
            }
        }
        .frame(height: 18)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Rectangle().fill(rule).frame(height: 0.75)
            HStack(alignment: .top) {
                Text(DoctorSummary.footer)
                    .font(.system(size: 8.5))
                    .foregroundStyle(muted)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Text("Page \(pageNumber) of \(pageCount)")
                    .font(.system(size: 8.5))
                    .foregroundStyle(muted)
            }
        }
    }

    private func dateText(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Summary chart

/// A print-friendly BMI line with the healthy range shaded.
struct SummaryChart: View {
    let entries: [ExportEntry]
    let standard: HealthStandard

    private var yDomain: ClosedRange<Double> {
        let values = entries.map(\.bmi)
        let lower = max(0, min((values.min() ?? 18) - 2, 16))
        let upper = max((values.max() ?? 30) + 2, 32)
        return lower...upper
    }

    private var xDomain: ClosedRange<Date> {
        let first = entries.first?.date ?? .now
        let last = entries.last?.date ?? .now
        if first == last {
            let pad: TimeInterval = 86_400
            return first.addingTimeInterval(-pad)...last.addingTimeInterval(pad)
        }
        return first...last
    }

    var body: some View {
        let healthy = standard.healthyBMIRange
        Chart {
            RectangleMark(
                xStart: .value("Start", xDomain.lowerBound),
                xEnd: .value("End", xDomain.upperBound),
                yStart: .value("Healthy low", healthy.lowerBound),
                yEnd: .value("Healthy high", healthy.upperBound)
            )
            .foregroundStyle(Color(red: 0.18, green: 0.69, blue: 0.35).opacity(0.14))

            ForEach(entries.indices, id: \.self) { index in
                LineMark(x: .value("Date", entries[index].date),
                         y: .value("BMI", entries[index].bmi))
                    .foregroundStyle(Color(red: 0.10, green: 0.45, blue: 0.75))
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                PointMark(x: .value("Date", entries[index].date),
                          y: .value("BMI", entries[index].bmi))
                    .foregroundStyle(Color(red: 0.10, green: 0.45, blue: 0.75))
                    .symbolSize(14)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color(white: 0.85))
                AxisValueLabel {
                    if let bmi = value.as(Double.self) {
                        Text(bmi, format: .number.precision(.fractionLength(0)))
                            .font(.system(size: 8))
                            .foregroundStyle(Color(white: 0.35))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.4)).foregroundStyle(Color(white: 0.85))
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 8))
                    .foregroundStyle(Color(white: 0.35))
            }
        }
        .overlay(alignment: .topLeading) {
            Text("BMI over time · shaded band: healthy range")
                .font(.system(size: 8))
                .foregroundStyle(Color(white: 0.35))
                .padding(.leading, 26)
        }
    }
}
