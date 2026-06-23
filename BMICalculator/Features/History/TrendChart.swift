//
//  TrendChart.swift
//  BMICalculator
//
//  A Swift Charts line chart of BMI over time, with color-coded category
//  bands behind the line and color-coded data points. Supports a selectable
//  time range (7 / 30 / 90 / 365 days).
//

import SwiftUI
import Charts

// MARK: - ChartRange

/// The selectable look-back window for the trend chart.
public enum ChartRange: Int, CaseIterable, Identifiable, Sendable {
    case week = 7
    case month = 30
    case quarter = 90
    case year = 365

    public var id: Int { rawValue }

    /// Short label for the range picker.
    public var label: String {
        switch self {
        case .week:    return "7D"
        case .month:   return "30D"
        case .quarter: return "90D"
        case .year:    return "1Y"
        }
    }

    /// Accessible, spelled-out description.
    public var accessibilityLabel: String {
        switch self {
        case .week:    return "Last 7 days"
        case .month:   return "Last 30 days"
        case .quarter: return "Last 90 days"
        case .year:    return "Last year"
        }
    }

    /// The earliest date included by this range, relative to `now`. Anchored to
    /// the start of the day `rawValue - 1` days ago so e.g. "7D" spans exactly 7
    /// calendar days (today + 6 prior), rather than a 7×24h window off the current
    /// instant that bleeds into an 8th day.
    public func startDate(relativeTo now: Date = Date()) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: -(rawValue - 1), to: calendar.startOfDay(for: now)) ?? now
    }

    /// A reasonable axis stride (in days) for tick marks in this range.
    var axisStrideDays: Int {
        switch self {
        case .week:    return 1
        case .month:   return 7
        case .quarter: return 14
        case .year:    return 60
        }
    }
}

// MARK: - Category Band Colors

/// Chart-local color mapping for BMI categories.
///
/// Defined here (rather than depending on a DesignSystem symbol) so the chart
/// is self-contained. Colors follow the brand spec: underweight blue,
/// healthy green, overweight yellow/orange, obesity escalating orange→red.
/// All colors adapt to light/dark via system semantic blends.
enum BMIBandPalette {

    /// The brand accent blue (#19BEF4) used for the underweight band/line.
    static let brandBlue = Color(red: 0x19 / 255, green: 0xBE / 255, blue: 0xF4 / 255)

    /// Solid representative color for a category (used for points and the
    /// history-row dot). Routes through the design system's appearance-aware
    /// band colors so each category reads on BOTH light and dark surfaces —
    /// raw system colors (e.g. `.yellow` for overweight) wash out on the
    /// near-white light-mode chart.
    static func color(for category: BMICategory) -> Color {
        category.bandColor
    }

    /// Translucent fill used for the background band behind the line. Uses the
    /// design system's per-mode-tuned soft tint (0.16 light / 0.26 dark) rather
    /// than a flat opacity over a raw color, so the bands stay perceptible in
    /// light mode.
    static func bandFill(for category: BMICategory) -> Color {
        category.bandSoftColor
    }

    /// A distinct point-mark shape per category so the trend reads without
    /// relying on color alone (color-blind safety).
    static func symbol(for category: BMICategory) -> BasicChartSymbolShape {
        switch category {
        case .underweight:  return .circle
        case .healthy:      return .square
        case .overweight:   return .triangle
        case .obesityI:     return .diamond
        case .obesityII:    return .cross
        case .obesityIII:   return .pentagon
        }
    }
}

// MARK: - TrendChart

/// A line chart of BMI over time with colored category bands and points.
///
/// The caller supplies already-fetched records; the view filters to the
/// selected `range` and draws:
/// - Horizontal `RectangleMark` bands tinted per BMI category.
/// - `RuleMark` boundary lines at each category cutoff.
/// - A `LineMark` of BMI with category-colored `PointMark`s.
public struct TrendChart: View {

    /// All available records (any order). Filtered/sorted internally.
    public let records: [BMIRecord]

    /// The active look-back window.
    public let range: ChartRange

    /// The health standard used to color points by category.
    public let standard: HealthStandard

    @Environment(\.colorScheme) private var colorScheme

    public init(
        records: [BMIRecord],
        range: ChartRange,
        standard: HealthStandard = .standard
    ) {
        self.records = records
        self.range = range
        self.standard = standard
    }

    // MARK: Derived data

    /// Records within the selected range, sorted oldest → newest.
    private var visibleRecords: [BMIRecord] {
        let start = range.startDate()
        return records
            // Drop non-finite BMI so the line, points, axis domain, and a11y
            // summary stay consistent and yDomain can never form 0.0...NaN
            // (which would trap the whole History tab).
            .filter { $0.date >= start && $0.bmi.isFinite }
            .sorted { $0.date < $1.date }
    }

