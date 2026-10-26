//
//  BMISharedStore.swift
//  BMICalculator — shared by the App + Widget targets (multi-target membership)
//
//  The App writes the latest entries here after every completed calculation; the
//  widget reads them. We use `UserDefaults(suiteName:)` with a tiny Codable
//  payload rather than sharing the SwiftData store, so the widget never has to
//  boot a `ModelContainer` just to paint a sparkline.
//
//  INTEGRATION: the App target and the widget extension must both declare the
//  App Group `group.com.jdr.BMI` in their entitlements. Foundation-only (uses
//  Core types, which are in-module in both targets — no `import Core`).
//

import Foundation

// MARK: - Shared App Group

/// Namespacing for the data the app and its extensions share.
public enum BMISharedStore {

    /// The App Group identifier shared across the app, widget, and controls.
    public static let appGroupID = "group.com.jdr.BMI"

    /// The key under which the app persists the recent-entries snapshot.
    public static let recentEntriesKey = "widget.recentEntries.v1"

    /// The key for the longer trend snapshot the Pro trend widget draws.
    public static let trendEntriesKey = "widget.trendEntries.v1"

    /// `Bool` the app writes (see `EntitlementCache`) when Pro is unlocked.
    public static let proUnlockedKey = "store.pro.unlocked"

    /// The Pro trend widget's kind, so the app can reload just that widget.
    public static let trendWidgetKind = "BMITrendWidget"

    /// How far back the trend snapshot reaches, and its size cap.
    public static let trendWindowDays = 90
    public static let trendMaxEntries = 120

    /// Shared defaults backed by the App Group, or `nil` if the entitlement is
    /// missing (defensive — readers then fall back to a friendly empty state).
    public static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Loads the most recent entries (newest first) the app has published.
    public static func loadRecentEntries() -> [BMIWidgetEntryData] {
        guard
            let data = defaults?.data(forKey: recentEntriesKey),
            let decoded = try? JSONDecoder().decode([BMIWidgetEntryData].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }

    /// Writes the recent-entries snapshot (called by the App after each calc).
    /// A no-op when the App Group isn't provisioned (unsigned/dev builds).
    public static func save(_ entries: [BMIWidgetEntryData]) {
        guard let defaults, let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: recentEntriesKey)
    }

    /// Loads the trend snapshot, oldest first.
    public static func loadTrendEntries(from defaults: UserDefaults? = defaults) -> [BMIWidgetEntryData] {
        guard
            let data = defaults?.data(forKey: trendEntriesKey),
            let decoded = try? JSONDecoder().decode([BMIWidgetEntryData].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.date < $1.date }
    }

    /// Writes the trend snapshot.
    public static func saveTrendEntries(_ entries: [BMIWidgetEntryData], to defaults: UserDefaults? = defaults) {
        guard let defaults, let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: trendEntriesKey)
    }

    /// Whether Pro is unlocked, as last written by the app.
    public static func isProUnlocked(in defaults: UserDefaults? = defaults) -> Bool {
        defaults?.bool(forKey: proUnlockedKey) ?? false
    }

    /// Picks the trend snapshot: entries within the window, finite, oldest first,
    /// capped to the newest `trendMaxEntries`.
    public static func trendSnapshot(from entries: [BMIWidgetEntryData], now: Date = Date()) -> [BMIWidgetEntryData] {
        let start = Calendar.current.date(byAdding: .day, value: -(trendWindowDays - 1),
                                          to: Calendar.current.startOfDay(for: now)) ?? now
        let inWindow = entries
            .filter { $0.date >= start && $0.bmi.isFinite }
            .sorted { $0.date < $1.date }
        return Array(inWindow.suffix(trendMaxEntries))
    }
}

// MARK: - Trend widget state

/// What the Pro trend widget draws, decided in one pure place (shared so the
/// app's tests cover it). Without Pro it's a neutral "open the app" message.
public enum BMITrendWidgetState: Equatable, Sendable {
    case locked
    case empty
    case trend

    public static func make(isPro: Bool, pointCount: Int) -> BMITrendWidgetState {
        guard isPro else { return .locked }
        return pointCount == 0 ? .empty : .trend
    }
}

// MARK: - Shared DTO

/// A minimal, Codable snapshot of a single saved BMI measurement. Plain value
/// type (Foundation only) so the widget never imports SwiftData.
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
