//
//  UpsellPolicyTests.swift
//  BMICalculatorTests
//
//  When the app may mention Pro: never to owners, never in a session with a
//  rating prompt, quiet for 30 days after "Not now", and History only after a
//  few entries and at most three dismissals a year.
//

import Testing
import Foundation
@testable import BMICalculator

private let now = Date(timeIntervalSince1970: 1_800_000_000)
private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

@Suite("Upsell policy")
struct UpsellPolicyTests {

    // MARK: Result card

    @Test("Result card: shown when there's an offer and it was never dismissed")
    func resultCardDefault() {
        #expect(UpsellPolicy.showsResultCard(hasOffer: true, record: UpsellRecord(), now: now,
                                             reviewPromptedThisSession: false))
    }

    @Test("Result card: never for owners (nothing to offer)")
    func resultCardOwners() {
        #expect(!UpsellPolicy.showsResultCard(hasOffer: false, record: UpsellRecord(), now: now,
                                              reviewPromptedThisSession: false))
    }

    @Test("Result card: quiet for 30 days after a dismissal, then back")
    func resultCardQuietPeriod() {
        var record = UpsellRecord()
        record.resultCardDismissedAt = daysAgo(10)
        #expect(!UpsellPolicy.showsResultCard(hasOffer: true, record: record, now: now, reviewPromptedThisSession: false))
        record.resultCardDismissedAt = daysAgo(29.9)
        #expect(!UpsellPolicy.showsResultCard(hasOffer: true, record: record, now: now, reviewPromptedThisSession: false))
        record.resultCardDismissedAt = daysAgo(30.1)
        #expect(UpsellPolicy.showsResultCard(hasOffer: true, record: record, now: now, reviewPromptedThisSession: false))
    }

    @Test("Result card: hidden in a session where the rating prompt appeared")
    func resultCardReviewSession() {
        #expect(!UpsellPolicy.showsResultCard(hasOffer: true, record: UpsellRecord(), now: now,
                                              reviewPromptedThisSession: true))
    }

    // MARK: History card

    @Test("History card: needs entries on at least 3 different days")
    func historyMinimumEntries() {
        for count in 0..<UpsellPolicy.historyCardMinimumEntryDays {
            #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: count, record: UpsellRecord(),
                                                   now: now, reviewPromptedThisSession: false))
        }
        #expect(UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 3, record: UpsellRecord(),
                                              now: now, reviewPromptedThisSession: false))
    }

    @Test("History card: never for owners or in a rating-prompt session")
    func historyOwnersAndReview() {
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: false, distinctEntryDays: 10, record: UpsellRecord(),
                                               now: now, reviewPromptedThisSession: false))
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 10, record: UpsellRecord(),
                                               now: now, reviewPromptedThisSession: true))
    }

    @Test("History card: quiet for 30 days after Not now")
    func historyQuietPeriod() {
        let record = UpsellPolicy.recordingHistoryDismissal(UpsellRecord(), now: daysAgo(5))
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 10, record: record,
                                               now: now, reviewPromptedThisSession: false))
        let later = UpsellPolicy.recordingHistoryDismissal(UpsellRecord(), now: daysAgo(31))
        #expect(UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 10, record: later,
                                              now: now, reviewPromptedThisSession: false))
    }

    @Test("History card: stops after 3 dismissals within a year, returns when they age out")
    func historyYearlyCap() {
        var record = UpsellRecord()
        record.historyCardDismissals = [daysAgo(300), daysAgo(200), daysAgo(100)]
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 10, record: record,
                                               now: now, reviewPromptedThisSession: false))
        record.historyCardDismissals = [daysAgo(400), daysAgo(200), daysAgo(100)]
        #expect(UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 10, record: record,
                                              now: now, reviewPromptedThisSession: false))
    }

    @Test("Recording a dismissal prunes entries older than a year")
    func recordingPrunes() {
        var record = UpsellRecord()
        record.historyCardDismissals = [daysAgo(500), daysAgo(40)]
        let updated = UpsellPolicy.recordingHistoryDismissal(record, now: now)
        #expect(updated.historyCardDismissals == [daysAgo(40), now])
    }

    @Test("History card: at most once every 30 days and 3 times a year, even if never dismissed")
    func historyImpressionCap() {
        var record = UpsellPolicy.recordingHistoryImpression(UpsellRecord(), now: daysAgo(10))
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 9, record: record,
                                               now: now, reviewPromptedThisSession: false))
        record = UpsellRecord()
        record.historyCardImpressions = [daysAgo(200), daysAgo(120), daysAgo(40)]
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 9, record: record,
                                               now: now, reviewPromptedThisSession: false))
        record.historyCardImpressions = [daysAgo(400), daysAgo(120), daysAgo(40)]
        #expect(UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 9, record: record,
                                              now: now, reviewPromptedThisSession: false))
    }

    @Test("History card: once shown this session it stays, unless dismissed")
    func historyStableWithinSession() {
        let shown = UpsellPolicy.recordingHistoryImpression(UpsellRecord(), now: now)
        #expect(UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 4, record: shown, now: now,
                                              reviewPromptedThisSession: false, shownThisSession: true))
        let dismissed = UpsellPolicy.recordingHistoryDismissal(shown, now: now)
        #expect(!UpsellPolicy.showsHistoryCard(hasOffer: true, distinctEntryDays: 4, record: dismissed, now: now,
                                               reviewPromptedThisSession: false, shownThisSession: true))
    }

    @Test("Recording an impression prunes entries older than a year")
    func impressionPrunes() {
        var record = UpsellRecord()
        record.historyCardImpressions = [daysAgo(500)]
        #expect(UpsellPolicy.recordingHistoryImpression(record, now: now).historyCardImpressions == [now])
    }

    // MARK: Banner link and thank-you

    @Test("The Go ad-free link is shown exactly when a banner is")
    func bannerLink() {
        #expect(UpsellPolicy.showsBannerLink(showsBanner: true))
        #expect(!UpsellPolicy.showsBannerLink(showsBanner: false))
    }

    @Test("Early supporters get the thank-you once")
    func earlySupporterThanks() {
        let early = Entitlements(adsRemoved: true, pro: true, earlySupporter: true)
        var record = UpsellRecord()
        #expect(UpsellPolicy.needsEarlySupporterThanks(entitlements: early, record: record))
        record.earlySupporterThanked = true
        #expect(!UpsellPolicy.needsEarlySupporterThanks(entitlements: early, record: record))
        let proBuyer = Entitlements(adsRemoved: true, pro: true, earlySupporter: false)
        #expect(!UpsellPolicy.needsEarlySupporterThanks(entitlements: proBuyer, record: UpsellRecord()))
        #expect(!UpsellPolicy.needsEarlySupporterThanks(entitlements: .none, record: UpsellRecord()))
    }
}

