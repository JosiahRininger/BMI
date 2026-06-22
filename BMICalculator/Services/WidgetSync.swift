//
//  WidgetSync.swift
//  BMICalculator
//
//  Publishes the latest BMI history to the App Group so the widget can paint it,
//  then asks WidgetKit to refresh. Called after every saved calculation.
//
//  HEALTH/AD FIREWALL: writes only to the App Group store the widget reads —
//  nothing here touches the ad SDK.
//

import Foundation
import SwiftData
import WidgetKit

enum WidgetSync {

    /// Snapshots the most recent records into `BMISharedStore` and reloads the
    /// widget timelines. A no-op (graceful) when the App Group isn't provisioned.
    @MainActor
    static func update(from container: ModelContainer) {
        let context = ModelContext(container)

        // Show the active profile's history so the widget tracks whoever the
        // person is currently viewing. Falls back to all records pre-migration.
        let activeID = ProfilePreferences.activeID()
        var descriptor = FetchDescriptor<BMIRecord>(
            predicate: activeID.map { id in #Predicate<BMIRecord> { $0.profileID == id } },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 7
        let records = (try? context.fetch(descriptor)) ?? []

        let standard = HealthStandard.standard.rawValue
        let entries = records.map {
            BMIWidgetEntryData(date: $0.date, bmi: $0.bmi, standardRaw: standard)
        }
        BMISharedStore.save(entries)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
