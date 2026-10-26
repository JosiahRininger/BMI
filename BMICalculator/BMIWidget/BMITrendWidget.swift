//
//  BMITrendWidget.swift
//  BMICalculator — BMIWidget extension
//
//  The Pro trend widget: the last 90 days of BMI as a line, with the healthy
//  range shaded. A separate widget kind, so the free BMI widget people already
//  placed never changes.
//
//  Locked state (Guideline 4.4): extensions may not sell anything, so without
//  Pro the widget shows only a neutral "Open BMI Calculator to set up this
//  widget." line with no price and no button. Tapping it opens the app, where
//  the Pro sheet explains the rest. The gallery preview uses sample data.
//
//  Privacy: a "Show numbers" option (on by default) can be turned off to show
//  only the line, which keeps the number off a Home Screen others can see.
//
//  HEALTH/AD FIREWALL: reads the App Group snapshot only to draw; no ads here.
//

import SwiftUI
import WidgetKit
import AppIntents
import Charts

// MARK: - Configuration

struct BMITrendWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "BMI Trend" }
    static var description: IntentDescription {
        IntentDescription("Your BMI over the last 90 days.")
    }

    @Parameter(title: "Show numbers", default: true)
    var showsNumbers: Bool

    init() {}
}

// MARK: - Entry

struct BMITrendEntry: TimelineEntry {
    let date: Date
    /// Oldest first, within the trend window.
    let points: [BMIWidgetEntryData]
    let isPro: Bool
    let showsNumbers: Bool

    static func sample(showsNumbers: Bool = true) -> BMITrendEntry {
        let now = Date()
        // A gentle, directionless sample within one range, so the gallery shows
        // the feature without implying a goal.
        let values: [Double] = [23.2, 23.4, 23.1, 23.3, 23.5, 23.2, 23.4, 23.3, 23.1, 23.4, 23.3]
        let points = values.enumerated().map { index, value in
            BMIWidgetEntryData(
                date: Calendar.current.date(byAdding: .day, value: (index - values.count + 1) * 8, to: now) ?? now,
                bmi: value
            )
        }
        return BMITrendEntry(date: now, points: points, isPro: true, showsNumbers: showsNumbers)
    }
}

// MARK: - Provider

struct BMITrendProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> BMITrendEntry {
        .sample()
    }

    func snapshot(for configuration: BMITrendWidgetIntent, in context: Context) -> BMITrendEntry {
        // The gallery shows sample data so people can see what Pro adds.
        if context.isPreview { return .sample(showsNumbers: configuration.showsNumbers) }
        return makeEntry(configuration)
    }

    func timeline(for configuration: BMITrendWidgetIntent, in context: Context) -> Timeline<BMITrendEntry> {
        let entry = makeEntry(configuration)
        // The window slides daily; the app also reloads after new data or a
        // purchase.
        let next = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: entry.date))
            ?? entry.date.addingTimeInterval(86_400)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func makeEntry(_ configuration: BMITrendWidgetIntent) -> BMITrendEntry {
        let points = BMISharedStore.trendSnapshot(from: BMISharedStore.loadTrendEntries())
        return BMITrendEntry(
            date: Date(),
            points: points,
            isPro: BMISharedStore.isProUnlocked(),
            showsNumbers: configuration.showsNumbers
        )
    }
}

// MARK: - Views

struct BMITrendWidgetView: View {
    let entry: BMITrendEntry
    @Environment(\.widgetFamily) private var family

    private static let lineColor = Color(red: 0x19 / 255, green: 0xBE / 255, blue: 0xF4 / 255)