@Suite("Upsell store")
@MainActor
struct UpsellStoreTests {

    private func defaults() -> UserDefaults {
        let name = "test.upsell.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Dismissals and the thank-you persist across launches")
    func persistence() {
        let suite = defaults()
        let store = UpsellStore(defaults: suite)
        store.dismissResultCard(now: now)
        store.dismissHistoryCard(now: now)
        store.markEarlySupporterThanked()

        let relaunched = UpsellStore(defaults: suite)
        #expect(relaunched.record.resultCardDismissedAt == now)
        #expect(relaunched.record.historyCardDismissals == [now])
        #expect(relaunched.record.earlySupporterThanked)
        #expect(!relaunched.showsResultCard(hasOffer: true, now: now.addingTimeInterval(86_400)))
    }

    @Test("A rating prompt hides upsell cards for the rest of the session only")
    func reviewSessionFlag() {
        let suite = defaults()
        let store = UpsellStore(defaults: suite)
        #expect(store.showsResultCard(hasOffer: true, now: now))
        store.noteReviewPrompted()
        #expect(!store.showsResultCard(hasOffer: true, now: now))
        #expect(!store.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now))
        // A new session (relaunch) starts clean.
        #expect(UpsellStore(defaults: suite).showsResultCard(hasOffer: true, now: now))
    }

    @Test("A History card impression is recorded once per session and persists")
    func impressionOncePerSession() {
        let suite = defaults()
        let store = UpsellStore(defaults: suite)
        #expect(store.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now))
        store.noteHistoryCardShown(now: now)
        store.noteHistoryCardShown(now: now.addingTimeInterval(60))     // same session: not counted again
        #expect(store.record.historyCardImpressions == [now])
        #expect(store.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now))   // stays this session
        let relaunched = UpsellStore(defaults: suite)
        #expect(!relaunched.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now.addingTimeInterval(86_400)))
        #expect(relaunched.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now.addingTimeInterval(31 * 86_400)))
    }

    @Test("A record saved before a field existed still decodes, keeping the thank-you flag")
    func tolerantDecoding() throws {
        let json = #"{"historyCardDismissals":[],"earlySupporterThanked":true}"#
        let record = try JSONDecoder().decode(UpsellRecord.self, from: Data(json.utf8))
        #expect(record.earlySupporterThanked)
        #expect(record.historyCardImpressions.isEmpty)
        #expect(record.resultCardDismissedAt == nil)
    }

    @Test("A History 'session' ends after six hours even if the app stays running")
    func sessionExpires() {
        let store = UpsellStore(defaults: defaults())
        store.noteHistoryCardShown(now: now)
        #expect(store.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now.addingTimeInterval(3_600)))
        #expect(!store.showsHistoryCard(hasOffer: true, distinctEntryDays: 5, now: now.addingTimeInterval(7 * 3_600)))
    }

    @Test("The review adapter flags the session only when a prompt was shown")
    func reviewAdapterFlags() {
        let store = UpsellStore(defaults: defaults())
        let adapter = ReviewRequesterAdapter(ReviewPrompter(), upsellStore: store)
        // No RequestReviewAction is bound in tests, so no prompt is shown.
        #expect(adapter.maybePrompt() == false)
        #expect(store.reviewPromptedThisSession == false)
    }
}
