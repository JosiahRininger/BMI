//
//  AdsManager.swift
//  BMICalculator
//
//  Google Mobile Ads (SPM) integration: a SwiftUI banner + a single, capped
//  interstitial shown ONLY after a completed calculation.
//
//  ⚠️ HEALTH/AD FIREWALL (App Store Guideline 5.1.3):
//  This file never receives or reads any weight / height / BMI / HealthKit
//  value. Ad requests are configured NON-PERSONALIZED (NPA) so no behavioral
//  targeting occurs. Do not add any health signal to `AdManagerRequest`/`Request`
//  or its `extras`. Keep this firewall intact.
//
//  Monetization rules honored here:
//   • Banner only on the free tier.
//   • Exactly ONE interstitial, only AFTER a completed calc.
//   • Capped (≈ once per 3 calcs) + time cooldown.
//   • Large, obvious system close button (provided by the SDK).
//   • `isPro` short-circuits everything → no ad objects are even created.
//
//  Test ad unit IDs are used in DEBUG; real IDs in release.
//

import Foundation
import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Ad unit identifiers

/// Centralized ad unit IDs. DEBUG builds always use Google's public test units
/// so we never serve (or accidentally click) live ads during development.
public enum AdUnit {

    // Google-published test unit IDs (safe to ship in DEBUG only).
    private static let testBanner = "ca-app-pub-3940256099942544/2934735716"
    private static let testInterstitial = "ca-app-pub-3940256099942544/4411468910"

    // TODO(prod): replace with the real ad units created in AdMob for this app,
    // under app ID ca-app-pub-6687613409331343~7486203316.
    private static let prodBanner = "ca-app-pub-6687613409331343/0000000000"
    private static let prodInterstitial = "ca-app-pub-6687613409331343/1111111111"

    public static var banner: String {
        #if DEBUG
        testBanner
        #else
        prodBanner
        #endif
    }

    public static var interstitial: String {
        #if DEBUG
        testInterstitial
        #else
        prodInterstitial
        #endif
    }
}

// MARK: - AdsManager

/// Owns SDK initialization, interstitial lifecycle, and the frequency cap.
///
/// `@MainActor` + `@Observable` so SwiftUI can react to `isInterstitialReady`.
/// The single shared instance is injected into the environment.
@MainActor
@Observable
public final class AdsManager: NSObject {

    // MARK: Frequency-cap tuning

    /// Show an interstitial at most once every N completed calcs.
    public var calcsPerInterstitial = 3
    /// Minimum seconds between two interstitials, regardless of calc count.
    public var interstitialCooldown: TimeInterval = 120

    // MARK: State

    /// Whether an interstitial is loaded and ready to present.
    public private(set) var isInterstitialReady = false

    /// Drives the banner: when Pro, the banner view renders nothing.
    public private(set) var isPro = false

    /// Whether the SDK has been started (prevents double init).
    private var didStart = false

    // Cap bookkeeping.
    private var calcsSinceLastInterstitial = 0
    private var lastInterstitialDate: Date?

    #if canImport(GoogleMobileAds)
    private var interstitial: InterstitialAd?
    #endif

    public override init() {
        super.init()
    }

    // MARK: Pro state

    /// Updates Pro status. When Pro becomes active, all ad objects are released
    /// and no further ads are requested or shown.
    public func setPro(_ pro: Bool) {
        isPro = pro
        if pro {
            #if canImport(GoogleMobileAds)
            interstitial = nil
            #endif
            isInterstitialReady = false
        } else if didStart {
            // Returned to free tier (e.g. refund) — repopulate.
            loadInterstitial()
        }
    }

    // MARK: SDK lifecycle

    /// Starts the Mobile Ads SDK once and preloads the first interstitial.
    /// No-op when Pro. Safe to call multiple times.
    public func start() {
        guard !isPro, !didStart else { return }
        didStart = true

        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        loadInterstitial()
        #endif
    }

    // MARK: Non-personalized request

