//
//  BMIWidgetProvider.swift
//  BMICalculator — BMIWidget extension
//
//  Reads the latest BMI entries from the shared App Group store and feeds
//  them into WidgetKit timelines. The provider only depends on Core (the
//  Foundation-only engine) plus Foundation/WidgetKit so it stays cheap to
//  reload and free of any health <-> ad coupling.
//
//  HEALTH/AD FIREWALL (Guideline 5.1.3): nothing in this file — or anywhere
//  in the widget extension — forwards weight/height/BMI to an ad SDK. The
//  widget reads health data only to render glanceable UI.
//

import Foundation
import WidgetKit

// MARK: - Timeline Entry

/// One rendered moment in the widget's timeline.
///
/// Carries the latest measurement plus up to seven recent values for the
/// trend sparkline. `configuration` allows the user to pick a health standard
/// via the widget's edit sheet (AppIntent configuration).
struct BMIWidgetEntry: TimelineEntry {

    let date: Date

    /// The most recent measurement, or `nil` when the person has no history.
    let latest: BMIWidgetEntryData?

    /// Up to seven recent BMI values, oldest → newest, for the sparkline.
    let trend: [Double]

    /// The selected configuration (health standard).
    let configuration: BMIWidgetConfigurationIntent

    init(
        date: Date,
        latest: BMIWidgetEntryData?,
        trend: [Double],
        configuration: BMIWidgetConfigurationIntent
    ) {
        self.date = date
        self.latest = latest
        self.trend = trend
        self.configuration = configuration
    }

    /// A representative entry used for previews and the gallery.
    static func sample(
        configuration: BMIWidgetConfigurationIntent = BMIWidgetConfigurationIntent()
    ) -> BMIWidgetEntry {
        let now = Date()
        let values: [Double] = [27.4, 26.9, 26.2, 25.5, 24.8, 24.3, 23.9]
        let sample = BMIWidgetEntryData(date: now, bmi: values.last ?? 23.9)
        return BMIWidgetEntry(date: now, latest: sample, trend: values, configuration: configuration)
    }

    /// A redacted/empty entry shown when there is no saved history yet.
    static func empty(
        configuration: BMIWidgetConfigurationIntent = BMIWidgetConfigurationIntent()
    ) -> BMIWidgetEntry {
        BMIWidgetEntry(date: Date(), latest: nil, trend: [], configuration: configuration)
    }
}

// MARK: - Provider

/// Supplies timelines for the BMI widgets.
///
/// Because BMI only changes when a person logs a new measurement (in-app),
/// there is no value in frequent refreshes. We publish a single entry and ask
/// WidgetKit to reload after a day; the app additionally calls
/// `WidgetCenter.shared.reloadAllTimelines()` whenever it writes a new record.
struct BMIWidgetProvider: AppIntentTimelineProvider {

    init() {}

    func placeholder(in context: Context) -> BMIWidgetEntry {
        // Shown while the real snapshot loads — redacted by WidgetKit.
        .sample()
    }

    func snapshot(
        for configuration: BMIWidgetConfigurationIntent,
        in context: Context
    ) -> BMIWidgetEntry {
        // The gallery (`context.isPreview`) gets attractive sample data; the
        // real widget reflects the person's actual history.
        if context.isPreview {
            return .sample(configuration: configuration)
        }
        return makeEntry(for: configuration)
    }

    func timeline(
        for configuration: BMIWidgetConfigurationIntent,
        in context: Context
    ) -> Timeline<BMIWidgetEntry> {
        let entry = makeEntry(for: configuration)
        // Refresh roughly daily as a safety net; the app reloads on new data.
        let next = Calendar.current.date(byAdding: .day, value: 1, to: entry.date) ?? entry.date
        return Timeline(entries: [entry], policy: .after(next))
    }

    // MARK: Entry construction

    /// Builds an entry from the shared store using the chosen configuration.
    private func makeEntry(for configuration: BMIWidgetConfigurationIntent) -> BMIWidgetEntry {
        let stored = BMISharedStore.loadRecentEntries() // newest first

        guard let newest = stored.first else {
            return .empty(configuration: configuration)
        }

        // Use the entry exactly as the app saved it — it carries the BMI-cutoff
        // standard chosen in Settings (written by WidgetSync) — so the widget's
        // category matches History / the CSV export rather than diverging.
        let latest = newest

        // Seven most recent values, oldest → newest, for the sparkline.
        let trend = stored
            .prefix(7)
            .map(\.bmi)
            .reversed()

        return BMIWidgetEntry(
            date: Date(),
            latest: latest,
            trend: Array(trend),
            configuration: configuration
        )
    }
}
