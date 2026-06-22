//
//  BMIProfile.swift
//  BMICalculator
//
//  SwiftData model for a tracked person (a "profile"), so one household can
//  follow several people — e.g. yourself plus a partner or child. A BMI Pro
//  perk: the free tier keeps a single profile; Pro unlocks more.
//
//  Each saved ``BMIRecord`` carries an optional `profileID` pointing back here.
//  The link is intentionally a loose UUID rather than a SwiftData relationship
//  so the addition is a *lightweight* migration (a new optional column + a new
//  table) that can't lose any existing history.
//
//  HEALTH/AD FIREWALL: a profile is just a name + id; it holds no health value
//  and must never reach the ad SDK. This store is not iCloud-synced.
//

import Foundation
import SwiftData

// MARK: - BMIProfile

/// A named person whose BMI history is tracked separately.
@Model
public final class BMIProfile {

    /// Stable identifier linked from `BMIRecord.profileID`. Unique so a profile
    /// is never silently duplicated.
    @Attribute(.unique) public var id: UUID

    /// Display name (e.g. "Me", "Alex"). Trimmed, non-empty by construction.
    public var name: String

    /// When the profile was created — used as a stable tiebreaker for ordering.
    public var createdAt: Date

    /// Manual ordering in the switcher/manage list (lower comes first).
    public var sortIndex: Int

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        sortIndex: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortIndex = sortIndex
    }
}
