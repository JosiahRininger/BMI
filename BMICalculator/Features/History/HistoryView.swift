//
//  HistoryView.swift
//  BMICalculator
//
//  The History tab: a trend chart over a selectable range, summary stats
//  (average / high / low), and a list of saved measurements grouped by day
//  with swipe-to-delete and an empty state.
//
//  Person-first, non-judgmental copy throughout.
//

import SwiftUI
import SwiftData
import Charts

// MARK: - HistoryView

/// Displays saved ``BMIRecord`` history with a trend chart, summary stats,
/// and a grouped, deletable list.
public struct HistoryView: View {

    /// The health standard used to categorize and color history.
    /// Defaults to the universal CDC/WHO cutoffs.
    private let standard: HealthStandard

    /// All records, newest first. SwiftData keeps this live.
    @Query(sort: \BMIRecord.date, order: .reverse)
    private var records: [BMIRecord]

    @Environment(\.modelContext) private var modelContext

    @State private var range: ChartRange = .month
    @State private var showExportSheet = false

    /// Whether the person owns Pro (gates export). Injected by the app shell.
    private let isPro: Bool
    /// Presents the Pro paywall when a non-Pro person taps a Pro feature.
    private let onShowPaywall: () -> Void

    public init(standard: HealthStandard = .standard,
                isPro: Bool = false,
                onShowPaywall: @escaping () -> Void = {}) {
        self.standard = standard
        self.isPro = isPro
        self.onShowPaywall = onShowPaywall
    }

    // MARK: Derived data

    /// Records within the selected range (for chart + stats), newest first.
    private var rangedRecords: [BMIRecord] {
        let start = range.startDate()
        return records.filter { $0.date >= start }
    }

    /// Records grouped by calendar day, each group sorted newest-first, and
    /// the groups themselves ordered newest day first.
    private var groupedByDay: [(day: Date, records: [BMIRecord])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
        return groups
            .map { (day: $0.key, records: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    /// Progress-framed payload for the shareable card. Computed from records so
    /// History needs no extra dependency. The card defaults to streak + trend
    /// shape (no absolute BMI unless the person opts in inside the share sheet).
    private var sharePayload: SharePayload {
        let trend = Array(rangedRecords.prefix(20)).reversed().map(\.bmi) // oldest → newest
        return SharePayload(
            streakDays: consecutiveDayStreak,
            entryCount: records.count,
            recentTrend: Array(trend),
            dateRangeText: range.label
        )
    }

    /// Consecutive-calendar-day streak ending at the most recent entry.
    private var consecutiveDayStreak: Int {
        let calendar = Calendar.current
        let days = Set(records.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let first = days.first else { return 0 }
        // A streak is only "active" if the most recent entry is today or yesterday;
        // otherwise it has lapsed and we must not advertise it on the share card.
        guard calendar.isDateInToday(first) || calendar.isDateInYesterday(first) else { return 0 }
        var streak = 1
        var previous = first
        for day in days.dropFirst() {
            guard let diff = calendar.dateComponents([.day], from: day, to: previous).day, diff == 1 else { break }
            streak += 1
            previous = day
        }
        return streak
    }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            Group {
                if records.isEmpty {
                    EmptyHistoryView()
                } else {
                    content
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if isPro { showExportSheet = true } else { onShowPaywall() }
                    } label: {
                        Label("Export", systemImage: isPro ? "square.and.arrow.up" : "lock.fill")
                    }
                    .disabled(records.isEmpty)
                    .accessibilityLabel(isPro ? "Export history" : "Export history, a Pro feature")
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportSheet(records: records, standard: standard)
            }
        }
    }

    private var content: some View {
        List {
            // Chart + range picker + summary stats.
            Section {
                rangePicker

                TrendChart(records: records, range: range, standard: standard)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))

                SummaryStatsRow(records: rangedRecords)

                // Opt-in, progress-framed share card (organic-growth mechanic).
                ShareProgressButton(payload: sharePayload)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listRowSeparator(.hidden)

            // Grouped measurement rows.
            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.records) { record in
                        HistoryRow(record: record, standard: standard)
                    }
                    .onDelete { offsets in
                        delete(at: offsets, in: group.records)
                    }
                } header: {
                    Text(group.day, format: .dateTime.weekday(.wide).month().day().year())
                        .font(.subheadline.weight(.semibold))
                        .textCase(nil)
                }
            }

