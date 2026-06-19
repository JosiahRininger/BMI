//
//  StreakService.swift
//  BMICalculator — Features/Streak
//
//  A SHAME-FREE streak system. Research is explicit that punitive streaks on a
//  weight/health app backfire (churn + 1-star reviews), so this design:
//  - celebrates presence (consecutive-day streak + permanent milestone badges),
//  - never punishes absence (a gap silently resets the current streak to 1 on
//    the next entry; there is no negative/"you failed" state),
//  - persists to the App Group so the widget can read the streak too.
//

import Foundation
import Observation

public struct StreakMilestone: Identifiable, Codable, Hashable, Sendable {
    public let threshold: Int          // entry count at which it's earned
    public let title: String
    public let systemImage: String
    public var id: Int { threshold }

    public static let all: [StreakMilestone] = [
        StreakMilestone(threshold: 7,   title: "One week",  systemImage: "7.circle.fill"),
        StreakMilestone(threshold: 30,  title: "One month", systemImage: "30.circle.fill"),
        StreakMilestone(threshold: 100, title: "Century",   systemImage: "100.circle.fill"),
    ]
}

@Observable
@MainActor
public final class StreakService {

    public private(set) var currentStreak: Int = 0
    public private(set) var longestStreak: Int = 0
    public private(set) var entryCount: Int = 0
    public private(set) var earnedMilestones: [StreakMilestone] = []

    /// Set when a milestone is crossed during `recordEntry`; consumed once by the
    /// UI to drive a one-time celebration.
    private var pendingMilestone: StreakMilestone?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let calendar = Calendar.current

    private enum Key {
        static let current = "streak.current"
        static let longest = "streak.longest"
        static let count = "streak.entryCount"
        static let lastDay = "streak.lastEntryDay"   // timeIntervalSince1970 of start-of-day
        static let milestones = "streak.earnedMilestones"
    }

    public init(appGroupID: String = "group.com.jdr.BMI") {
        self.defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        load()
    }

    /// Record a logged entry (call once per successful calculation).
    public func recordEntry(date: Date = Date()) {
        let day = calendar.startOfDay(for: date)
        let lastDay = (defaults.object(forKey: Key.lastDay) as? Double).map { Date(timeIntervalSince1970: $0) }

        if let last = lastDay {
            if calendar.isDate(day, inSameDayAs: last) {
                // Same day: counts as an entry, streak unchanged.
            } else {
                let diff = calendar.dateComponents([.day], from: last, to: day).day ?? 0
                if diff == 1 {
                    currentStreak += 1
                } else if diff > 1 {
                    currentStreak = 1          // gap — shame-free reset, no penalty state
                }
                // diff <= 0 (out-of-order) ignored
            }
        } else {
            currentStreak = 1
        }

        entryCount += 1
        longestStreak = max(longestStreak, currentStreak)
        defaults.set(day.timeIntervalSince1970, forKey: Key.lastDay)
        updateMilestones()
        save()
    }

    /// Returns and clears any milestone earned in the last `recordEntry`.
    public func milestoneJustEarned() -> StreakMilestone? {
        defer { pendingMilestone = nil }
        return pendingMilestone
    }

    /// The next milestone the person hasn't reached yet (nil when all earned).
    public var nextMilestone: StreakMilestone? {
        StreakMilestone.all.first { entryCount < $0.threshold }
    }

    /// Entries remaining until `nextMilestone`.
    public var entriesToNextMilestone: Int? {
        nextMilestone.map { max(0, $0.threshold - entryCount) }
    }

    // MARK: - Private

    private func updateMilestones() {
        for milestone in StreakMilestone.all
        where entryCount >= milestone.threshold && !earnedMilestones.contains(milestone) {
            earnedMilestones.append(milestone)
            pendingMilestone = milestone
        }
    }

    private func load() {
        currentStreak = defaults.integer(forKey: Key.current)
        longestStreak = defaults.integer(forKey: Key.longest)
        entryCount = defaults.integer(forKey: Key.count)
        if let data = defaults.data(forKey: Key.milestones),
           let decoded = try? JSONDecoder().decode([StreakMilestone].self, from: data) {
            earnedMilestones = decoded
        }
        // A stale current streak (a gap since the last entry) is corrected lazily
        // on the next recordEntry — we intentionally do NOT zero it here, so the
        // UI keeps showing the last achieved streak rather than a punishing "0".
    }

    private func save() {
        defaults.set(currentStreak, forKey: Key.current)
        defaults.set(longestStreak, forKey: Key.longest)
        defaults.set(entryCount, forKey: Key.count)
        if let data = try? JSONEncoder().encode(earnedMilestones) {
            defaults.set(data, forKey: Key.milestones)
        }
    }
}
