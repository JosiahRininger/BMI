//
//  StoreService.swift
//  BMICalculator
//
//  StoreKit 2 wrapper for the single one-time, non-consumable
//  "Remove Ads / Pro" purchase. NO subscription.
//
//  Unlocking Pro removes the banner + interstitial (see `AdsManager`, which
//  short-circuits on `StoreState.isPro`). Entitlements are observed live via
//  `Transaction.updates` and verified against `Transaction.currentEntitlements`.
//

import Foundation
import StoreKit

// MARK: - StoreState

/// Observable purchase state the rest of the app binds to.
///
/// `isPro` is the single source of truth for whether ads should be suppressed.
@MainActor
@Observable
public final class StoreState {
    /// `true` once the non-consumable "Remove Ads / Pro" entitlement is owned.
    public internal(set) var isPro = false

    /// The loaded product, once `StoreService` fetches it from the App Store.
    public internal(set) var removeAdsProduct: Product?

    /// Localized price string for UI (e.g. "$4.99"); `nil` until product loads.
    public var displayPrice: String? { removeAdsProduct?.displayPrice }

    /// Whether a purchase / restore is currently in flight (drive a spinner).
    public internal(set) var isProcessing = false

    /// Last user-facing error, if any (cleared on the next action).
    public internal(set) var lastErrorMessage: String?

    public init() {}
}

// MARK: - StoreError

public enum StoreError: LocalizedError {
    case productUnavailable
    case verificationFailed
    case pending
    case unknown

    public var errorDescription: String? {
        switch self {
        case .productUnavailable:
            return "The upgrade isn't available right now. Please try again later."
        case .verificationFailed:
            return "We couldn't verify the purchase with the App Store."
        case .pending:
            return "Your purchase is pending approval."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

// MARK: - StoreService

/// Loads the product, handles purchase / restore, and keeps `StoreState.isPro`
/// in sync with the customer's entitlements for the lifetime of the app.
@MainActor
public final class StoreService {

    /// The single non-consumable product identifier (must match App Store Connect).
    public static let removeAdsProductID = "com.bmi.removeads"

    /// The shared, observable state object injected throughout the UI.
    public let state: StoreState

    /// Background task listening for `Transaction.updates` ( to react to
    /// purchases made on other devices, Ask-to-Buy approvals, refunds, etc.).
    private var updatesTask: Task<Void, Never>?

    /// Soft local cache of the last known entitlement. StoreKit remains the
    /// source of truth, but this (a) prevents an ad "flash" before the async
    /// entitlement check completes at launch, and (b) is a graceful fallback for
    /// the reported iOS 26.x `currentEntitlements`-returns-empty regression.
    private static let proCacheKey = "store.isPro.cache"
    private var cacheDefaults: UserDefaults { UserDefaults(suiteName: "group.com.jdr.BMI") ?? .standard }

    public init(state: StoreState = StoreState()) {
        self.state = state
        // Optimistically reflect the last known entitlement so the UI doesn't
        // briefly show ads to a paying user before `start()` reconciles.
        if cacheDefaults.bool(forKey: Self.proCacheKey) { state.isPro = true }
        self.updatesTask = listenForTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: Lifecycle

    /// Call once at launch: loads the product and syncs current entitlements.
    public func start() async {
        await loadProduct()
        await refreshEntitlements()
    }

    /// Fetches the "Remove Ads / Pro" product from the App Store.
    public func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.removeAdsProductID])
            state.removeAdsProduct = products.first
        } catch {
            state.lastErrorMessage = StoreError.productUnavailable.errorDescription
        }
    }

    // MARK: Purchase / Restore

    /// Initiates the purchase flow for the Remove Ads / Pro product.
    /// - Returns: `true` if the entitlement is now owned.
    @discardableResult
    public func purchase() async -> Bool {
        guard let product = state.removeAdsProduct else {
            state.lastErrorMessage = StoreError.productUnavailable.errorDescription
            return false
        }

        state.isProcessing = true
        state.lastErrorMessage = nil
        defer { state.isProcessing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return state.isPro
            case .pending:
                state.lastErrorMessage = StoreError.pending.errorDescription
                return false
            case .userCancelled:
                return false
            @unknown default:
                state.lastErrorMessage = StoreError.unknown.errorDescription
                return false
            }
        } catch {
            state.lastErrorMessage = (error as? StoreError)?.errorDescription
                ?? StoreError.unknown.errorDescription
            return false
        }
    }

    /// Restores previous purchases. With StoreKit 2 this re-syncs the App Store
    /// account; `AppStore.sync()` may present a sign-in sheet.
    /// - Returns: `true` if Pro is owned after restoring.
    @discardableResult
    public func restore() async -> Bool {
        state.isProcessing = true
        state.lastErrorMessage = nil
        defer { state.isProcessing = false }

        do {
            try await AppStore.sync()
        } catch {
            // Sync can fail (e.g. user cancels sign-in); still re-check entitlements.
        }
        await refreshEntitlements()
        if !state.isPro {
            state.lastErrorMessage = "No previous purchase was found to restore."
        }
        return state.isPro
    }

    // MARK: Entitlements

    /// Recomputes `isPro` from `Transaction.currentEntitlements`.
    public func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            if transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        state.isPro = owned
        // Persist the authoritative result for the next cold launch. We only
        // ever cache a real entitlement read here, so a refund (owned == false)
        // correctly clears the cache — the cache never overrides a true refund.
        cacheDefaults.set(owned, forKey: Self.proCacheKey)
    }

    /// Streams `Transaction.updates` for the app's lifetime, finishing and
    /// re-syncing on each verified transaction.
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                guard let transaction = try? await self.checkVerified(update) else { continue }
                await transaction.finish()
                await self.refreshEntitlements()
            }
        }
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
