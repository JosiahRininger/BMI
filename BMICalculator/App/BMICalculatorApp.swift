//
//  BMICalculatorApp.swift
//  BMICalculator
//
//  The application entry point and composition root. This file owns the things
//  no single feature module should: the SwiftData `ModelContainer` (placed in a
//  shared App Group so the widget can read history), the long-lived services
//  (`StoreState`/`StoreService`, `AdsManager`, `HealthKitService`,
//  `ReviewPrompter`), the shared `@AppStorage` key namespace, and the deep-link
//  router that turns `bmicalculator://…` URLs and App-Intent launches into
//  in-app navigation.
//
//  ─────────────────────────────────────────────────────────────────────────
//  HEALTH / AD FIREWALL (App Store Guideline 5.1.3)
//  This module wires the ad SDK (`AdsManager`) into the app, but never hands it
//  any weight/height/BMI/HealthKit value. `AdsManager` is configured for
//  non-personalized ads internally; the only thing this shell tells it is the
//  binary Pro flag (to suppress ads after purchase). Health data lives only in
//  the SwiftData store and HealthKit, both kept well away from the ad path.
//  The SwiftData store is intentionally NOT iCloud-synced.
//  ─────────────────────────────────────────────────────────────────────────
//

import SwiftUI
import SwiftData
import StoreKit
import CoreSpotlight
import WidgetKit

// MARK: - App Configuration

/// Static, build-wide configuration constants for the app target.
enum AppConfig {

    /// The App Group shared by the app, the widget, and the Control Center
    /// control. The SwiftData store and the widget's lightweight cache both
    /// live here so history is visible to extensions.
    ///
    /// INTEGRATION: this exact identifier must be enabled in the *App Groups*
    /// capability for the app target, the widget extension, and (if present)
    /// the intents extension. It mirrors `BMIWidgetProvider.appGroupID`.
    static let appGroupID = "group.com.jdr.BMI"

    /// The custom URL scheme used by the widget / controls to deep-link into
    /// the app. INTEGRATION: register this scheme under
    /// *Info > URL Types > URL Schemes* for the app target.
    static let urlScheme = "bmicalculator"

    /// `true` when the app is only hosting unit tests. The app then skips its
    /// launch-time StoreKit work (product requests and the transaction
    /// listener), which would otherwise race the tests' StoreKit sessions.
    static let isHostingTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
}

// MARK: - Shared @AppStorage Keys

/// The single source of truth for `@AppStorage` keys shared across modules.
///
/// Onboarding, Settings, and the Calculator all persist a handful of durable
/// preferences (chosen units, the BMI-cutoff standard, whether onboarding is
/// done). Centralizing the raw key strings here prevents drift — a typo in one
/// module would otherwise silently desync the preference from the rest of the app.
enum AppStorageKey {

    /// `Bool` — set once the person finishes (or skips) the onboarding flow.
    /// Drives whether the app launches into `OnboardingView` or `RootView`.
    static let hasOnboarded = "app.hasOnboarded"

    /// `String` — the person's preferred ``UnitSystem`` raw value (metric/imperial).
    static let unitSystem = "app.unitSystem"

    /// `String` — the chosen ``HealthStandard`` raw value (standard/asian).
    static let healthStandard = "app.healthStandard"

    /// `Double` — the last body the person entered, in canonical kilograms, so the
    /// Calculator opens pre-filled with it (seeded from onboarding on day one,
    /// then kept current on each calculation). Absent until first written.
    static let lastWeightKilograms = "app.lastWeightKilograms"

    /// `Double` — the last entered height in canonical meters. Pairs with
    /// ``lastWeightKilograms``.
    static let lastHeightMeters = "app.lastHeightMeters"
}

// MARK: - Deep Link Routing

/// The destinations the app can be deep-linked to from a widget, a Control
/// Center control, an App Shortcut, or an `OpenURLIntent`.
enum AppRoute: Hashable {

    /// Open the Calculator tab ready for a new measurement.
    case newEntry

    /// Open the History tab.
    case history

    /// Open the Pro sheet (e.g. from the locked trend widget).
    case pro
}

/// The app-level sheets `RootView` presents.
enum AppSheet: String, Identifiable {
    case pro
    case earlySupporterThanks

    var id: String { rawValue }
}

extension AppRoute {

