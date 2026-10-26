//
//  Entitlements.swift
//  BMICalculator
//
//  The pure, StoreKit-free core of the purchase model, so every rule about who
//  gets what is unit-testable without the App Store.
//
//  Two one-time, non-consumable products exist:
//   • Remove Ads (`com.bmi.removeads`, $1.99): removes ads only.
//   • Pro (`com.bmi.pro`, $4.99): removes ads AND unlocks the Pro features.
//
//  Early supporters: anyone whose Remove Ads purchase was made before
//  `ProLaunch.cutoff` gets full Pro at no cost. The app called that purchase
//  "Pro" before Pro existed, so this keeps the promise. The rule reads only
//  StoreKit's own purchase data (`originalPurchaseDate`), never a local flag or
//  code, so it stays an App Store purchase unlock (Guideline 3.1.1).
//
//  NEVER delete, rename, or reuse the Remove Ads product ID: existing buyers'
//  ad-free experience depends on it forever.
//

import Foundation

// MARK: - Product IDs

/// The App Store product identifiers. Must match App Store Connect and
/// `Products.storekit` exactly.
enum ProductID {
    /// One-time "Remove Ads" (ads only). Live since 2.0; keep valid forever.
    static let removeAds = "com.bmi.removeads"

    /// One-time "BMI Calculator Pro" (no ads plus the Pro features).
    static let pro = "com.bmi.pro"

    /// Every product the app sells, in display priority order.
    static let all: [String] = [pro, removeAds]
}

// MARK: - Pro launch cutoff

enum ProLaunch {

    /// Remove Ads purchases made strictly before this instant count as early
    /// supporter purchases and include Pro. It sits a few days after the 2.1
    /// submission, so everything bought under the old "Remove Ads / BMI Pro"
    /// label qualifies. Before this instant 2.1 itself sells only Pro (see
    /// `PurchaseOffer`), so nobody can buy Remove Ads in 2.1 and slip under it.
    /// If the 2.1 release slips past this date, move it to the release day.
    static let cutoff: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "UTC")
        components.year = 2026
        components.month = 11
        components.day = 2
        components.hour = 8          // midnight Pacific
        return components.date ?? Date(timeIntervalSince1970: 1_793_606_400)
    }()
}

// MARK: - Purchases and entitlements

/// One verified purchase the customer owns, reduced to the fields the rules use.
struct OwnedPurchase: Codable, Equatable, Hashable, Sendable {
    let productID: String
    let originalPurchaseDate: Date
    var isRevoked: Bool = false

    /// The stand-in date for a 2.0.x cached purchase whose real date is unknown
    /// until StoreKit is read. It sorts before the cutoff, so the customer keeps
    /// ad-free (and provisional Pro) on a cold or offline launch.
    static let unconfirmedDate = Date.distantPast

    /// `true` for a 2.0.x placeholder that StoreKit hasn't confirmed yet.
    var isUnconfirmed: Bool { originalPurchaseDate == Self.unconfirmedDate }
}

/// What the customer is entitled to right now.
struct Entitlements: Codable, Equatable, Sendable {
    /// No ads anywhere (Remove Ads, Pro, or early supporter).
    var adsRemoved = false
    /// The Pro features are unlocked (Pro purchase or early supporter).
    var pro = false
    /// Pro comes from an early Remove Ads purchase rather than a Pro purchase.
    /// Drives the one-time thank-you and the grandfathered Settings wording.
    var earlySupporter = false

    static let none = Entitlements()
}

/// The single rule that turns owned purchases into entitlements.
func resolveEntitlements(_ purchases: [OwnedPurchase], proLaunchCutoff: Date) -> Entitlements {
    let active = purchases.filter { !$0.isRevoked }
    let ownsPro = active.contains { $0.productID == ProductID.pro }
    let ownsRemoveAds = active.contains { $0.productID == ProductID.removeAds }
    let early = active.contains {
        $0.productID == ProductID.removeAds && $0.originalPurchaseDate < proLaunchCutoff
    }
    return Entitlements(
        adsRemoved: ownsPro || ownsRemoveAds,
        pro: ownsPro || early,
        earlySupporter: early && !ownsPro
    )
}

// MARK: - What to offer

/// What the purchase surfaces should offer this customer.
enum PurchaseOffer: Equatable, Sendable {
    /// Nothing owned: offer Pro, plus Remove Ads as the ads-only option once the
    /// cutoff has passed.
    case pro(includesRemoveAdsOption: Bool)
    /// Owns Remove Ads (bought after the cutoff): offer the Pro upgrade only.
    case upgradeToPro
    /// Pro is unlocked (bought or early supporter): offer nothing.
    case nothing

    static func make(for entitlements: Entitlements, now: Date, cutoff: Date = ProLaunch.cutoff) -> PurchaseOffer {
        if entitlements.pro { return .nothing }
        if entitlements.adsRemoved { return .upgradeToPro }
        return .pro(includesRemoveAdsOption: now >= cutoff)
    }

    /// Whether any upsell should be shown at all.
    var hasOffer: Bool { self != .nothing }
}

// MARK: - Reconciling StoreKit reads with the cache

