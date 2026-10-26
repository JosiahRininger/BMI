//
//  StoreServiceTests.swift
//  BMICalculatorTests
//
//  End-to-end purchase behavior against Apple's local StoreKit test
//  environment (`SKTestSession` + Products.storekit): real products, real
//  transactions, refunds, Ask to Buy, restores, and the offline/empty-read
//  path, through the actual `StoreService`.
//

import Testing
import Foundation
import StoreKit
import StoreKitTest
@testable import BMICalculator

@Suite("StoreService with StoreKit test session", .serialized)
@MainActor
struct StoreServiceTests {

    // MARK: Helpers

    /// A fresh session with no transactions and no system dialogs.
    private func makeSession() throws -> SKTestSession {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        session.askToBuyEnabled = false
        return session
    }

    /// An isolated cache (a fresh UserDefaults suite).
    private func makeCache() -> EntitlementCache {
        let name = "test.store.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return EntitlementCache(defaults: defaults)
    }

    /// A service whose cutoff makes any purchase made now "early" or "late".
    private func makeService(earlyPurchases: Bool, cache: EntitlementCache? = nil,
                             listens: Bool = false) -> StoreService {
        let cutoff = earlyPurchases ? Date().addingTimeInterval(86_400) : Date().addingTimeInterval(-86_400)
        return StoreService(state: StoreState(proLaunchCutoff: cutoff), cache: cache ?? makeCache(),
                            listensForUpdates: listens)
    }

