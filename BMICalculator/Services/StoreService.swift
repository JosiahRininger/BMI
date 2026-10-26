//
//  StoreService.swift
//  BMICalculator
//
//  StoreKit 2 wrapper for the two one-time, non-consumable purchases: Pro and
//  Remove Ads. NO subscription.
//
//  `Transaction.currentEntitlements` is read at launch and after every purchase
//  or restore, and `Transaction.updates` is observed for the app's lifetime, so
//  purchases on other devices, Ask to Buy approvals, and refunds all apply
//  without a relaunch. Only `.verified` transactions count. The rules for what
//  a set of purchases unlocks live in `Entitlements.swift`; this file only
//  gathers purchases from StoreKit and publishes the result.
//
//  StoreKit 2 also returns purchases made through the original StoreKit API, so
//  every Remove Ads buyer is covered.
//

import Foundation
import StoreKit

// MARK: - StoreState

/// Observable purchase state the rest of the app binds to.
@MainActor
@Observable
public final class StoreState {

    /// What the customer is entitled to. The single source of truth for ads
    /// and Pro gating.
    var entitlements: Entitlements = .none

    /// `true` once entitlements are known for this launch: either restored from
    /// the on-device cache or read from StoreKit. Until then nothing requests an
    /// ad, so a paying customer on a fresh install never sees one.
    public internal(set) var isResolved = false

    /// The loaded products, once fetched from the App Store.
    public internal(set) var proProduct: Product?
    public internal(set) var removeAdsProduct: Product?

    /// `true` once StoreKit itself (a non-empty entitlements read, a purchase,
    /// or a transaction update) has confirmed the purchases this launch. One-time
    /// moments like the early supporter thank-you wait for it, so a provisional
    /// 2.0.x cache can't trigger them.
    public internal(set) var isConfirmedByStoreKit = false

    /// Whether a purchase or restore is in flight (drives spinners).
    public internal(set) var isProcessing = false

    /// Last user-facing error, if any (cleared on the next action).
    public internal(set) var lastErrorMessage: String?

    /// The Pro launch cutoff (injectable for tests).
    let proLaunchCutoff: Date

    init(proLaunchCutoff: Date = ProLaunch.cutoff) {
        self.proLaunchCutoff = proLaunchCutoff
    }

    // MARK: Derived

    /// No ads anywhere.
    public var adsRemoved: Bool { entitlements.adsRemoved }

    /// The Pro features are unlocked.
    public var hasPro: Bool { entitlements.pro }

    /// Pro comes from an early Remove Ads purchase.
    public var isEarlySupporter: Bool { entitlements.earlySupporter }

    /// What the purchase surfaces should offer right now.
    var offer: PurchaseOffer {
        PurchaseOffer.make(for: entitlements, now: .now, cutoff: proLaunchCutoff)
    }

    /// `true` while there is still something to offer (Pro, or the upgrade).
    public var hasUpsellOffer: Bool { offer.hasOffer }

    /// Localized prices for UI (e.g. "$4.99"); `nil` until products load.
    public var proPrice: String? { proProduct?.displayPrice }
    public var removeAdsPrice: String? { removeAdsProduct?.displayPrice }
}

// MARK: - StoreError

public enum StoreError: LocalizedError {
    case productUnavailable
    case verificationFailed
    case unknown

    public var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "This purchase isn't available right now. Please try again later."
        case .verificationFailed:
            return "We couldn't verify the purchase with the App Store."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

/// The outcome of a purchase attempt, so the UI can react precisely.
public enum PurchaseOutcome: Equatable, Sendable {
    /// The purchase completed and the entitlement is now owned.
    case purchased
    /// Waiting for approval (Ask to Buy or a payment issue). Nothing unlocks
    /// until the approval arrives through `Transaction.updates`.
    case pending
    /// The person closed the purchase sheet.
    case cancelled
    /// The purchase failed; `StoreState.lastErrorMessage` explains why.
    case failed
}

// MARK: - StoreService

/// Loads products, handles purchase and restore, and keeps `StoreState` in sync
/// with the customer's entitlements for the lifetime of the app.
@MainActor
@Observable
public final class StoreService {

    /// The shared, observable state object injected throughout the UI.
    public let state: StoreState

    /// The App Group cache (injectable for tests).
    @ObservationIgnored private let cache: EntitlementCache

    /// The last known purchases (what `state.entitlements` was resolved from).
    @ObservationIgnored private(set) var purchases: [OwnedPurchase] = []

    /// Background task listening for `Transaction.updates`.
    // `nonisolated(unsafe)` so `deinit` (nonisolated) can cancel it; the value is
    // only ever assigned on the main actor and Task.cancel() is thread-safe.
    @ObservationIgnored nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    /// Called on the main actor whenever entitlements change (widgets, ads).
    @ObservationIgnored var onEntitlementsChanged: ((Entitlements) -> Void)?