enum EntitlementReconciler {

    /// Merges a fresh `Transaction.currentEntitlements` read with the cached
    /// purchases.
    ///
    /// iOS 26.x has a reported regression where `currentEntitlements` yields an
    /// EMPTY sequence for a paying customer, which looks exactly like a genuine
    /// "owns nothing" read. Flipping a paying user back to ads on that read is the
    /// worse failure, so an empty read keeps the cache. A real refund is still
    /// honored: it arrives through `Transaction.updates` and is applied with
    /// `removing(_:from:)`. A non-empty read is trusted and replaces the cache.
    ///
    /// - Parameters:
    ///   - cached: The last known purchases, or `nil` if nothing was ever cached.
    ///   - fresh: Verified, non-revoked purchases from this read.
    ///   - sequenceWasEmpty: `true` when the read yielded no results at all
    ///     (verified or not).
    static func reconcile(
        cached: [OwnedPurchase]?,
        fresh: [OwnedPurchase],
        sequenceWasEmpty: Bool
    ) -> [OwnedPurchase] {
        if sequenceWasEmpty {
            return cached ?? []
        }
        return deduplicated(fresh)
    }

    /// Drops a product from the known purchases (a revocation or refund).
    static func removing(_ productID: String, from purchases: [OwnedPurchase]) -> [OwnedPurchase] {
        purchases.filter { $0.productID != productID }
    }

    /// Adds or updates a purchase (a new purchase or an Ask to Buy approval).
    static func adding(_ purchase: OwnedPurchase, to purchases: [OwnedPurchase]) -> [OwnedPurchase] {
        deduplicated(purchases.filter { $0.productID != purchase.productID } + [purchase])
    }

    /// One entry per product, keeping the earliest original purchase date (the
    /// date that decides early supporter status) and only known products.
    static func deduplicated(_ purchases: [OwnedPurchase]) -> [OwnedPurchase] {
        var byProduct: [String: OwnedPurchase] = [:]
        for purchase in purchases where ProductID.all.contains(purchase.productID) && !purchase.isRevoked {
            if let existing = byProduct[purchase.productID],
               existing.originalPurchaseDate <= purchase.originalPurchaseDate {
                continue
            }
            byProduct[purchase.productID] = purchase
        }
        return ProductID.all.compactMap { byProduct[$0] }
    }
}

// MARK: - On-device cache

/// The last known purchases, kept in App Group `UserDefaults` so a paying
/// customer never sees an ad flash on a cold or offline launch, and so the
/// widget can read Pro state. StoreKit stays the authority; this is a hint.
struct EntitlementCache {

    /// The App Group suite shared with the widget.
    static let appGroupID = "group.com.jdr.BMI"

    /// JSON `[OwnedPurchase]`, written by 2.1 and later.
    static let purchasesKey = "store.purchases.v2"

    /// `Bool` written by 2.0.x: `true` meant Remove Ads was owned. Still written
    /// (as "ads removed") so the value stays truthful for anything reading it.
    static let legacyAdsRemovedKey = "store.isPro.cache"

    /// `Bool` the widget reads to decide whether the Pro trend widget unlocks.
    static let proUnlockedKey = "store.pro.unlocked"

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The shared App Group cache (falls back to standard defaults when the App
    /// Group isn't provisioned, e.g. unsigned builds).
    static var appGroup: EntitlementCache {
        EntitlementCache(defaults: UserDefaults(suiteName: appGroupID) ?? .standard)
    }

    /// The cached purchases, or `nil` if this device has never resolved them.
    ///
    /// A 2.0.x cache only stored "Remove Ads owned", with no date. It's read
    /// back as a Remove Ads purchase dated `OwnedPurchase.unconfirmedDate` so a
    /// paying customer never sees an ad flash. That placeholder is provisional:
    /// it is never written to the 2.1 cache, and nothing one-time (the early
    /// supporter thank-you) runs until StoreKit supplies the real date.
    func load() -> [OwnedPurchase]? {
        if let data = defaults.data(forKey: Self.purchasesKey),
           let purchases = try? JSONDecoder().decode([OwnedPurchase].self, from: data) {
            return purchases
        }
        if defaults.object(forKey: Self.legacyAdsRemovedKey) != nil {
            return defaults.bool(forKey: Self.legacyAdsRemovedKey)
                ? [OwnedPurchase(productID: ProductID.removeAds, originalPurchaseDate: OwnedPurchase.unconfirmedDate)]
                : []
        }
        return nil
    }

    /// Persists the purchases and the flags derived from them. A provisional
    /// 2.0.x placeholder is never written as a purchase (only the flags), so the
    /// next launch re-reads the 2.0.x value until StoreKit confirms a real date.
    func save(_ purchases: [OwnedPurchase], entitlements: Entitlements) {
        if !purchases.contains(where: \.isUnconfirmed), let data = try? JSONEncoder().encode(purchases) {
            defaults.set(data, forKey: Self.purchasesKey)
        }
        defaults.set(entitlements.adsRemoved, forKey: Self.legacyAdsRemovedKey)
        defaults.set(entitlements.pro, forKey: Self.proUnlockedKey)
    }
}
