//
//  SpotlightResultProvider.swift
//  BMICalculator
//
//  Bridges the SwiftData `BMIRecord` store to the Intents/Spotlight layer's
//  `BMIResultProviding` contract, so "recent BMI results" resolve in Spotlight,
//  Siri, and Shortcuts. The App installs this via `BMIResultStore.configure(...)`
//  at launch; the Intents module never imports SwiftData.
//
//  HEALTH/AD FIREWALL: read-only mapping of health records to display entities —
//  nothing here touches the ad SDK.
//

import Foundation
import SwiftData

/// A `Sendable` value that reads recent records from the shared `ModelContainer`
/// on a fresh context per query and maps them to `BMIResultEntity`.
struct SpotlightResultProvider: BMIResultProviding {

    let container: ModelContainer

    func recentResults(limit: Int) async -> [BMIResultEntity] {
        let context = ModelContext(container)

        // Resolve to the active profile's records (falls back to all pre-migration).
        let activeID = ProfilePreferences.activeID()
        var descriptor = FetchDescriptor<BMIRecord>(
            predicate: activeID.map { id in #Predicate<BMIRecord> { $0.profileID == id } },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if limit != .max { descriptor.fetchLimit = max(0, limit) }

        guard let records = try? context.fetch(descriptor) else { return [] }

        return records.map { record in
            let category = record.category(standard: .standard)
            // Deterministic, stable id (records carry no UUID). Second-level
            // granularity is fine for Spotlight result resolution.
            let id = "bmi-\(Int(record.date.timeIntervalSince1970))-\(record.roundedBMI)"
            return BMIResultEntity(
                id: id,
                bmi: record.roundedBMI,
                categoryTitle: category.title,
                categoryRange: category.displayRange,
                categoryRaw: category.rawValue,
                date: record.date
            )
        }
    }
}
