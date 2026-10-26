//
//  WidgetSync.swift
//  BMICalculator
//
//  Publishes the latest BMI history to the App Group so the widgets can paint
//  it, then asks WidgetKit to refresh. Called after every saved calculation,
//  after History deletes, and when the cutoff standard changes.
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

        var descriptor = FetchDescriptor<BMIRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 7
        let records = (try? context.fetch(descriptor)) ?? []

        // Honor the person's chosen BMI-cutoff standard (Standard vs Asian) so
        // the widget categorizes the same way History/CSV do.
        let standard = CalculatorViewModel.savedStandard.rawValue
        let entries = records.map {
            BMIWidgetEntryData(date: $0.date, bmi: $0.bmi, standardRaw: standard)
        }
        BMISharedStore.save(entries)

        // The longer window for the Pro trend widget (written for everyone, so
        // it's ready the moment Pro unlocks).
        let start = Calendar.current.date(byAdding: .day, value: -(BMISharedStore.trendWindowDays - 1),
                                          to: Calendar.current.startOfDay(for: .now)) ?? .now
        let trendDescriptor = FetchDescriptor<BMIRecord>(
            predicate: #Predicate { $0.date >= start },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let trendRecords = (try? context.fetch(trendDescriptor)) ?? []
        let trend = BMISharedStore.trendSnapshot(from: trendRecords.map {
            BMIWidgetEntryData(date: $0.date, bmi: $0.bmi, standardRaw: standard)
        })
        BMISharedStore.saveTrendEntries(trend)

        WidgetCenter.shared.reloadAllTimelines()
    }
}
