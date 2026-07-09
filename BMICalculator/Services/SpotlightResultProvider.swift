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

        var descriptor = FetchDescriptor<BMIRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if limit != .max { descriptor.fetchLimit = max(0, limit) }

        guard let records = try? context.fetch(descriptor) else { return [] }

        // Honor the chosen standard so Spotlight/Siri categorize like History.
        let standard = CalculatorViewModel.savedStandard

        return records.map { record in
            let category = record.category(standard: standard)
            // Use the SAME id formula intent donations use, so a result donated
            // via Siri and the same record resolved here reconcile (dedup + the
            // Spotlight tap can find the entity) instead of producing two ids.
            let id = BMIResultEntity.deterministicID(bmi: record.roundedBMI, date: record.date)
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