    /// Maps an incoming `bmicalculator://…` URL onto a route, or returns `nil`
    /// if the URL is unrecognized. Hosts are matched case-insensitively and the
    /// leading path component is accepted as a fallback (so both
    /// `bmicalculator://new-entry` and `bmicalculator:///new-entry` work).
    init?(url: URL) {
        guard url.scheme?.lowercased() == AppConfig.urlScheme else { return nil }

        // Prefer the host; fall back to the first path component.
        let token = (url.host ?? url.pathComponents.first { $0 != "/" })?
            .lowercased()

        switch token {
        case "new-entry", "newentry", "calculate", "calculator":
            self = .newEntry
        case "history", "trends", "trend":
            self = .history
        case "pro", "upgrade":
            self = .pro
        default:
            return nil
        }
    }
}

/// Observable router shared via the environment. The root `TabView` observes
/// `pendingRoute`/`selectedTab` and reacts; deep-link handlers just push a
/// route here and let SwiftUI do the navigation.
@MainActor
@Observable
final class DeepLinkRouter {

    /// The currently selected tab. Bound by `RootView`'s `TabView`.
    var selectedTab: RootTab = .calculator

    /// A route awaiting handling. Set by the URL/App-Intent handlers; cleared by
    /// `RootView` once it has switched tabs. Modeled as a one-shot signal so the
    /// same route can be requested twice in a row.
    var pendingRoute: AppRoute?

    /// The app-level sheet on screen, if any (bound by `RootView`).
    var presentedSheet: AppSheet?

    /// Requests navigation to `route`. Safe to call from any deep-link source.
    func handle(_ route: AppRoute) {
        pendingRoute = route
    }

    /// Convenience: route from an incoming URL. Returns `true` if it matched.
    @discardableResult
    func handle(url: URL) -> Bool {
        guard let route = AppRoute(url: url) else { return false }
        handle(route)
        return true
    }
}

// MARK: - Protocol Adapters (Service → Calculator contract)

//  The Calculator module declares three small `@MainActor` protocols
//  (`ProState`, `InterstitialPresenting`, `ReviewRequesting`) that it consumes
//  via the environment. The concrete services live in the Services module and
//  don't import the Calculator module, so the composition root supplies the
//  conformances. Keeping them here means the services stay decoupled and the
//  wiring is reviewable in one place.

/// `StoreState` already exposes `adsRemoved`, `hasPro`, `isResolved`, and
/// `hasUpsellOffer`; conforming it to `ProState` lets the Calculator read them
/// without importing the Store module.
extension StoreState: ProState {}

/// `AdsManager.maybeShowInterstitial()` returns a `Bool` (whether an ad was
/// shown); the Calculator's `InterstitialPresenting` is fire-and-forget, so we
/// bridge with a tiny adapter that discards the result.
@MainActor
final class InterstitialAdapter: InterstitialPresenting {

    private let ads: AdsManager

    init(_ ads: AdsManager) { self.ads = ads }

    /// Called only after a completed calculation. `AdsManager` enforces the
    /// frequency cap, cooldown, NPA, and the large close button internally.
    func maybeShowInterstitial() {
        _ = ads.maybeShowInterstitial()
    }
}

/// `ReviewPrompter.maybePrompt(using:)` needs a SwiftUI `RequestReviewAction`,
/// which is only available from the environment inside a `View`. This adapter
/// captures that action so the Calculator can call the no-argument
/// `ReviewRequesting.maybePrompt()` from its view model.
@MainActor
@Observable
final class ReviewRequesterAdapter: ReviewRequesting {

    private let prompter: ReviewPrompter
    private let upsellStore: UpsellStore?
    private var requestReview: RequestReviewAction?

    init(_ prompter: ReviewPrompter, upsellStore: UpsellStore? = nil) {
        self.prompter = prompter
        self.upsellStore = upsellStore
    }

    /// Supplies the live `RequestReviewAction`; call from a view's `.task`/
    /// `.onAppear` where `@Environment(\.requestReview)` is available.
    func bind(requestReview: RequestReviewAction) {
        self.requestReview = requestReview
    }

    /// Forwards the successful-calc count so review eligibility can advance.
    func recordSuccessfulCalc() {
        prompter.recordSuccessfulCalc()
    }

    /// Returns `true` if a prompt was actually presented. No-op + `false` unless
    /// the prompter's heuristics allow a prompt *and* a `RequestReviewAction` has
    /// been bound.
    @discardableResult
    func maybePrompt() -> Bool {
        guard let requestReview else { return false }
        let prompted = prompter.maybePrompt(using: requestReview)
        // Never show an upsell card in the same session as a rating prompt.
        if prompted { upsellStore?.noteReviewPrompted() }
        return prompted
    }
}

