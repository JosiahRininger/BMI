//
//  EntitlementTests.swift
//  BMICalculatorTests
//
//  The purchase rules, exhaustively: who gets ads removed, who gets Pro, who is
//  an early supporter, what each person is offered, how StoreKit reads merge
//  with the cache, and how the cache survives launches (including the 2.0.x
//  cache format).
//

import Testing
import Foundation
@testable import BMICalculator

private let cutoff = Date(timeIntervalSince1970: 1_800_000_000)
private let before = cutoff.addingTimeInterval(-86_400)
private let after = cutoff.addingTimeInterval(86_400)

private func removeAds(_ date: Date, revoked: Bool = false) -> OwnedPurchase {
    OwnedPurchase(productID: ProductID.removeAds, originalPurchaseDate: date, isRevoked: revoked)
}

private func pro(_ date: Date = after, revoked: Bool = false) -> OwnedPurchase {
    OwnedPurchase(productID: ProductID.pro, originalPurchaseDate: date, isRevoked: revoked)
}

// MARK: - resolveEntitlements (the handoff's test matrix)

@Suite("Entitlement rules")
struct EntitlementRulesTests {

    @Test("1. Fresh install, no purchases: ads on, Pro locked")
    func noPurchases() {
        let e = resolveEntitlements([], proLaunchCutoff: cutoff)
        #expect(e == .none)
        #expect(e.adsRemoved == false)
        #expect(e.pro == false)
        #expect(e.earlySupporter == false)
    }

    @Test("2. Remove Ads bought before the cutoff: no ads, Pro unlocked, early supporter")
    func earlyRemoveAds() {
        let e = resolveEntitlements([removeAds(before)], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: true, earlySupporter: true))
    }

    @Test("3. Remove Ads bought after the cutoff: no ads, Pro locked")
    func lateRemoveAds() {
        let e = resolveEntitlements([removeAds(after)], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: false, earlySupporter: false))
    }

    @Test("A purchase exactly at the cutoff is not early (the cutoff is exclusive)")
    func exactlyAtCutoff() {
        let e = resolveEntitlements([removeAds(cutoff)], proLaunchCutoff: cutoff)
        #expect(e.pro == false)
        #expect(e.earlySupporter == false)
        #expect(e.adsRemoved)
    }

    @Test("4. Pro bought: no ads, Pro unlocked, not an early supporter")
    func proOnly() {
        let e = resolveEntitlements([pro()], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: true, earlySupporter: false))
    }

    @Test("5. Both owned (early Remove Ads + Pro): no thank-you, because Pro was bought")
    func bothEarly() {
        let e = resolveEntitlements([removeAds(before), pro()], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: true, earlySupporter: false))
    }

    @Test("5b. Both owned (late Remove Ads + Pro)")
    func bothLate() {
        let e = resolveEntitlements([removeAds(after), pro()], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: true, earlySupporter: false))
    }

    @Test("6. Remove Ads refunded: ads return, Pro removed")
    func removeAdsRevoked() {
        let e = resolveEntitlements([removeAds(before, revoked: true)], proLaunchCutoff: cutoff)
        #expect(e == .none)
    }

    @Test("6b. Remove Ads refunded but Pro owned: Pro and ad-free stay")
    func removeAdsRevokedProOwned() {
        let e = resolveEntitlements([removeAds(before, revoked: true), pro()], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: true, earlySupporter: false))
    }

    @Test("Pro refunded, early Remove Ads kept: still Pro through the early grant")
    func proRevokedEarlyKept() {
        let e = resolveEntitlements([removeAds(before), pro(revoked: true)], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: true, earlySupporter: true))
    }

    @Test("Pro refunded, late Remove Ads kept: ad-free only")
    func proRevokedLateKept() {
        let e = resolveEntitlements([removeAds(after), pro(revoked: true)], proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: false, earlySupporter: false))
    }

    @Test("Unknown product IDs never unlock anything")
    func unknownProduct() {
        let stray = OwnedPurchase(productID: "com.example.other", originalPurchaseDate: before)
        #expect(resolveEntitlements([stray], proLaunchCutoff: cutoff) == .none)
    }

    @Test("A 2.0.x cache entry (distant past) counts as early")
    func legacyCacheIsEarly() {
        let e = resolveEntitlements([removeAds(.distantPast)], proLaunchCutoff: cutoff)
        #expect(e.earlySupporter)
        #expect(e.pro)
    }

    @Test("The real cutoff is Nov 2, 2026 08:00 UTC, after 2.0.2 shipped")
    func realCutoff() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: ProLaunch.cutoff)
        #expect(parts.year == 2026)
        #expect(parts.month == 11)
        #expect(parts.day == 2)
        #expect(parts.hour == 8)
        #expect(parts.minute == 0)
        let twoZeroTwoRelease = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7))!
        #expect(ProLaunch.cutoff > twoZeroTwoRelease)
    }

    @Test("Product IDs are exactly the App Store Connect IDs, and Remove Ads never changes")
    func productIDs() {
        #expect(ProductID.removeAds == "com.bmi.removeads")
        #expect(ProductID.pro == "com.bmi.pro")
        #expect(ProductID.all == ["com.bmi.pro", "com.bmi.removeads"])
    }
}