    /// Builds a NON-PERSONALIZED ad request. This is the *only* request factory;
    /// it intentionally carries no user/health signal. Do not add `extras`
    /// derived from health data — see firewall note at top of file.
    #if canImport(GoogleMobileAds)
    private func nonPersonalizedRequest() -> Request {
        let request = Request()
        let extras = Extras()
        // "npa=1" → request non-personalized ads (no behavioral targeting).
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }
    #endif

    // MARK: Interstitial loading

    /// Loads (or reloads) the single interstitial. No-op when Pro.
    public func loadInterstitial() {
        guard !isPro else { return }
        #if canImport(GoogleMobileAds)
        Task { @MainActor in
            do {
                let ad = try await InterstitialAd.load(
                    with: AdUnit.interstitial,
                    request: nonPersonalizedRequest()
                )
                ad.fullScreenContentDelegate = self
                self.interstitial = ad
                self.isInterstitialReady = true
            } catch {
                self.interstitial = nil
                self.isInterstitialReady = false
            }
        }
        #endif
    }

    // MARK: Interstitial presentation

    /// Records a completed calculation and, if the cap + cooldown allow, shows
    /// the interstitial. Call this **after** a calculation completes.
    ///
    /// Returns `true` if an ad was presented.
    @discardableResult
    public func maybeShowInterstitial() -> Bool {
        // Pro users never see interstitials.
        guard !isPro else { return false }

        calcsSinceLastInterstitial += 1

        // Frequency cap: only every Nth completed calc.
        guard calcsSinceLastInterstitial >= calcsPerInterstitial else { return false }

        // Time cooldown.
        if let last = lastInterstitialDate,
           Date.now.timeIntervalSince(last) < interstitialCooldown {
            return false
        }

        guard isInterstitialReady else { return false }

        #if canImport(GoogleMobileAds)
        guard let interstitial, let root = Self.topViewController() else { return false }
        interstitial.present(from: root)
        // Reset cap counters; delegate will reload the next ad on dismiss.
        calcsSinceLastInterstitial = 0
        lastInterstitialDate = .now
        isInterstitialReady = false
        return true
        #else
        return false
        #endif
    }

    // MARK: Root view controller lookup

    #if canImport(GoogleMobileAds)
    /// Finds the frontmost presented view controller to host the interstitial.
    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        guard var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController { top = presented }
        return top
    }
    #endif
}

// MARK: - FullScreenContentDelegate

#if canImport(GoogleMobileAds)
extension AdsManager: FullScreenContentDelegate {
    /// Preload the next interstitial as soon as the current one is dismissed.
    public func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        isInterstitialReady = false
        loadInterstitial()
    }

    /// On a presentation failure, drop the ad and try to reload.
    public func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        interstitial = nil
        isInterstitialReady = false
        loadInterstitial()
    }
}
#endif

// MARK: - Banner view (SwiftUI)

/// A SwiftUI banner that renders the AdMob banner on the free tier and nothing
/// when Pro. Drop it into a layout with a fixed height (50pt standard banner).
///
/// Usage:
/// ```swift
/// if !storeState.isPro {
///     AdBannerView().frame(height: 50)
/// }
/// ```
public struct AdBannerView: View {
    /// When `true`, the banner renders nothing (Pro tier).
    public var isPro: Bool

    public init(isPro: Bool = false) {
        self.isPro = isPro
    }

    public var body: some View {
        if isPro {
            EmptyView()
        } else {
            #if canImport(GoogleMobileAds)
            BannerRepresentable()
                .frame(height: 50)
                .accessibilityLabel("Advertisement")
            #else
            // SDK not linked (e.g. previews / unit-test target): render nothing.
            EmptyView()
            #endif
        }
    }
}

// MARK: - Banner UIViewRepresentable

#if canImport(GoogleMobileAds)
/// Bridges the AdMob `BannerView` into SwiftUI using a non-personalized request.
private struct BannerRepresentable: UIViewRepresentable {

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = AdUnit.banner
        banner.rootViewController = rootViewController()

        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"] // non-personalized
        request.register(extras)
        banner.load(request)

        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        if uiView.rootViewController == nil {
            uiView.rootViewController = rootViewController()
        }
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .windows.first(where: \.isKeyWindow)?
            .rootViewController
    }
}
#endif
