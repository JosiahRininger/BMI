//
//  BMICalculatorApp.swift
//  BMICalculator
//
//  The application entry point and composition root. This file owns the things
//  no single feature module should: the SwiftData `ModelContainer` (placed in a
//  shared App Group so the widget can read history), the long-lived services
//  (`StoreState`/`StoreService`, `AdsManager`, `HealthKitService`,
//  `NotificationService`, `ReviewPrompter`), the shared `@AppStorage` key
//  namespace, and the deep-link router that turns `bmicalculator://…` URLs and
//  App-Intent launches into in-app navigation.
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
import UserNotifications

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
}

// MARK: - Shared @AppStorage Keys

/// The single source of truth for `@AppStorage` keys shared across modules.
///
/// Onboarding, Settings, and the Calculator all persist a handful of durable
/// preferences (chosen units, the BMI-cutoff standard, whether onboarding is
/// done, the weekly-reminder toggle). Centralizing the raw key strings here
/// prevents drift — a typo in one module would otherwise silently desync the
/// preference from the rest of the app.
enum AppStorageKey {

    /// `Bool` — set once the person finishes (or skips) the onboarding flow.
    /// Drives whether the app launches into `OnboardingView` or `RootView`.
    static let hasOnboarded = "app.hasOnboarded"

    /// `String` — the person's preferred ``UnitSystem`` raw value (metric/imperial).
    static let unitSystem = "app.unitSystem"

    /// `String` — the chosen ``HealthStandard`` raw value (standard/asian).
    static let healthStandard = "app.healthStandard"

    /// `Bool` — whether the weekly weigh-in reminder is enabled.
    static let weeklyReminderEnabled = "app.weeklyReminderEnabled"
}

// MARK: - Deep Link Routing

/// The destinations the app can be deep-linked to from a widget, a Control
/// Center control, an App Shortcut, or an `OpenURLIntent`.
enum AppRoute: Hashable {

    /// Open the Calculator tab ready for a new measurement.
    case newEntry

    /// Open the History tab.
    case history
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

/// `StoreState` already exposes `isPro`; conforming it to `ProState` lets the
/// Calculator read Pro status without importing the Store module.
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
final class ReviewRequesterAdapter: ReviewRequesting {

    private let prompter: ReviewPrompter
    private var requestReview: RequestReviewAction?

    init(_ prompter: ReviewPrompter) { self.prompter = prompter }

    /// Supplies the live `RequestReviewAction`; call from a view's `.task`/
    /// `.onAppear` where `@Environment(\.requestReview)` is available.
    func bind(requestReview: RequestReviewAction) {
        self.requestReview = requestReview
    }

    /// Forwards the successful-calc count so review eligibility can advance.
    func recordSuccessfulCalc() {
        prompter.recordSuccessfulCalc()
    }

    /// No-op unless the prompter's heuristics allow a prompt *and* a
    /// `RequestReviewAction` has been bound.
    func maybePrompt() {
        guard let requestReview else { return }
        prompter.maybePrompt(using: requestReview)
    }
}

/// Bridges the Calculator's `LogRecording` contract to the retention services:
/// records a streak entry and reschedules the weigh-in reminder so a just-logged
/// person isn't pinged immediately. Receives no health data (firewall-safe).
@MainActor
final class LogRecorderAdapter: LogRecording {

    private let streak: StreakService
    private let notifications: NotificationService

    init(streak: StreakService, notifications: NotificationService) {
        self.streak = streak
        self.notifications = notifications
    }

    func recordEntry() {
        streak.recordEntry()
        Task { await notifications.rescheduleAfterLog() }
    }
}

// MARK: - Notification Delegate

/// Routes notification taps and the "Log now" action into the app via the
/// `bmicalculator://…` deep link carried in the notification's `userInfo`.
/// Snooze is a no-op (the reminder is a repeating trigger, so the next
/// occurrence is already scheduled).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Set by the App to forward to the `DeepLinkRouter`.
    var onDeepLink: (@MainActor (URL) -> Void)?

    /// Show banners while the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard response.actionIdentifier != NotificationService.snoozeActionID else { return }
        let info = response.notification.request.content.userInfo
        if let link = info["link"] as? String, let url = URL(string: link) {
            Task { @MainActor in onDeepLink?(url) }
        }
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
    let notifications: NotificationService
    let reviewPrompter: ReviewPrompter

    // Retention
    let streak: StreakService

