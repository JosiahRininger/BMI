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