// MARK: - PurchaseOffer

@Suite("What each customer is offered")
struct PurchaseOfferTests {

    @Test("Before the cutoff, a free customer is offered Pro only")
    func freeBeforeCutoff() {
        #expect(PurchaseOffer.make(for: .none, now: before, cutoff: cutoff) == .pro(includesRemoveAdsOption: false))
    }

    @Test("From the cutoff on, a free customer also sees the ads-only option")
    func freeAfterCutoff() {
        #expect(PurchaseOffer.make(for: .none, now: cutoff, cutoff: cutoff) == .pro(includesRemoveAdsOption: true))
        #expect(PurchaseOffer.make(for: .none, now: after, cutoff: cutoff) == .pro(includesRemoveAdsOption: true))
    }

    @Test("A late Remove Ads owner is offered the upgrade to Pro")
    func lateOwnerUpgrade() {
        let e = resolveEntitlements([removeAds(after)], proLaunchCutoff: cutoff)
        #expect(PurchaseOffer.make(for: e, now: after, cutoff: cutoff) == .upgradeToPro)
    }

    @Test("Pro owners and early supporters are offered nothing")
    func ownersOfferedNothing() {
        let proOwner = resolveEntitlements([pro()], proLaunchCutoff: cutoff)
        let early = resolveEntitlements([removeAds(before)], proLaunchCutoff: cutoff)
        #expect(PurchaseOffer.make(for: proOwner, now: after, cutoff: cutoff) == .nothing)
        #expect(PurchaseOffer.make(for: early, now: after, cutoff: cutoff) == .nothing)
        #expect(PurchaseOffer.nothing.hasOffer == false)
        #expect(PurchaseOffer.upgradeToPro.hasOffer)
        #expect(PurchaseOffer.pro(includesRemoveAdsOption: true).hasOffer)
    }
}

// MARK: - Reconciler

@Suite("Reconciling StoreKit reads with the cache")
struct EntitlementReconcilerTests {

    @Test("An empty read keeps the cache (iOS 26 empty-read guard): no ad flash for payers")
    func emptyReadKeepsCache() {
        let cached = [removeAds(before)]
        let merged = EntitlementReconciler.reconcile(cached: cached, fresh: [], sequenceWasEmpty: true)
        #expect(merged == cached)
    }

    @Test("An empty read with no cache yields nothing")
    func emptyReadNoCache() {
        #expect(EntitlementReconciler.reconcile(cached: nil, fresh: [], sequenceWasEmpty: true).isEmpty)
    }

