//
//  RetentionServiceTests.swift
//  BMICalculatorTests
//
//  Coverage for the retention logic: ReviewPrompter (the pure eligibility gates,
//  driven by injected `now` + an isolated UserDefaults suite).
//

import Testing
import Foundation
@testable import BMICalculator

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
