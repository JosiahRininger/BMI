//
//  PersistenceController.swift
//  BMICalculator
//
//  Factory for the app's SwiftData `ModelContainer`.
//
//  HEALTH/AD FIREWALL: This store holds health data (weight/height/BMI).
//  It is intentionally configured WITHOUT CloudKit so BMI history is never
//  iCloud-synced, and its contents must never reach the ad SDK
//  (App Store Guideline 5.1.3).
//

import Foundation
import SwiftData

// MARK: - PersistenceController

/// Builds and vends the SwiftData `ModelContainer` for `BMIRecord`.
///
/// Use ``shared`` for the live app and ``inMemory()`` for previews/tests.
/// Widget sharing is supported via ``shared(appGroupID:)`` — see the
/// integration notes for the required App Group entitlement.
public enum PersistenceController {

    /// The SwiftData schema for the app's persisted models.
    public static let schema = Schema([BMIRecord.self])

    // MARK: Live container

    /// The app-wide, on-disk container.
    ///
    /// Lazily created once. If construction fails (e.g. an unrecoverable
    /// migration error) we fall back to an in-memory container so the app
    /// never crashes on launch — history is non-critical to the core
    /// calculator flow.
    public static let shared: ModelContainer = {
        do {
            return try makeContainer(inMemory: false)
        } catch {
            assertionFailure("Falling back to in-memory store: \(error)")
            // Last-resort container; a failure here is non-recoverable.
            return try! makeContainer(inMemory: true)
        }
    }()

    // MARK: Factories

    /// Creates a container.
    ///
    /// - Parameters:
    ///   - inMemory: When `true`, data lives only for the process lifetime
    ///     (ideal for previews/tests).
    ///   - appGroupID: When provided, the store is placed in the shared App
    ///     Group container so a widget extension can read the same history.
    ///     Pass `nil` to use the app's private container.
    /// - Returns: A configured `ModelContainer`.
    public static func makeContainer(
        inMemory: Bool = false,
        appGroupID: String? = nil
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration

        if let appGroupID {
            // Store inside the shared App Group so the widget can read it.
            // CloudKit is explicitly NOT enabled (health data stays local).
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                groupContainer: .identifier(appGroupID),
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: .none
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// A throwaway, in-memory container for SwiftUI previews and unit tests.
    public static func inMemory() -> ModelContainer {
        // Force-try is acceptable here: an in-memory store has no I/O to fail,
        // and this path is only used by previews/tests.
        try! makeContainer(inMemory: true)
    }

    /// A shared, App-Group-backed container for widget data sharing.
    /// - Parameter appGroupID: The App Group identifier (e.g. `group.com.jdr.BMI`).
    public static func shared(appGroupID: String) throws -> ModelContainer {
        try makeContainer(inMemory: false, appGroupID: appGroupID)
    }
}

// MARK: - Preview Seeding

public extension ModelContainer {

    /// An in-memory container pre-populated with sample history, for previews.
    @MainActor
    static var previewWithSampleHistory: ModelContainer {
        let container = PersistenceController.inMemory()
        let context = container.mainContext

        for record in BMIRecord.sampleHistory {
            context.insert(record)
        }
        try? context.save()
        return container
    }
}

// MARK: - Sample Data

public extension BMIRecord {

    /// A spread of sample records across ~120 days for previews and the
    /// chart's range picker. Values drift gently downward to demonstrate a
    /// realistic trend across category bands.
    static var sampleHistory: [BMIRecord] {
        let calendar = Calendar.current
        let today = Date()
        let height = 1.75 // meters

        // (daysAgo, bmi) pairs trending from overweight toward healthy.
        let points: [(Int, Double)] = [
            (118, 31.2), (110, 30.4), (101, 29.8), (92, 29.1),
            (84, 28.6),  (75, 28.0),  (66, 27.3),  (58, 26.5),
            (49, 25.9),  (40, 25.2),  (31, 24.6),  (22, 24.1),
            (14, 23.7),  (7, 23.4),    (2, 23.1),   (0, 22.9)
        ]

        return points.map { daysAgo, bmi in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            // Back-solve weight from bmi and a fixed height: kg = bmi * h^2.
            let weight = bmi * height * height
            return BMIRecord(
                date: date,
                bmi: bmi,
                weightKilograms: weight,
                heightMeters: height,
                unitSystemRaw: UnitSystem.metric.rawValue
            )
        }
    }
}