    // Calculator-contract adapters
    let interstitialAdapter: InterstitialAdapter
    let reviewRequester: ReviewRequesterAdapter
    let logRecorder: LogRecorderAdapter

    init() {
        let storeState = StoreState()
        self.storeState = storeState
        self.storeService = StoreService(state: storeState)

        let adsManager = AdsManager()
        self.adsManager = adsManager

        self.healthKit = HealthKitService()
        let notifications = NotificationService()
        self.notifications = notifications

        let reviewPrompter = ReviewPrompter()
        self.reviewPrompter = reviewPrompter

        let streak = StreakService()
        self.streak = streak

        self.interstitialAdapter = InterstitialAdapter(adsManager)
        self.reviewRequester = ReviewRequesterAdapter(reviewPrompter)
        self.logRecorder = LogRecorderAdapter(streak: streak, notifications: notifications)
    }

    /// Starts purchase observation, loads the product, syncs entitlements, and
    /// boots the ad SDK on the free tier. Idempotent enough to call once at
    /// launch from `.task`.
    func start() async {
        // Reflect existing entitlement before anything renders an ad surface.
        await storeService.start()
        applyProStateToAds()

        // Boot ads only when not Pro (the manager also guards this internally).
        if !storeState.isPro {
            adsManager.start()
        }

        // Register the "Log now" / "Snooze" actions and refresh the auth snapshot.
        notifications.registerCategories()
        await notifications.refreshStatus()
    }

    /// Pushes the current Pro flag into the ad manager so banners/interstitials
    /// disappear immediately after a purchase or restore.
    func applyProStateToAds() {
        adsManager.setPro(storeState.isPro)
    }
}

// MARK: - App Entry

@main
struct BMICalculatorApp: App {

    /// The composition root for all app-scoped services.
    @State private var services = AppServices()

    /// Routes deep links (URLs / App Intents) to tabs.
    @State private var router = DeepLinkRouter()

    /// Routes notification taps / actions into the app via the deep-link router.
    @State private var notificationDelegate = NotificationDelegate()

    /// First-run gate. When `false`, onboarding is presented before the app.
    @AppStorage(AppStorageKey.hasOnboarded) private var hasOnboarded = false

    /// The shared SwiftData container, placed in the App Group when possible so
    /// the widget can read saved history. Falls back to a local store, then to
    /// an in-memory store, so the app always launches rather than crashing.
    private let modelContainer: ModelContainer = Self.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            content
                .tint(Theme.brand)                       // brand-blue accent app-wide
                .environment(services.storeState)
                .environment(services.storeService)
                .environment(services.adsManager)
                .environment(services.healthKit)
                .environment(services.notifications)
                .environment(services.reviewPrompter)
                .environment(services.streak)
                // The concrete review adapter is injected so a view with access
                // to `@Environment(\.requestReview)` (RootView) can bind the
                // live action into it — see `ReviewRequesterAdapter.bind`.
                .environment(services.reviewRequester)
                .environment(router)
                // Bind the Calculator module's environment-key contract so its
                // view model can read Pro status, fire interstitials, ask for
                // reviews, and record streak/log entries without importing Services.
                .environment(\.proState, services.storeState)
                .environment(\.interstitialPresenter, services.interstitialAdapter)
                .environment(\.reviewRequester, services.reviewRequester)
                .environment(\.logRecorder, services.logRecorder)
                // Keep ads in sync the moment Pro status flips.
                .onChange(of: services.storeState.isPro) { _, _ in
                    services.applyProStateToAds()
                }
                .task {
                    // Route notification taps / "Log now" actions into the app.
                    notificationDelegate.onDeepLink = { url in router.handle(url: url) }
                    UNUserNotificationCenter.current().delegate = notificationDelegate
                    await services.start()
                }
                // Deep links from the widget, Control Center control, and App
                // Shortcuts all arrive as `bmicalculator://…` URLs (the control
                // and `OpenBMICalculatorIntent` use `OpenURLIntent`), so a
                // single `onOpenURL` handler covers every launch source.
                .onOpenURL { url in
                    router.handle(url: url)
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
        do {
            return try PersistenceController.shared(appGroupID: AppConfig.appGroupID)
        } catch {
            assertionFailure("App Group SwiftData store failed: \(error)")
        }

        do {
            return try PersistenceController.makeContainer()
        } catch {
            assertionFailure("Local SwiftData store failed: \(error)")
        }

        return PersistenceController.inMemory()
    }
}
