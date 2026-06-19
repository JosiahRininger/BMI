//
//  BMIRecord.swift
//  BMICalculator
//
//  SwiftData persistence model for a single saved BMI measurement.
//
//  NOTE: Unlike the rest of `Core/`, this file imports SwiftData (it defines
//  the app's `@Model`). It is co-located with the engine for discoverability,
//  but it is part of the App target — the pure, Foundation-only calculation
//  engine (`BMICalculator`, `BMICategory`, …) has no dependency on it.
//
//  HEALTH/AD FIREWALL: Records hold weight/height/BMI. These values MUST NEVER
//  be passed to the ad SDK or used for ad targeting (App Store Guideline 5.1.3),
//  and this store MUST NOT be iCloud-synced.
//

import Foundation
import SwiftData

// MARK: - BMIRecord

/// A single persisted BMI measurement for the History feature.
///
/// Stores the inputs (weight in kilograms, height in meters) alongside the
/// computed BMI so historical rows render correctly even if the cutoff logic
/// or display formatting evolves. The unit system the person used at entry
/// time is preserved so values can be shown back in their preferred units.
@Model
public final class BMIRecord {

    /// When the measurement was taken/saved.
    public var date: Date

    /// The computed BMI value (full precision; round only for display).
    public var bmi: Double

    /// The weight used for this measurement, normalized to kilograms.
    public var weightKilograms: Double

    /// The height used for this measurement, normalized to meters.
    public var heightMeters: Double

    /// The `UnitSystem.rawValue` the person used when entering this record.
    ///
    /// Stored as a raw `String` (rather than the enum) so the persisted
    /// schema stays stable and decoupled from enum evolution.
    public var unitSystemRaw: String

    /// Creates a new BMI record.
    /// - Parameters:
    ///   - date: When the measurement was taken/saved.
    ///   - bmi: The full-precision computed BMI.
    ///   - weightKilograms: Weight normalized to kilograms.
    ///   - heightMeters: Height normalized to meters.
    ///   - unitSystemRaw: The `UnitSystem.rawValue` in use at entry time.
    public init(
        date: Date,
        bmi: Double,
        weightKilograms: Double,
        heightMeters: Double,
        unitSystemRaw: String
    ) {
        self.date = date
        self.bmi = bmi
        self.weightKilograms = weightKilograms
        self.heightMeters = heightMeters
        self.unitSystemRaw = unitSystemRaw
    }
}

// MARK: - Convenience

public extension BMIRecord {

    /// The `UnitSystem` this record was entered with, decoded from the raw
    /// string. Falls back to `.metric` if the stored value is unrecognized.
    var unitSystem: UnitSystem {
        UnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    /// The BMI category for this record under a given health standard.
    ///
    /// Computed on demand from `bmi` so historical rows always reflect the
    /// currently selected standard (`.standard` vs `.asian`).
    func category(standard: HealthStandard = .standard) -> BMICategory {
        BMICalculator.category(forBMI: bmi, standard: standard)
    }

    /// BMI rounded to one decimal place, for display.
    var roundedBMI: Double {
        (bmi * 10).rounded() / 10
    }
}
