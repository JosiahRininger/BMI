//
//  HistoryView.swift
//  BMICalculator
//
//  The History tab: a trend chart over a selectable range (including All),
//  summary stats (average / high / low), the change since the first entry, a
//  list of saved measurements grouped by day with swipe-to-delete, and Export
//  (CSV for everyone, the doctor summary with Pro).
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

    /// All saved records, newest first. SwiftData keeps this live.
    @Query(sort: \BMIRecord.date, order: .reverse) private var records: [BMIRecord]

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreState.self) private var store: StoreState?
    @Environment(UpsellStore.self) private var upsellStore: UpsellStore?
    @Environment(DeepLinkRouter.self) private var router: DeepLinkRouter?

    /// The person's default units, used by the doctor summary.
    @AppStorage(AppStorageKey.unitSystem) private var unitSystemRaw = UnitSystem.metric.rawValue

    @State private var range: ChartRange = .month
    @State private var showsDoctorSummary = false

    public init(standard: HealthStandard = .standard) {
        self.standard = standard
    }

    // MARK: Derived data

    /// Records within the selected range (for chart + stats), newest first.
    /// Drops any non-finite BMI so the average / high / low tiles can't render
    /// "nan" — mirroring the chart's own finite guard in `TrendChart`.
    private var rangedRecords: [BMIRecord] {
        let start = range.startDate()
        return records.filter { $0.date >= start && $0.bmi.isFinite }
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
                if !records.isEmpty {
                    ToolbarItem(placement: .primaryAction) { exportMenu }
                }
            }
            .sheet(isPresented: $showsDoctorSummary) {
                DoctorSummaryView(
                    entries: records.map(ExportEntry.init),
                    unitSystem: UnitSystem(rawValue: unitSystemRaw) ?? .metric,
                    standard: standard
                )
            }
        }
    }

    // MARK: Export

    /// CSV is free for everyone (your data is always yours); the doctor summary
    /// is Pro, and without Pro it opens as a preview.
    private var exportMenu: some View {
        Menu {
            Button {
                showsDoctorSummary = true
            } label: {
                Label(store?.hasPro == true ? "Doctor summary (PDF)" : "Doctor summary (Pro)",
                      systemImage: "doc.text")
            }
            ShareLink(
                item: CSVExport(entries: records.map(ExportEntry.init), standard: standard),
                preview: SharePreview("BMI history (CSV)")
            ) {
                Label("Spreadsheet (CSV)", systemImage: "tablecells")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .accessibilityHint("Share your history as a doctor summary or a spreadsheet")
    }

    /// The History Pro card: only after a few saved entries, quiet for 30 days
    /// after "Not now", and never for Pro owners (`UpsellPolicy`).
    private var showsHistoryCard: Bool {
        guard let store, let upsellStore else { return false }
        return upsellStore.showsHistoryCard(hasOffer: store.hasUpsellOffer, savedEntryCount: records.count)
    }

    private var content: some View {
        List {
            // Chart + range picker + summary stats.
            Section {
                rangePicker

                TrendChart(records: records, range: range, standard: standard)
                    .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 8, trailing: 8))

                SummaryStatsRow(records: rangedRecords)

                if let change = HistoryChange.make(from: records) {
                    SinceFirstEntryRow(change: change)
                }
            }
            .listRowSeparator(.hidden)

            if showsHistoryCard {
                Section {
                    HistoryProCard(
                        isUpgrade: store?.adsRemoved == true,
                        onTakeALook: { router?.presentedSheet = .pro },
                        onNotNow: { upsellStore?.dismissHistoryCard() }
                    )
                }
            }

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
        // Constrain to a readable, centered column so History doesn't stretch
        // edge-to-edge on iPad. No effect on iPhone (already narrower than 640).
        // The list's own gray is hidden and repainted full-width behind the
        // column, so wide windows (iPad, iPhone Duo inner display) show one even
        // background instead of white bands beside a gray column. Same color the
        // inset-grouped list paints, so iPhone is unchanged.
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    // MARK: Range picker

    private var rangePicker: some View {
        Picker("Time range", selection: $range) {
            ForEach(ChartRange.allCases) { range in
                // Segment shows "7D"; VoiceOver speaks the spelled-out form
                // ("Last 7 days") instead of "7 D".
                Text(range.label).tag(range)
                    .accessibilityLabel(range.accessibilityLabel)
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
        // Keep the widgets in step: a deleted entry must not linger on them.
        WidgetSync.update(from: modelContext.container)
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
        guard let value else { return "–" }
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

// MARK: - Since first entry

/// A neutral whole-history readout: when tracking started and how BMI has
/// changed since. No "left to go", no judgment, just the numbers.
private struct SinceFirstEntryRow: View {
    let change: HistoryChange

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Since your first entry")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(change.firstDate.formatted(date: .abbreviated, time: .omitted)) · BMI \(String(format: "%.1f", change.firstBMI)) then, \(String(format: "%.1f", change.latestBMI)) now (\(change.formattedChange))")
                .font(.subheadline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - History Pro card

/// The rare History card that mentions Pro. Dismissible, never blocking.
private struct HistoryProCard: View {
    let isUpgrade: Bool
    let onTakeALook: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.brand)
                    .accessibilityHidden(true)
                Text(isUpgrade ? "Upgrade to Pro" : "Enjoying BMI Calculator?")
                    .font(.subheadline.weight(.semibold))
            }
            Text("Pro adds a doctor summary, a trend widget, and themes. One purchase, no subscription.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button("Take a look", action: onTakeALook)
                    .buttonStyle(.bordered)
                    .tint(Theme.brand)
                Button("Not now", action: onNotNow)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
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
    private let text = "BMI is a screening tool for informational purposes only, not a diagnosis or a substitute for professional medical advice. It doesn't directly measure body fat and can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider."

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            // Keep the "Disclaimer" framing but include the full text — a bare
            // "Disclaimer" label previously silenced the entire message for VoiceOver.
            .accessibilityLabel("Disclaimer. \(text)")
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