    /// Waits (up to ~5 s) for a condition driven by `Transaction.updates`.
    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async -> Bool {
        for _ in 0..<50 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    // MARK: Products

    @Test("Both products load with their configured prices")
    func productsLoad() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: false)
        await service.loadProducts()
        #expect(service.state.proProduct?.id == ProductID.pro)
        #expect(service.state.removeAdsProduct?.id == ProductID.removeAds)
        #expect(service.state.proProduct?.price == Decimal(string: "4.99"))
        #expect(service.state.removeAdsProduct?.price == Decimal(string: "1.99"))
        #expect(service.state.proProduct?.type == .nonConsumable)
        #expect(service.state.removeAdsProduct?.type == .nonConsumable)
    }

    // MARK: Fresh install

    @Test("1. Fresh install: unresolved until the first read, then ads on and Pro locked")
    func freshInstall() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: false)
        #expect(service.state.isResolved == false)          // no ad request yet
        await service.refreshEntitlements()
        #expect(service.state.isResolved)
        #expect(service.state.entitlements == .none)
        #expect(service.state.hasUpsellOffer)
    }

    // MARK: Purchases

    @Test("4/10. Buying Pro unlocks Pro and removes ads immediately")
    func buyPro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: false)
        await service.loadProducts()
        var changes: [Entitlements] = []
        service.onEntitlementsChanged = { changes.append($0) }

        let outcome = await service.purchase(ProductID.pro)
        #expect(outcome == .purchased)
        #expect(service.state.hasPro)
        #expect(service.state.adsRemoved)
        #expect(service.state.isEarlySupporter == false)
        #expect(service.state.hasUpsellOffer == false)
        #expect(changes.last == Entitlements(adsRemoved: true, pro: true, earlySupporter: false))
    }

    @Test("3. Remove Ads bought after the cutoff: no ads, Pro locked, upgrade offered")
    func buyRemoveAdsLate() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: false)
        await service.loadProducts()
        #expect(await service.purchase(ProductID.removeAds) == .purchased)
        #expect(service.state.adsRemoved)
        #expect(service.state.hasPro == false)
        #expect(service.state.offer == .upgradeToPro)
    }

    @Test("2. Remove Ads bought before the cutoff: no ads, Pro unlocked, early supporter")
    func buyRemoveAdsEarly() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: true)
        await service.loadProducts()
        #expect(await service.purchase(ProductID.removeAds) == .purchased)
        #expect(service.state.adsRemoved)
        #expect(service.state.hasPro)
        #expect(service.state.isEarlySupporter)
        #expect(service.state.offer == .nothing)
    }

    @Test("5. Owning both: Pro unlocked and no early-supporter thank-you")
    func ownsBoth() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: true)
        await service.loadProducts()
        _ = await service.purchase(ProductID.removeAds)
        _ = await service.purchase(ProductID.pro)
        #expect(service.state.hasPro)
        #expect(service.state.isEarlySupporter == false)
    }

    @Test("Buying a product that hasn't loaded fails gracefully with a message")
    func purchaseWithoutProducts() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: false)
        #expect(await service.purchase(ProductID.pro) == .failed)
        #expect(service.state.lastErrorMessage != nil)
        #expect(service.state.isProcessing == false)
    }

    // MARK: Refunds

    @Test("6. A refund arrives through Transaction.updates and takes Pro and ad-free away")
    func refundRemovesPro() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let service = makeService(earlyPurchases: false, listens: true)
        await service.loadProducts()
        #expect(await service.purchase(ProductID.pro) == .purchased)

        let transaction = try #require(session.allTransactions().first { $0.productIdentifier == ProductID.pro })
        try session.refundTransaction(identifier: transaction.identifier)

        let cleared = await waitUntil { !service.state.hasPro && !service.state.adsRemoved }
        #expect(cleared)
    }

    // MARK: Ask to Buy

    @Test("8. Ask to Buy: nothing unlocks while pending, then Pro unlocks on approval")
    func askToBuy() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let service = makeService(earlyPurchases: false, listens: true)
        await service.loadProducts()

        #expect(await service.purchase(ProductID.pro) == .pending)
        #expect(service.state.hasPro == false)
        #expect(service.state.adsRemoved == false)

        let pending = try #require(session.allTransactions().first { $0.productIdentifier == ProductID.pro })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)

        let unlocked = await waitUntil { service.state.hasPro }
        #expect(unlocked)
    }

    // MARK: Restore / new device

    @Test("7. Restore on a new device (empty cache) gives the same entitlements")
    func newDeviceRestore() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let original = makeService(earlyPurchases: true)
        await original.loadProducts()
        _ = await original.purchase(ProductID.removeAds)
        let before = original.state.entitlements

        // A second device: nothing cached, same Apple Account.
        let newDevice = makeService(earlyPurchases: true)
        #expect(newDevice.state.isResolved == false)
        await newDevice.refreshEntitlements()
        #expect(newDevice.state.entitlements == before)
        #expect(newDevice.state.isEarlySupporter)
    }

    // MARK: Offline / empty read

    @Test("9. A paying customer's cache survives an empty StoreKit read: no ad flash")
    func cacheSurvivesEmptyRead() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let cache = makeCache()
        cache.save([OwnedPurchase(productID: ProductID.removeAds, originalPurchaseDate: .distantPast)],
                   entitlements: Entitlements(adsRemoved: true, pro: true, earlySupporter: true))

        let service = makeService(earlyPurchases: false, cache: cache)
        // Resolved from the cache before any StoreKit call: the banner can't load.
        #expect(service.state.isResolved)
        #expect(service.state.adsRemoved)

        // StoreKit has no transactions (like the iOS 26 empty read): keep the cache.
        await service.refreshEntitlements()
        #expect(service.state.adsRemoved)
        #expect(service.state.hasPro)
    }

    @Test("A 2.0.x cache upgrades cleanly: ad-free and Pro from the first frame")
    func legacyCacheUpgrade() async throws {
        let session = try makeSession()
        defer { session.clearTransactions() }
        let name = "test.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.set(true, forKey: EntitlementCache.legacyAdsRemovedKey)
        let service = StoreService(state: StoreState(), cache: EntitlementCache(defaults: defaults),
                                   listensForUpdates: false)
        #expect(service.state.isResolved)
        #expect(service.state.adsRemoved)
        #expect(service.state.hasPro)
        #expect(service.state.isEarlySupporter)
        defaults.removePersistentDomain(forName: name)
    }
}