    /// The category cutoffs to draw as background bands, for the current
    /// standard. Each tuple is (lowerBound, upperBound, category). The top
    /// band is open-ended and clamped to the visible Y domain.
    private var bands: [(lower: Double, upper: Double, category: BMICategory)] {
        switch standard {
        case .standard:
            return [
                (0,    18.5, .underweight),
                (18.5, 25.0, .healthy),
                (25.0, 30.0, .overweight),
                (30.0, 35.0, .obesityI),
                (35.0, 40.0, .obesityII),
                (40.0, yDomain.upperBound, .obesityIII)
            ]
        case .asian:
            return [
                (0,    18.5, .underweight),
                (18.5, 23.0, .healthy),
                (23.0, 27.5, .overweight),
                (27.5, yDomain.upperBound, .obesityI)
            ]
        }
    }

    /// A Y-axis domain padded around the data so bands and points are visible.
    private var yDomain: ClosedRange<Double> {
        let values = visibleRecords.map(\.bmi)
        let minValue = (values.min() ?? 18.0) - 2
        let maxValue = (values.max() ?? 30.0) + 2
        // Keep at least the healthy/overweight region in view.
        let lower = max(0, min(minValue, 16))
        let upper = max(maxValue, 32)
        // Defensive: never form an out-of-order or non-finite range (would trap).
        let safeLower = lower.isFinite ? lower : 0
        let safeUpper = upper.isFinite ? upper : 32
        return min(safeLower, safeUpper)...max(safeLower, safeUpper)
    }

    /// The X-axis domain spanning the selected range up to now.
    private var xDomain: ClosedRange<Date> {
        let now = Date()
        let start = visibleRecords.first?.date ?? range.startDate(relativeTo: now)
        return min(start, range.startDate(relativeTo: now))...now
    }

    // MARK: Body

    public var body: some View {
        Group {
            if visibleRecords.isEmpty {
                emptyChartPlaceholder
            } else {
                chart
            }
        }
    }

    private var chart: some View {
        Chart {
            // Background category bands.
            ForEach(bands.indices, id: \.self) { index in
                let band = bands[index]
                RectangleMark(
                    xStart: .value("Start", xDomain.lowerBound),
                    xEnd: .value("End", xDomain.upperBound),
                    yStart: .value("Lower", max(band.lower, yDomain.lowerBound)),
                    yEnd: .value("Upper", min(band.upper, yDomain.upperBound))
                )
                .foregroundStyle(BMIBandPalette.bandFill(for: band.category))

                // Cutoff boundary line at the top of each band (skip the
                // open-ended top band to avoid a stray line off-chart).
                if band.upper < yDomain.upperBound {
                    RuleMark(y: .value("Cutoff", band.upper))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
            }

            // The BMI trend line.
            ForEach(visibleRecords) { record in
                LineMark(
                    x: .value("Date", record.date),
                    y: .value("BMI", record.bmi)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(BMIBandPalette.brandBlue)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            // Color-coded points on top of the line. The symbol shape also varies
            // by category so the trend is distinguishable without relying on color
            // alone (color-blind safety).
            ForEach(visibleRecords) { record in
                let category = record.category(standard: standard)
                PointMark(
                    x: .value("Date", record.date),
                    y: .value("BMI", record.bmi)
                )
                .symbolSize(60)
                .symbol(BMIBandPalette.symbol(for: category))
                .foregroundStyle(BMIBandPalette.color(for: category))
            }
        }
        .chartYScale(domain: yDomain)
        .chartXScale(domain: xDomain)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let bmi = value.as(Double.self) {
                        Text(bmi, format: .number.precision(.fractionLength(0)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: range.axisStrideDays)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                               centered: false)
            }
        }
        .frame(height: 220)
        // Collapse the individual marks into one summarized element so VoiceOver
        // speaks a concise trend instead of reading every point.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BMI trend chart, \(range.accessibilityLabel)")
        .accessibilityValue(accessibilitySummary)
    }

    private var emptyChartPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 32, weight: .regular))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No measurements in this range")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .accessibilityElement(children: .combine)
    }

    /// A spoken summary of the visible trend for VoiceOver. Names the latest
    /// category in words so the colored bands are conveyed without relying on
    /// color (color-blind / non-visual access).
    private var accessibilitySummary: String {
        guard let first = visibleRecords.first, let last = visibleRecords.last else {
            return "No data"
        }
        let firstBMI = first.roundedBMI
        let lastBMI = last.roundedBMI
        let direction: String
        if lastBMI > firstBMI { direction = "increasing" }
        else if lastBMI < firstBMI { direction = "decreasing" }
        else { direction = "steady" }
        let latestCategory = last.category(standard: standard).title
        return "BMI \(direction) from \(firstBMI) to \(lastBMI) over \(visibleRecords.count) measurements. Latest reading \(lastBMI), \(latestCategory)."
    }
}

// MARK: - Previews

#Preview("Trend — 90 days") {
    TrendChartPreviewHarness(range: .quarter)
        .padding()
}

#Preview("Trend — 7 days (sparse)") {
    TrendChartPreviewHarness(range: .week)
        .padding()
}

/// Small harness so previews can pull seeded sample data without a live store.
private struct TrendChartPreviewHarness: View {
    let range: ChartRange
    var body: some View {
        TrendChart(
            records: BMIRecord.sampleHistory,
            range: range,
            standard: .standard
        )
    }
}