            // Screening-tool disclaimer (Guideline-aligned, person-first).
            Section {
                DisclaimerFootnote()
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: Range picker

    private var rangePicker: some View {
        Picker("Time range", selection: $range) {
            ForEach(ChartRange.allCases) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .listRowSeparator(.hidden)
        .accessibilityLabel("Chart time range")
    }

    // MARK: Deletion

    /// Deletes records at the given offsets within a day group.
    private func delete(at offsets: IndexSet, in dayRecords: [BMIRecord]) {
        for index in offsets {
            guard dayRecords.indices.contains(index) else { continue }
            modelContext.delete(dayRecords[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Summary Stats

/// A compact average / high / low summary for the visible range.
private struct SummaryStatsRow: View {
    let records: [BMIRecord]

    private var values: [Double] { records.map(\.bmi) }

    private var average: Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    var body: some View {
        HStack(spacing: 12) {
            StatTile(title: "Average", value: average)
            StatTile(title: "Highest", value: values.max())
            StatTile(title: "Lowest", value: values.min())
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
    }
}

/// A single stat tile, with a Liquid Glass background on iOS 26 and a
/// material fallback on earlier systems.
private struct StatTile: View {
    let title: String
    let value: Double?

    private var displayValue: String {
        guard let value else { return "—" }
        return String(format: "%.1f", value)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(displayValue)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                // Three tiles share a fixed-width row; let the value shrink a
                // little before clipping at large Dynamic Type sizes.
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(tileBackground)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) BMI")
        .accessibilityValue(value == nil ? "No data" : displayValue)
    }

    @ViewBuilder
    private var tileBackground: some View {
        if #available(iOS 26.0, *) {
            // Liquid Glass treatment for the stat tile.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.clear)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        }
    }
}

// MARK: - History Row

/// A single saved measurement row: time, BMI value, and a category chip.
private struct HistoryRow: View {
    let record: BMIRecord
    let standard: HealthStandard

    private var category: BMICategory { record.category(standard: standard) }

    var body: some View {
        HStack(spacing: 12) {
            // Category color dot.
            Circle()
                .fill(BMIBandPalette.color(for: category))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.roundedBMI, format: .number.precision(.fractionLength(1)))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(category.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(record.date, format: .dateTime.hour().minute())
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BMI \(record.roundedBMI), \(category.title)")
        .accessibilityValue(record.date.formatted(date: .abbreviated, time: .shortened))
    }
}

// MARK: - Empty State

/// Shown when no measurements have been saved yet.
private struct EmptyHistoryView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No History Yet", systemImage: "chart.xyaxis.line")
        } description: {
            Text("Your saved BMI measurements will appear here so you can track changes over time.")
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Disclaimer

/// The required screening-tool disclaimer, surfaced near results history.
private struct DisclaimerFootnote: View {
    var body: some View {
        Text("BMI is a screening tool, not a diagnosis. It doesn't measure body fat directly and can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .accessibilityLabel("Disclaimer")
    }
}

// MARK: - Export Sheet (Pro)

/// Generates a CSV and a PDF of the history on appearance and offers them via
/// the system share sheet. Local-first: files are written to a temp directory.
private struct ExportSheet: View {
    let records: [BMIRecord]
    let standard: HealthStandard

    @Environment(\.dismiss) private var dismiss
    @State private var csvURL: URL?
    @State private var pdfURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let csvURL {
                        ShareLink(item: csvURL) {
                            Label("Export as CSV", systemImage: "tablecells")
                        }
                    }
                    if let pdfURL {
                        ShareLink(item: pdfURL) {
                            Label("Export as PDF", systemImage: "doc.richtext")
                        }
                    }
                    if csvURL == nil, pdfURL == nil {
                        HStack { ProgressView(); Text("Preparing export…") }
                    }
                } footer: {
                    Text("Your data stays on your device until you choose where to share it.")
                }
            }
            .navigationTitle("Export history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .task {
            csvURL = HistoryExporter.csvFileURL(records: records, standard: standard)
            pdfURL = HistoryExporter.pdfFileURL(records: records, standard: standard)
        }
    }
}

// MARK: - Previews

#Preview("With history") {
    HistoryView()
        .modelContainer(.previewWithSampleHistory)
}

#Preview("Empty") {
    HistoryView()
        .modelContainer(PersistenceController.inMemory())
}