/// Bridges the Calculator's `LogRecording` contract to the widget: after a
/// successful calculation, refreshes the shared snapshot so the home-screen
/// widget reflects the latest BMI. Receives no health data (firewall-safe).
@MainActor
final class LogRecorderAdapter: LogRecording {

    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func recordEntry() {
        WidgetSync.update(from: modelContainer)
    }
}

// MARK: - App Services Container

/// Owns the long-lived, app-scoped services and their lifecycle. Held as
/// `@State` on the `App` so it lives exactly as long as the process. Individual
/// services are injected into the environment so feature views can observe them.
@MainActor
@Observable
final class AppServices {

    // Store / IAP
    let storeState: StoreState
    let storeService: StoreService

    // Ads (free tier only)
    let adsManager: AdsManager

    // Platform integrations
    let healthKit: HealthKitService
    let reviewPrompter: ReviewPrompter

    // Upsell bookkeeping (dismissals, the one-time thank-you)
    let upsellStore: UpsellStore

    // The shared SwiftData container (for the launch-time widget snapshot)
    let modelContainer: ModelContainer

    // Calculator-contract adapters
    let interstitialAdapter: InterstitialAdapter
    let reviewRequester: ReviewRequesterAdapter
    let logRecorder: LogRecorderAdapter

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let storeState = StoreState()
        self.storeState = storeState
        self.storeService = StoreService(state: storeState, listensForUpdates: !AppConfig.isHostingTests)

        let adsManager = AdsManager()
        self.adsManager = adsManager

        self.healthKit = HealthKitService()

        let reviewPrompter = ReviewPrompter()
        self.reviewPrompter = reviewPrompter

        let upsellStore = UpsellStore()
        self.upsellStore = upsellStore

        self.interstitialAdapter = InterstitialAdapter(adsManager)
        self.reviewRequester = ReviewRequesterAdapter(reviewPrompter, upsellStore: upsellStore)
        self.logRecorder = LogRecorderAdapter(modelContainer: modelContainer)

        // The cached entitlements (if any) are already applied by StoreService's
        // init; draw the right theme and ad state from them before first render.
        if storeState.isResolved {
            applyEntitlements(storeState.entitlements)
        }
        storeService.onEntitlementsChanged = { [weak self] entitlements in
            self?.applyEntitlements(entitlements)
        }
    }

    /// Reads entitlements, boots the ad SDK only if ads aren't removed, then
    /// loads products. Call once at launch from `.task`.
    func start() async {
        // Unit tests drive StoreKit themselves with a test session.
        guard !AppConfig.isHostingTests else { return }

        // Entitlements first: a local read (no network), and nothing requests an
        // ad until it's done, so a paying customer never sees one.
        await storeService.refreshEntitlements()
        applyEntitlements(storeState.entitlements)

        // Boot ads only when ads aren't removed (the manager also guards this).
        if !storeState.adsRemoved {
            adsManager.start()
        }

        // Mirror the chosen BMI-cutoff standard into the App Group so the
        // Siri/Shortcut intent (which may run headless in the extension process)
        // can read it cross-process.
        if let group = UserDefaults(suiteName: AppConfig.appGroupID) {
            let raw = UserDefaults.standard.string(forKey: AppStorageKey.healthStandard) ?? HealthStandard.standard.rawValue
            group.set(raw, forKey: AppStorageKey.healthStandard)
        }

        // Refresh the widget snapshots once per launch, so the trend widget has
        // the person's history the moment Pro unlocks (people updating from 2.0.x
        // have no trend snapshot until this runs).
        WidgetSync.update(from: modelContainer)

        // Products need the network; nothing above waits on them.
        await storeService.loadProducts()
    }

    /// Applies entitlements everywhere they matter: ads vanish immediately after
    /// a purchase or restore (no relaunch), the theme follows Pro, and the Pro
    /// trend widget re-renders. Reloading a widget while the app is in the
    /// foreground doesn't count against its refresh budget.
    func applyEntitlements(_ entitlements: Entitlements) {
        adsManager.setAdsRemoved(entitlements.adsRemoved)
        AppearanceStore.shared.enforceEntitlement(hasPro: entitlements.pro)
        WidgetCenter.shared.reloadTimelines(ofKind: BMISharedStore.trendWidgetKind)
    }
}

