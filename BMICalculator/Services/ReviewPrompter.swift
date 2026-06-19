//
//  ReviewPrompter.swift
//  BMICalculator
//
//  Wrapper around StoreKit's `RequestReviewAction` (the SwiftUI-native successor
//  to `SKStoreReviewController`) that only asks for a review at a *genuinely
//  good* moment: after a successful calculation, once the app has been installed
//  a while and the person has used it enough, and never more than Apple's
//  3-prompts-per-365-days budget.
//
//  Apple ultimately rate-limits prompts itself; these gates are good-citizen
//  heuristics so we don't burn the budget on day one.
//

import Foundation
import SwiftUI
import StoreKit

// MARK: - ReviewPrompter

/// Decides whether to ask for an App Store review and (when appropriate)
/// triggers the system prompt via the injected `RequestReviewAction`.
///
/// State is persisted in `UserDefaults` so counters survive launches.
@MainActor
@Observable
public final class ReviewPrompter {

    // MARK: Tunable gates

    /// Minimum days since first launch before we'll ever prompt.
    public var minimumDaysInstalled: Int = 7
    /// Minimum number of successful calcs before we'll ever prompt.
    public var minimumSuccessfulCalcs: Int = 3
    /// Apple's hard ceiling — prompts per rolling 365 days.
    public var maxPromptsPerYear: Int = 3
    /// Don't ask twice within this many days even if other gates pass.
    public var minimumDaysBetweenPrompts: Int = 30

    // MARK: Persistence keys

    private enum Key {
        static let firstLaunch = "review.firstLaunchDate"
        static let successfulCalcs = "review.successfulCalcCount"
        static let promptDates = "review.promptDates" // [Date] as timeIntervalSince1970
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        seedFirstLaunchIfNeeded()
    }

    // MARK: First launch bookkeeping

    private func seedFirstLaunchIfNeeded() {
        if defaults.object(forKey: Key.firstLaunch) == nil {
            defaults.set(Date.now.timeIntervalSince1970, forKey: Key.firstLaunch)
        }
    }

    private var firstLaunchDate: Date {
        let t = defaults.double(forKey: Key.firstLaunch)
        return t > 0 ? Date(timeIntervalSince1970: t) : .now
    }

    // MARK: Successful-calc counter

    /// Running count of successful calculations.
    public var successfulCalcCount: Int {
        defaults.integer(forKey: Key.successfulCalcs)
    }

    /// Records that a calculation succeeded. Call this every time a result is produced.
    public func recordSuccessfulCalc() {
        defaults.set(successfulCalcCount + 1, forKey: Key.successfulCalcs)
    }

    // MARK: Prompt history

    private var promptDates: [Date] {
        get {
            let raw = defaults.array(forKey: Key.promptDates) as? [Double] ?? []
            return raw.map { Date(timeIntervalSince1970: $0) }
        }
        set {
            defaults.set(newValue.map(\.timeIntervalSince1970), forKey: Key.promptDates)
        }
    }

    /// Prompts recorded within the last rolling 365 days.
    private func promptsInLastYear(now: Date = .now) -> [Date] {
        let cutoff = now.addingTimeInterval(-365 * 24 * 60 * 60)
        return promptDates.filter { $0 >= cutoff }
    }

    // MARK: Eligibility

    /// Pure predicate (testable, no side effects) describing whether all gates pass.
    public func isEligible(now: Date = .now) -> Bool {
        // Gate 1: installed long enough.
        let daysInstalled = Calendar.current.dateComponents([.day], from: firstLaunchDate, to: now).day ?? 0
        guard daysInstalled >= minimumDaysInstalled else { return false }

        // Gate 2: used enough.
        guard successfulCalcCount >= minimumSuccessfulCalcs else { return false }

        // Gate 3: under the yearly budget.
        let recent = promptsInLastYear(now: now)
        guard recent.count < maxPromptsPerYear else { return false }

        // Gate 4: cooldown since the last prompt.
        if let last = recent.max() {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: now).day ?? 0
            guard daysSince >= minimumDaysBetweenPrompts else { return false }
        }

        return true
    }

    // MARK: Trigger

    /// Maybe asks for a review. Call **only after a successful calc**.
    ///
    /// When all gates pass, fires the system prompt via `requestReview` and
    /// records the attempt against the yearly budget.
    ///
    /// - Parameter requestReview: the SwiftUI `RequestReviewAction` from the
    ///   environment (`@Environment(\.requestReview)`).
    /// - Returns: `true` if a prompt was requested.
    @discardableResult
    public func maybePrompt(using requestReview: RequestReviewAction, now: Date = .now) -> Bool {
        guard isEligible(now: now) else { return false }

        // Record before presenting so a rapid double-call can't double-spend.
        var dates = promptDates
        dates.append(now)
        promptDates = dates

        requestReview()
        return true
    }
}
