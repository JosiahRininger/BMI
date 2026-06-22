//
//  RetentionServiceTests.swift
//  BMICalculatorTests
//
//  Coverage for the retention logic: StreakService (shame-free consecutive-day
//  streak + milestones, driven by injected dates) and ReviewPrompter (the pure
//  eligibility gates, driven by injected `now` + an isolated UserDefaults suite).
//

import Testing
import Foundation
@testable import BMICalculator

private let base = Date(timeIntervalSince1970: 1_700_000_000)
private func day(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: base)! }

// MARK: - StreakService

@Suite("Streak service")
@MainActor
struct StreakServiceTests {

    private func fresh(_ suite: String) -> StreakService {
        UserDefaults().removePersistentDomain(forName: suite)
        return StreakService(appGroupID: suite)
    }

    @Test("First entry starts a streak of one")
    func firstEntry() {
        let s = fresh("test.streak.first")
        s.recordEntry(date: day(0))
        #expect(s.currentStreak == 1)
        #expect(s.entryCount == 1)
        #expect(s.loggedDayCount == 1)
        #expect(s.longestStreak == 1)
    }

    @Test("Consecutive days extend the streak")
    func consecutiveDays() {
        let s = fresh("test.streak.consecutive")
        s.recordEntry(date: day(0))
        s.recordEntry(date: day(1))
        s.recordEntry(date: day(2))
        #expect(s.currentStreak == 3)
        #expect(s.loggedDayCount == 3)
        #expect(s.longestStreak == 3)
    }

    @Test("A second entry the same day counts the entry but not the day or streak")
    func sameDayTwice() {
        let s = fresh("test.streak.sameday")
        s.recordEntry(date: day(0))
        s.recordEntry(date: day(0))
        #expect(s.entryCount == 2)
        #expect(s.loggedDayCount == 1)
        #expect(s.currentStreak == 1)
    }

    @Test("A gap silently resets the current streak to one but preserves the longest")
    func gapResets() {
        let s = fresh("test.streak.gap")
        s.recordEntry(date: day(0))
        s.recordEntry(date: day(1))   // streak 2
        s.recordEntry(date: day(5))   // gap → reset to 1
        #expect(s.currentStreak == 1)
        #expect(s.longestStreak == 2)
        #expect(s.loggedDayCount == 3)
    }

    @Test("An out-of-order older entry doesn't advance the day count")
    func outOfOrder() {
        let s = fresh("test.streak.order")
        s.recordEntry(date: day(5))
        s.recordEntry(date: day(3))   // older than last → not a new day
        #expect(s.entryCount == 2)
        #expect(s.loggedDayCount == 1)
    }

    @Test("Seven distinct logging days earn the One Week milestone, consumed once")
    func milestone() {
        let s = fresh("test.streak.milestone")
        for n in 0..<7 { s.recordEntry(date: day(n)) }
        #expect(s.loggedDayCount == 7)
        #expect(s.earnedMilestones.contains { $0.threshold == 7 })
        #expect(s.milestoneJustEarned()?.threshold == 7)
        #expect(s.milestoneJustEarned() == nil)   // one-shot signal
    }

    @Test("Same-day repeats can't fast-track a milestone (keyed on distinct days)")
    func milestoneNeedsDistinctDays() {
        let s = fresh("test.streak.nofasttrack")
        for _ in 0..<10 { s.recordEntry(date: day(0)) }   // 10 entries, one day
        #expect(s.entryCount == 10)
        #expect(s.loggedDayCount == 1)
        #expect(s.earnedMilestones.isEmpty)
    }

    @Test("nextMilestone and entriesToNextMilestone track remaining distinct days")
    func nextMilestone() {
        let s = fresh("test.streak.next")
        #expect(s.nextMilestone?.threshold == 7)
        #expect(s.entriesToNextMilestone == 7)
        for n in 0..<3 { s.recordEntry(date: day(n)) }
        #expect(s.entriesToNextMilestone == 4)
    }
}

// MARK: - ReviewPrompter

@Suite("Review prompter eligibility")
@MainActor
struct ReviewPrompterTests {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Builds a prompter with a deterministic install date + prior prompts in an
    /// isolated defaults suite. `firstLaunchDate` is pre-seeded so the install
    /// window is exact; calcs are added through the public API.
    private func makePrompter(suite: String,
                              daysInstalled: Int,
                              calcs: Int,
                              priorPrompts: [Date] = []) -> ReviewPrompter {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set(now.addingTimeInterval(-Double(daysInstalled) * 86_400).timeIntervalSince1970,
                     forKey: "review.firstLaunchDate")
        if !priorPrompts.isEmpty {
            defaults.set(priorPrompts.map(\.timeIntervalSince1970), forKey: "review.promptDates")
        }
        let prompter = ReviewPrompter(defaults: defaults)
        for _ in 0..<calcs { prompter.recordSuccessfulCalc() }
        return prompter
    }

    @Test("Not eligible before the minimum install window")
    func tooSoon() {
        let p = makePrompter(suite: "test.review.soon", daysInstalled: 2, calcs: 5)
        #expect(p.isEligible(now: now) == false)
    }

    @Test("Not eligible without enough successful calcs")
    func tooFewCalcs() {
        let p = makePrompter(suite: "test.review.calcs", daysInstalled: 30, calcs: 2)
        #expect(p.isEligible(now: now) == false)
    }

    @Test("Eligible once installed long enough and used enough")
    func eligible() {
        let p = makePrompter(suite: "test.review.ok", daysInstalled: 30, calcs: 3)
        #expect(p.isEligible(now: now))
    }

    @Test("recordSuccessfulCalc increments the persisted counter")
    func counter() {
        let p = makePrompter(suite: "test.review.counter", daysInstalled: 30, calcs: 0)
        #expect(p.successfulCalcCount == 0)
        p.recordSuccessfulCalc()
        p.recordSuccessfulCalc()
        #expect(p.successfulCalcCount == 2)
    }

    @Test("Cooldown blocks a prompt too soon after the last one")
    func cooldown() {
        let recent = makePrompter(suite: "test.review.cd1", daysInstalled: 60, calcs: 5,
                                  priorPrompts: [now.addingTimeInterval(-5 * 86_400)])
        #expect(recent.isEligible(now: now) == false)

        let elapsed = makePrompter(suite: "test.review.cd2", daysInstalled: 60, calcs: 5,
                                   priorPrompts: [now.addingTimeInterval(-40 * 86_400)])
        #expect(elapsed.isEligible(now: now))
    }

    @Test("The 3-per-year budget caps prompts")
    func yearlyBudget() {
        let prompts3 = [40, 120, 300].map { now.addingTimeInterval(-Double($0) * 86_400) }
        let capped = makePrompter(suite: "test.review.budget1", daysInstalled: 400, calcs: 5, priorPrompts: prompts3)
        #expect(capped.isEligible(now: now) == false)

        let prompts2 = [40, 300].map { now.addingTimeInterval(-Double($0) * 86_400) }
        let underBudget = makePrompter(suite: "test.review.budget2", daysInstalled: 400, calcs: 5, priorPrompts: prompts2)
        #expect(underBudget.isEligible(now: now))
    }
}