    @Test("A non-empty read replaces the cache, including removing a product")
    func nonEmptyReadReplaces() {
        let cached = [removeAds(before), pro()]
        let fresh = [removeAds(before)]
        #expect(EntitlementReconciler.reconcile(cached: cached, fresh: fresh, sequenceWasEmpty: false) == fresh)
    }

    @Test("A read that only had unverified results clears the cache")
    func unverifiedOnlyClears() {
        let merged = EntitlementReconciler.reconcile(cached: [pro()], fresh: [], sequenceWasEmpty: false)
        #expect(merged.isEmpty)
    }

    @Test("StoreKit's real (late) date replaces a 2.0.x placeholder and takes the provisional Pro away")
    func placeholderReplaced() {
        let merged = EntitlementReconciler.reconcile(cached: [removeAds(.distantPast)], fresh: [removeAds(after)],
                                                     sequenceWasEmpty: false)
        #expect(merged == [removeAds(after)])
        let e = resolveEntitlements(merged, proLaunchCutoff: cutoff)
        #expect(e.pro == false)
        #expect(e.adsRemoved)
    }

    @Test("A revocation removes just that product")
    func removing() {
        let merged = EntitlementReconciler.removing(ProductID.pro, from: [removeAds(before), pro()])
        #expect(merged == [removeAds(before)])
    }

    @Test("Adding replaces the same product; deduplication keeps the earliest date")
    func addingKeepsEarliest() {
        let merged = EntitlementReconciler.adding(removeAds(after), to: [removeAds(before)])
        #expect(merged == [removeAds(after)])   // adding replaces by product
        let deduped = EntitlementReconciler.deduplicated([removeAds(after), removeAds(before)])
        #expect(deduped == [removeAds(before)])
    }

    @Test("Deduplication drops revoked and unknown products and orders Pro first")
    func deduplicatedFilters() {
        let stray = OwnedPurchase(productID: "com.example.other", originalPurchaseDate: before)
        let result = EntitlementReconciler.deduplicated([removeAds(before), stray, pro(revoked: true), pro()])
        #expect(result == [pro(), removeAds(before)])
    }
}

// MARK: - Cache

@Suite("Entitlement cache")
struct EntitlementCacheTests {

    private func freshDefaults() -> UserDefaults {
        let name = "test.entitlements.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Nothing cached reads as nil (not yet resolved)")
    func emptyIsNil() {
        #expect(EntitlementCache(defaults: freshDefaults()).load() == nil)
    }