    var body: some View {
        content
            .containerBackground(for: .widget) {
                if #available(iOS 26.0, *) {
                    Rectangle().fill(.clear).glassEffect(.regular, in: .rect)
                } else {
                    Rectangle().fill(.regularMaterial)
                }
            }
            .widgetURL(url)
    }

    private var state: BMITrendWidgetState {
        BMITrendWidgetState.make(isPro: entry.isPro, pointCount: entry.points.count)
    }

    private var url: URL {
        switch state {
        case .locked: return BMIWidgetDeepLink.pro
        case .empty: return BMIWidgetDeepLink.newEntry
        case .trend: return BMIWidgetDeepLink.history
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .locked:
            message(symbol: "chart.xyaxis.line", text: "Open BMI Calculator to set up this widget.")
        case .empty:
            message(symbol: "plus.circle", text: "Save a measurement in BMI Calculator to see your trend here.")
        case .trend:
            trend
        }
    }

    private func message(symbol: String, text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(text)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var trend: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("BMI trend")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Last 90 days")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if entry.showsNumbers, let latest = entry.points.last {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(format: "%.1f", latest.rounded))
                        .font(family == .systemLarge ? .largeTitle.weight(.semibold) : .title2.weight(.semibold))
                        .monospacedDigit()
                    if let change = changeText {
                        Text(change)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            chart
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// e.g. "+0.4 since Jul 12". Neutral: no color, no judgment.
    private var changeText: String? {
        guard entry.points.count >= 2, let first = entry.points.first, let last = entry.points.last else { return nil }
        let change = ((last.bmi - first.bmi) * 10).rounded() / 10
        let value = change == 0 ? "0.0" : String(format: "%+.1f", change)
        return "\(value) since \(first.date.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var accessibilityLabel: String {
        guard entry.showsNumbers, let latest = entry.points.last else {
            return "BMI trend for the last 90 days"
        }
        return "BMI trend for the last 90 days. Latest \(String(format: "%.1f", latest.rounded)). \(changeText ?? "")"
    }

    private var chart: some View {
        let standard = entry.points.last?.standard ?? .standard
        let healthy = standard.healthyBMIRange
        let values = entry.points.map(\.bmi)
        let lower = max(0, min((values.min() ?? 18) - 1.5, healthy.lowerBound - 1))
        let upper = max((values.max() ?? 26) + 1.5, healthy.upperBound + 1)
        let firstDate = entry.points.first?.date ?? entry.date
        let lastDate = max(entry.points.last?.date ?? entry.date, firstDate.addingTimeInterval(86_400))
        return Chart {
            RectangleMark(
                xStart: .value("Start", firstDate),
                xEnd: .value("End", lastDate),
                yStart: .value("Healthy low", healthy.lowerBound),
                yEnd: .value("Healthy high", healthy.upperBound)
            )
            .foregroundStyle(BMICategory.healthy.bandColor.opacity(0.14))

            ForEach(entry.points, id: \.self) { point in
                LineMark(x: .value("Date", point.date), y: .value("BMI", point.bmi))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Self.lineColor)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
            if let last = entry.points.last {
                PointMark(x: .value("Date", last.date), y: .value("BMI", last.bmi))
                    .foregroundStyle(Self.lineColor)
                    .symbolSize(30)
            }
        }
        .chartXScale(domain: firstDate...lastDate)
        .chartYScale(domain: lower...upper)
        .chartXAxis(entry.showsNumbers && family == .systemLarge ? .automatic : .hidden)
        .chartYAxis(entry.showsNumbers ? .automatic : .hidden)
    }
}

// MARK: - Widget

struct BMITrendWidget: Widget {
    static let kind = BMISharedStore.trendWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: BMITrendWidgetIntent.self, provider: BMITrendProvider()) { entry in
            BMITrendWidgetView(entry: entry)
        }
        .configurationDisplayName("BMI Trend")
        .description("Your BMI over the last 90 days, with the healthy range shaded. Requires BMI Calculator Pro.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Previews

#Preview("Trend", as: .systemMedium) {
    BMITrendWidget()
} timeline: {
    BMITrendEntry.sample()
    BMITrendEntry.sample(showsNumbers: false)
    BMITrendEntry(date: .now, points: [], isPro: false, showsNumbers: true)
}
