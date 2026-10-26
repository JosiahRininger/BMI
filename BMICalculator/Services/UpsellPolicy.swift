//
//  UpsellPolicy.swift
//  BMICalculator
//
//  When the app may mention Pro. Every placement is soft, dismissible, and
//  never blocking. The rules (pure, unit-tested):
//
//   • Pro owners and early supporters never see an upsell.
//   • Nothing is shown at launch, and nothing depends on the BMI category.
//   • The result-card row can be dismissed; it then stays quiet for 30 days.
//   • The History card appears only after a few saved entries, stays quiet for
//     30 days after "Not now", and stops after 3 dismissals in a year.
//   • No upsell card appears in a session where the app asked for a rating.
//
//  The "Go ad-free" link by the banner and the Settings row are always
//  available to customers who still see ads or can still upgrade.
//

import Foundation
import Observation

// MARK: - Persisted state

/// The upsell bookkeeping saved between launches.
struct UpsellRecord: Codable, Equatable, Sendable {
    /// When the result-card row was last dismissed.
    var resultCardDismissedAt: Date?
    /// Every History card dismissal (pruned to the last year).
    var historyCardDismissals: [Date] = []
    /// Whether the one-time early supporter thank-you has been shown.
    var earlySupporterThanked = false
}

// MARK: - Policy

enum UpsellPolicy {

    /// Quiet period after a dismissal.
    static let quietPeriod: TimeInterval = 30 * 24 * 60 * 60

    /// Saved entries needed before the History card can appear.
    static let historyCardMinimumEntries = 3

    /// Most History card dismissals honored per rolling year before it stops.
    static let historyCardMaxDismissalsPerYear = 3

    private static let year: TimeInterval = 365 * 24 * 60 * 60

    /// Whether the result card may show its Pro row.
    static func showsResultCard(
        hasOffer: Bool,
        record: UpsellRecord,
        now: Date,
        reviewPromptedThisSession: Bool
    ) -> Bool {
        guard hasOffer, !reviewPromptedThisSession else { return false }
        if let dismissed = record.resultCardDismissedAt, now.timeIntervalSince(dismissed) < quietPeriod {
            return false
        }
        return true
    }

    /// Whether History may show its Pro card.
    static func showsHistoryCard(
        hasOffer: Bool,
        savedEntryCount: Int,
        record: UpsellRecord,
        now: Date,
        reviewPromptedThisSession: Bool
    ) -> Bool {
        guard hasOffer, !reviewPromptedThisSession,
              savedEntryCount >= historyCardMinimumEntries else { return false }
        let recent = record.historyCardDismissals.filter { now.timeIntervalSince($0) < year }
        if recent.count >= historyCardMaxDismissalsPerYear { return false }
        if let last = recent.max(), now.timeIntervalSince(last) < quietPeriod { return false }
        return true
    }

    /// Whether the small "Go ad-free" link by the banner shows. It's only there
    /// when a banner is.
    static func showsBannerLink(showsBanner: Bool) -> Bool {
        showsBanner
    }

    /// Whether the one-time early supporter thank-you should appear now.
    static func needsEarlySupporterThanks(entitlements: Entitlements, record: UpsellRecord) -> Bool {
        entitlements.earlySupporter && !record.earlySupporterThanked
    }

    /// Records a History card dismissal, keeping only the last year.
    static func recordingHistoryDismissal(_ record: UpsellRecord, now: Date) -> UpsellRecord {
        var copy = record
        copy.historyCardDismissals = (record.historyCardDismissals + [now])
            .filter { now.timeIntervalSince($0) < year }
        return copy
    }
}

// MARK: - Store

/// Owns the persisted upsell record plus the per-session flag. Injected through
/// the environment; views ask it the policy questions.
@MainActor
@Observable
final class UpsellStore {

    static let defaultsKey = "upsell.record.v1"

    private(set) var record: UpsellRecord

    /// Set when the app presented the App Store rating prompt this session.
    private(set) var reviewPromptedThisSession = false

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode(UpsellRecord.self, from: data) {
            record = decoded
        } else {
            record = UpsellRecord()
        }
    }

    func showsResultCard(hasOffer: Bool, now: Date = .now) -> Bool {
        UpsellPolicy.showsResultCard(hasOffer: hasOffer, record: record, now: now,
                                     reviewPromptedThisSession: reviewPromptedThisSession)
    }

    func showsHistoryCard(hasOffer: Bool, savedEntryCount: Int, now: Date = .now) -> Bool {
        UpsellPolicy.showsHistoryCard(hasOffer: hasOffer, savedEntryCount: savedEntryCount, record: record,
                                      now: now, reviewPromptedThisSession: reviewPromptedThisSession)
    }

    func needsEarlySupporterThanks(_ entitlements: Entitlements) -> Bool {
        UpsellPolicy.needsEarlySupporterThanks(entitlements: entitlements, record: record)
    }

    func dismissResultCard(now: Date = .now) {
        record.resultCardDismissedAt = now
        save()
    }

    func dismissHistoryCard(now: Date = .now) {
        record = UpsellPolicy.recordingHistoryDismissal(record, now: now)
        save()
    }

    func markEarlySupporterThanked() {
        record.earlySupporterThanked = true
        save()
    }

    /// Called when the rating prompt was actually shown.
    func noteReviewPrompted() {
        reviewPromptedThisSession = true
    }

    private func save() {
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }
}