    @Test("A 2.0.x 'Remove Ads owned' cache reads as an early Remove Ads purchase")
    func legacyTrue() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: EntitlementCache.legacyAdsRemovedKey)
        let loaded = EntitlementCache(defaults: defaults).load()
        #expect(loaded == [removeAds(.distantPast)])
    }

    @Test("A 2.0.x 'not owned' cache reads as resolved with nothing")
    func legacyFalse() {
        let defaults = freshDefaults()
        defaults.set(false, forKey: EntitlementCache.legacyAdsRemovedKey)
        #expect(EntitlementCache(defaults: defaults).load() == [])
    }

    @Test("Saving round-trips purchases and writes the flags the widget and 2.0.x read")
    func roundTrip() {
        let defaults = freshDefaults()
        let cache = EntitlementCache(defaults: defaults)
        let purchases = [pro(), removeAds(before)]
        let entitlements = resolveEntitlements(purchases, proLaunchCutoff: cutoff)
        cache.save(purchases, entitlements: entitlements)
        #expect(cache.load() == purchases)
        #expect(defaults.bool(forKey: EntitlementCache.legacyAdsRemovedKey))
        #expect(defaults.bool(forKey: EntitlementCache.proUnlockedKey))
        // The widget reads the same key through the shared store.
        #expect(EntitlementCache.proUnlockedKey == BMISharedStore.proUnlockedKey)
        #expect(BMISharedStore.isProUnlocked(in: defaults))
    }

    @Test("A late Remove Ads owner is cached as ad-free but not Pro (the trend widget stays locked)")
    func lateOwnerFlags() {
        let defaults = freshDefaults()
        let cache = EntitlementCache(defaults: defaults)
        let purchases = [removeAds(after)]
        let e = resolveEntitlements(purchases, proLaunchCutoff: cutoff)
        #expect(e == Entitlements(adsRemoved: true, pro: false, earlySupporter: false))
        cache.save(purchases, entitlements: e)
        #expect(defaults.bool(forKey: EntitlementCache.legacyAdsRemovedKey))
        #expect(defaults.bool(forKey: EntitlementCache.proUnlockedKey) == false)
        #expect(BMISharedStore.isProUnlocked(in: defaults) == false)
    }

    @Test("A provisional 2.0.x placeholder is never written as a 2.1 purchase")
    func placeholderNotPersisted() {
        let defaults = freshDefaults()
        defaults.set(true, forKey: EntitlementCache.legacyAdsRemovedKey)
        let cache = EntitlementCache(defaults: defaults)
        let loaded = cache.load()!
        #expect(loaded.allSatisfy { $0.isUnconfirmed })
        cache.save(loaded, entitlements: resolveEntitlements(loaded, proLaunchCutoff: cutoff))
        #expect(defaults.data(forKey: EntitlementCache.purchasesKey) == nil)   // still re-read from 2.0.x next launch
        #expect(cache.load() == loaded)
        // Once StoreKit supplies the real date, the real purchase is written.
        cache.save([removeAds(after)], entitlements: resolveEntitlements([removeAds(after)], proLaunchCutoff: cutoff))
        #expect(cache.load() == [removeAds(after)])
    }

    @Test("The 2.1 cache takes precedence over the 2.0.x flag")
    func v2Precedence() {
        let defaults = freshDefaults()
        let cache = EntitlementCache(defaults: defaults)
        cache.save([], entitlements: .none)
        #expect(cache.load() == [])
        #expect(defaults.bool(forKey: EntitlementCache.legacyAdsRemovedKey) == false)
        #expect(BMISharedStore.isProUnlocked(in: defaults) == false)
    }

    @Test("The App Group ID matches the one the app and widget use")
    func appGroupID() {
        #expect(EntitlementCache.appGroupID == BMISharedStore.appGroupID)
        #expect(EntitlementCache.appGroupID == AppConfig.appGroupID)
    }
}

// MARK: - Restore copy

@Suite("Restore messages")
struct RestoreCopyTests {

    @Test("Early supporters, Pro owners, and ad-free owners each get the right welcome back")
    func messages() {
        let early = Entitlements(adsRemoved: true, pro: true, earlySupporter: true)
        let proOwner = Entitlements(adsRemoved: true, pro: true, earlySupporter: false)
        let adsOnly = Entitlements(adsRemoved: true, pro: false, earlySupporter: false)
        #expect(RestoreCopy.message(for: early).contains("includes Pro"))
        #expect(RestoreCopy.message(for: proOwner) == "Welcome back. Pro is unlocked.")
        #expect(RestoreCopy.message(for: adsOnly) == "Welcome back. Your ads are removed.")
    }

    @Test("No user-facing purchase copy uses an em dash")
    func noEmDashes() {
        let copy = [ProCopy.name, ProCopy.tagline, ProCopy.footer, ProCopy.supporter, ProCopy.shortList,
                    ProSheet.proThanks, ProSheet.removeAdsThanks, DoctorSummary.title, DoctorSummary.footer]
            + ProCopy.features(includingNoAds: true).flatMap { [$0.title, $0.detail] }
            + [RestoreCopy.message(for: .none), RestoreCopy.message(for: Entitlements(adsRemoved: true, pro: true, earlySupporter: true))]
        for line in copy {
            #expect(!line.contains("\u{2014}"), "Em dash in: \(line)")
        }
    }
}