// MARK: - App Entry

@main
struct BMICalculatorApp: App {

    /// The composition root for all app-scoped services.
    @State private var services: AppServices

    /// Routes deep links (URLs / App Intents) to tabs.
    @State private var router = DeepLinkRouter()

    /// First-run gate. When `false`, onboarding is presented before the app.
    @AppStorage(AppStorageKey.hasOnboarded) private var hasOnboarded = false

    /// The shared SwiftData container, placed in the App Group when possible so
    /// the widget can read saved history. Falls back to a local store, then to
    /// an in-memory store, so the app always launches rather than crashing.
    private let modelContainer: ModelContainer

    init() {
        // Build the container first so it can be shared with the services
        // (the widget writer needs it) and the SwiftData model container.
        let container = Self.makeModelContainer()
        self.modelContainer = container
        _services = State(initialValue: AppServices(modelContainer: container))
    }

    var body: some Scene {
        WindowGroup {
            content
                .tint(Theme.brand)                       // the single brand accent
                .environment(services.storeState)
                .environment(services.storeService)
                .environment(services.adsManager)
                .environment(services.healthKit)
                .environment(services.reviewPrompter)
                .environment(services.upsellStore)
                // The concrete review adapter is injected so a view with access
                // to `@Environment(\.requestReview)` (RootView) can bind the
                // live action into it — see `ReviewRequesterAdapter.bind`.
                .environment(services.reviewRequester)
                .environment(router)
                // Bind the Calculator module's environment-key contract so its
                // view model can read Pro status, fire interstitials, ask for
                // reviews, and refresh the widget without importing Services.
                .environment(\.proState, services.storeState)
                .environment(\.interstitialPresenter, services.interstitialAdapter)
                .environment(\.reviewRequester, services.reviewRequester)
                .environment(\.logRecorder, services.logRecorder)
                .task {
                    // Back the Spotlight/Siri "recent BMI results" query with SwiftData.
                    BMIResultStore.configure(with: SpotlightResultProvider(container: modelContainer))
                    await services.start()
                }
                // Deep links from the widget, Control Center control, and App
                // Shortcuts all arrive as `bmicalculator://…` URLs (the control
                // and `OpenBMICalculatorIntent` use `OpenURLIntent`), so a
                // single `onOpenURL` handler covers every launch source.
                .onOpenURL { url in
                    router.handle(url: url)
                }
                // Tapping a donated BMI result in Spotlight launches the app with a
                // CoreSpotlight activity; land on History as a best-effort
                // destination. In-app calculations live there; a headless
                // Siri/Shortcut result is indexed but not yet persisted, so its
                // exact entry won't be present until intent-result persistence
                // lands (a known deferred item). The identifier is the
                // deterministic id from BMIResultEntity.deterministicID.
                .onContinueUserActivity(CSSearchableItemActionType) { activity in
                    if activity.userInfo?[CSSearchableItemActivityIdentifier] != nil {
                        router.handle(.history)
                    }
                }
        }
        .modelContainer(modelContainer)
    }

    // MARK: First-run gate

    @ViewBuilder
    private var content: some View {
        if hasOnboarded {
            RootView()
        } else {
            // `OnboardingView` flips `hasOnboarded` itself; `onFinish` lets us
            // route straight to a fresh calculation once it dismisses.
            OnboardingView(onFinish: { router.handle(.newEntry) })
        }
    }

    // MARK: Model Container Factory

    /// Builds the SwiftData container, degrading gracefully:
    /// 1. App-Group store (shared with the widget) — preferred.
    /// 2. Local on-disk store — if the App Group is unavailable/misconfigured.
    /// 3. In-memory store — last resort so the UI still launches.
    private static func makeModelContainer() -> ModelContainer {
        // The App Group store is only usable when the App Groups capability is
        // actually provisioned. On an unsigned/dev build (or in the test host) it
        // isn't, and SwiftData would TRAP (not throw) — so only attempt it when the
        // container URL resolves, otherwise fall through to a local store.
        if FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroupID) != nil {
            do {
                return try PersistenceController.shared(appGroupID: AppConfig.appGroupID)
            } catch {
                assertionFailure("App Group SwiftData store failed: \(error)")
            }
        }

        do {
            return try PersistenceController.makeContainer()
        } catch {
            assertionFailure("Local SwiftData store failed: \(error)")
        }

        return PersistenceController.inMemory()
    }
}
