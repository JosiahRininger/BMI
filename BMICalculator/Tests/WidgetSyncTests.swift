//
//  WidgetSyncTests.swift
//  BMICalculatorTests
//
//  The widget snapshots follow the saved history: new entries appear, deleted
//  entries disappear (from both the free widget and the Pro trend widget), and
//  entries older than the trend window stay out of the trend.
//

import Testing
import Foundation
import SwiftData
@testable import BMICalculator

@Suite("Widget sync", .serialized)
@MainActor
struct WidgetSyncTests {

    private func record(daysAgo: Double, bmi: Double) -> BMIRecord {
        BMIRecord(date: Date().addingTimeInterval(-daysAgo * 86_400), bmi: bmi,
                  weightKilograms: 70, heightMeters: 1.71, unitSystemRaw: "metric")
    }

    @Test("Deleting an entry and syncing removes it from both widget snapshots")
    func deleteSyncs() throws {
        let container = PersistenceController.inMemory()
        let context = container.mainContext
        let recent = record(daysAgo: 1, bmi: 23.8)
        let older = record(daysAgo: 2, bmi: 24.0)
        let outsideWindow = record(daysAgo: 120, bmi: 25.0)
        [recent, older, outsideWindow].forEach(context.insert)
        try context.save()

        WidgetSync.update(from: container)
        #expect(BMISharedStore.loadTrendEntries().map(\.bmi) == [24.0, 23.8])        // 120 days ago is outside the window
        #expect(BMISharedStore.loadRecentEntries().map(\.bmi) == [23.8, 24.0, 25.0])  // newest first

        context.delete(recent)
        try context.save()
        WidgetSync.update(from: container)
        #expect(BMISharedStore.loadTrendEntries().map(\.bmi) == [24.0])
        #expect(BMISharedStore.loadRecentEntries().map(\.bmi) == [24.0, 25.0])
    }

    @Test("An empty history clears both snapshots")
    func emptyHistory() throws {
        let container = PersistenceController.inMemory()
        WidgetSync.update(from: container)
        #expect(BMISharedStore.loadTrendEntries().isEmpty)
        #expect(BMISharedStore.loadRecentEntries().isEmpty)
    }
}