    init(state: StoreState, cache: EntitlementCache = .appGroup, listensForUpdates: Bool = true) {
        self.state = state
        self.cache = cache
        // Reflect the last known purchases immediately, so a paying customer
        // never sees an ad flash before the StoreKit read completes.
        if let cached = cache.load() {
            purchases = cached
            state.entitlements = resolveEntitlements(cached, proLaunchCutoff: state.proLaunchCutoff)
            state.isResolved = true
        }
        if listensForUpdates {
            updatesTask = listenForTransactions()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: Lifecycle

    /// Call once at launch. Entitlements come first: they're read locally (no
    /// network), and ads wait on them. Products need the network.
    public func start() async {
        await refreshEntitlements()
        await loadProducts()
    }

    /// Fetches both products from the App Store.
    public func loadProducts() async {
        do {
            let products = try await Product.products(for: ProductID.all)
            for product in products {
                switch product.id {
                case ProductID.pro: state.proProduct = product
                case ProductID.removeAds: state.removeAdsProduct = product
                default: break
                }
            }
        } catch {
            // Quiet: the purchase buttons show a fallback label and the error
            // surfaces only if the person actually tries to buy.
        }
    }

    // MARK: Purchase / Restore

    /// Starts the purchase flow for one product.
    @discardableResult
    public func purchase(_ productID: String) async -> PurchaseOutcome {
        // One purchase at a time: a second tap while one is in flight (including
        // the product reload below) does nothing.
        guard !state.isProcessing else { return .cancelled }
        state.isProcessing = true
        state.lastErrorMessage = nil
        defer { state.isProcessing = false }

        // Products load once at launch; if that failed (offline, a store
        // hiccup), try again now rather than failing until the next launch.
        if ProductID.all.contains(productID), loadedProduct(productID) == nil {
            await loadProducts()
        }
        guard let product = loadedProduct(productID) else {
            state.lastErrorMessage = StoreError.productUnavailable.errorDescription
            return .failed
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                apply(EntitlementReconciler.adding(OwnedPurchase(transaction), to: purchases), confirmed: true)
                await refreshEntitlements()
                return ownsAfterPurchase(productID) ? .purchased : .failed
            case .pending:
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                state.lastErrorMessage = StoreError.unknown.errorDescription
                return .failed
            }
        } catch {
            state.lastErrorMessage = (error as? StoreError)?.errorDescription
                ?? StoreError.unknown.errorDescription
            return .failed
        }
    }

    /// Restores earlier purchases. `AppStore.sync()` may show a sign-in sheet,
    /// so it runs only when the person taps Restore.
    /// - Returns: `true` if anything is owned after restoring.
    @discardableResult
    public func restore() async -> Bool {
        state.isProcessing = true
        state.lastErrorMessage = nil
        defer { state.isProcessing = false }

        do {
            try await AppStore.sync()
        } catch {
            // Sync can fail (e.g. the person cancels sign-in); still re-check.
        }
        await refreshEntitlements()
        if !state.adsRemoved {
            state.lastErrorMessage = "No earlier purchase was found for this Apple Account."
        }
        return state.adsRemoved
    }

    // MARK: Entitlements

    /// Re-reads `Transaction.currentEntitlements` and publishes the result.
    public func refreshEntitlements() async {
        var fresh: [OwnedPurchase] = []
        var sequenceWasEmpty = true
        for await result in Transaction.currentEntitlements {
            sequenceWasEmpty = false
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil,
                  ProductID.all.contains(transaction.productID) else { continue }
            fresh.append(OwnedPurchase(transaction))
        }
        let cached: [OwnedPurchase]? = state.isResolved ? purchases : cache.load()
        apply(EntitlementReconciler.reconcile(cached: cached, fresh: fresh, sequenceWasEmpty: sequenceWasEmpty),
              confirmed: !sequenceWasEmpty)
    }

    /// Publishes a set of purchases: resolves, caches, and notifies.
    /// - Parameter confirmed: StoreKit itself produced these purchases (not just
    ///   the cache surviving an empty read).
    func apply(_ newPurchases: [OwnedPurchase], confirmed: Bool = false) {
        // Confirmed only when StoreKit produced the data AND no 2.0.x
        // placeholder (unknown date) is left in it.
        if confirmed && !newPurchases.contains(where: { $0.isUnconfirmed }) {
            state.isConfirmedByStoreKit = true
        }
        purchases = newPurchases
        let resolved = resolveEntitlements(newPurchases, proLaunchCutoff: state.proLaunchCutoff)
        let changed = resolved != state.entitlements || !state.isResolved
        state.entitlements = resolved
        state.isResolved = true
        cache.save(newPurchases, entitlements: resolved)
        if changed { onEntitlementsChanged?(resolved) }
    }

    /// Streams `Transaction.updates` for the app's lifetime.
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                guard let transaction = try? self.checkVerified(update) else { continue }
                await transaction.finish()
                await self.handle(update: transaction)
            }
        }
    }

    /// Applies one transaction update. A revocation (refund) is the only
    /// reliable refund signal, because the next `currentEntitlements` read can
    /// be empty (see `EntitlementReconciler`), so it's honored directly.
    func handle(update transaction: Transaction) async {
        guard ProductID.all.contains(transaction.productID) else { return }
        if transaction.revocationDate != nil {
            apply(EntitlementReconciler.removing(transaction.productID, from: purchases), confirmed: true)
        } else {
            apply(EntitlementReconciler.adding(OwnedPurchase(transaction), to: purchases), confirmed: true)
            await refreshEntitlements()
        }
    }

    /// The loaded product for an ID; `nil` for unknown IDs or before loading.
    private func loadedProduct(_ productID: String) -> Product? {
        switch productID {
        case ProductID.pro: return state.proProduct
        case ProductID.removeAds: return state.removeAdsProduct
        default: return nil
        }
    }

    private func ownsAfterPurchase(_ productID: String) -> Bool {
        productID == ProductID.pro ? state.hasPro : state.adsRemoved
    }

    // MARK: Verification

    /// Unwraps StoreKit's `VerificationResult`, throwing on an unverified payload.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Transaction → OwnedPurchase

extension OwnedPurchase {
    init(_ transaction: Transaction) {
        self.init(
            productID: transaction.productID,
            originalPurchaseDate: transaction.originalPurchaseDate,
            isRevoked: transaction.revocationDate != nil
        )
    }
}
