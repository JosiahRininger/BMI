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
import Core

// MARK: - Shared App Group

/// Namespacing for the data the app and its extensions share.
///
/// INTEGRATION: the App target and this widget extension must both declare the
/// App Group `group.com.jdr.BMI` in their entitlements. The app writes the
/// latest entries here after every completed calculation; the widget reads
/// them. We deliberately use `UserDefaults(suiteName:)` with a tiny Codable
/// payload rather than sharing the SwiftData store, so the widget never has to
/// boot a `ModelContainer` just to paint a sparkline.
public enum BMISharedStore {

    /// The App Group identifier shared across the app, widget, and controls.
    public static let appGroupID = "group.com.jdr.BMI"

    /// The key under which the app persists the recent-entries snapshot.
    public static let recentEntriesKey = "widget.recentEntries.v1"

    /// Shared defaults backed by the App Group, or `nil` if the entitlement is
    /// missing (defensive — the widget then falls back to a friendly empty state).
    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Loads the most recent entries (newest first) the app has published.
    ///
    /// Returns an empty array when there is no data yet or the payload cannot
    /// be decoded, so callers can always render a safe empty/placeholder state.
    public static func loadRecentEntries() -> [BMIWidgetEntryData] {
        guard
            let data = defaults?.data(forKey: recentEntriesKey),
            let decoded = try? JSONDecoder().decode([BMIWidgetEntryData].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
}

// MARK: - Shared DTO

/// A minimal, Codable snapshot of a single saved BMI measurement.
///
/// The App target is responsible for mapping its `BMIRecord` SwiftData models
/// into an array of these and writing them to `BMISharedStore`. Keeping this a
/// plain value type (Foundation only) means the widget never imports SwiftData.
public struct BMIWidgetEntryData: Codable, Hashable, Sendable {

    /// When the measurement was taken.
    public let date: Date

    /// Full-precision BMI value.
    public let bmi: Double

    /// Which cutoff overlay produced the category (standard vs. Asian).
    public let standardRaw: String

    public init(date: Date, bmi: Double, standardRaw: String = HealthStandard.standard.rawValue) {
        self.date = date
        self.bmi = bmi
        self.standardRaw = standardRaw
    }

    /// The health standard, decoded from its raw value (defaults to `.standard`).
    public var standard: HealthStandard {
        HealthStandard(rawValue: standardRaw) ?? .standard
    }

    /// BMI rounded to one decimal place for display.
    public var rounded: Double {
        (bmi * 10).rounded() / 10
    }

    /// The category for this entry, computed via the shared Core engine.
    public var category: BMICategory {
        BMICalculator.category(forBMI: bmi, standard: standard)
    }
}

// MARK: - Timeline Entry

/// One rendered moment in the widget's timeline.
///
/// Carries the latest measurement plus up to seven recent values for the
/// trend sparkline. `configuration` allows the user to pick a health standard
/// via the widget's edit sheet (AppIntent configuration).
public struct BMIWidgetEntry: TimelineEntry {

    public let date: Date

    /// The most recent measurement, or `nil` when the person has no history.
    public let latest: BMIWidgetEntryData?

    /// Up to seven recent BMI values, oldest → newest, for the sparkline.
    public let trend: [Double]

    /// The selected configuration (health standard).
    public let configuration: BMIWidgetConfigurationIntent

    public init(
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
    public static func sample(
        configuration: BMIWidgetConfigurationIntent = BMIWidgetConfigurationIntent()
    ) -> BMIWidgetEntry {
        let now = Date()
        let values: [Double] = [27.4, 26.9, 26.2, 25.5, 24.8, 24.3, 23.9]
        let sample = BMIWidgetEntryData(date: now, bmi: values.last ?? 23.9)
        return BMIWidgetEntry(date: now, latest: sample, trend: values, configuration: configuration)
    }

    /// A redacted/empty entry shown when there is no saved history yet.
    public static func empty(
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
public struct BMIWidgetProvider: AppIntentTimelineProvider {

    public init() {}

    public func placeholder(in context: Context) -> BMIWidgetEntry {
        // Shown while the real snapshot loads — redacted by WidgetKit.
        .sample()
    }

    public func snapshot(
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

    public func timeline(
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

        // Re-stamp the latest entry with the configured standard so the
        // displayed category honours the user's widget choice even if the app
        // saved it under a different standard.
        let latest = BMIWidgetEntryData(
            date: newest.date,
            bmi: newest.bmi,
            standardRaw: configuration.healthStandard.rawValue
        )

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
