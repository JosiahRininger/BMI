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
import StoreKit

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

    /// `Bool` — whether the weekly weigh-in reminder is enabled (onboarding's simple opt-in).
    static let weeklyReminderEnabled = "app.weeklyReminderEnabled"

    /// `String` — the chosen ``NotificationService/ReminderCadence`` raw value (Settings).
    static let reminderCadence = "app.reminderCadence"

    /// `String` — the chosen ``AppTheme`` raw value (BMI Pro accent palette).
    static let appTheme = "app.appTheme"
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
@Observable
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

    /// Returns `true` if a prompt was actually presented. No-op + `false` unless
    /// the prompter's heuristics allow a prompt *and* a `RequestReviewAction` has
    /// been bound.
    @discardableResult
    func maybePrompt() -> Bool {
        guard let requestReview else { return false }
        return prompter.maybePrompt(using: requestReview)
    }
}

/// Bridges the Calculator's `LogRecording` contract to the retention services:
/// records a streak entry and reschedules the weigh-in reminder so a just-logged
/// person isn't pinged immediately. Receives no health data (firewall-safe).
@MainActor
final class LogRecorderAdapter: LogRecording {

    private let streak: StreakService
    private let notifications: NotificationService
    private let modelContainer: ModelContainer

    init(streak: StreakService, notifications: NotificationService, modelContainer: ModelContainer) {
        self.streak = streak
        self.notifications = notifications
        self.modelContainer = modelContainer
    }

    func recordEntry() {
        streak.recordEntry()
        // Publish the latest history to the App Group + refresh the widget.
        WidgetSync.update(from: modelContainer)
        Task { await notifications.rescheduleAfterLog() }
    }
}

// MARK: - Notification Delegate

/// Routes notification taps and the "Log now" action into the app via the
/// `bmicalculator://…` deep link carried in the notification's `userInfo`.
/// Snooze is a no-op (the reminder is a repeating trigger, so the next
/// occurrence is already scheduled).
@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {

    /// Set by the App to forward to the `DeepLinkRouter`.
    var onDeepLink: ((URL) -> Void)?

    /// Show banners while the app is foregrounded.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard response.actionIdentifier != NotificationService.snoozeActionID else { return }
        let info = response.notification.request.content.userInfo
        if let link = info["link"] as? String, let url = URL(string: link) {
            // Delivered on the main thread; `self` is @MainActor (Sendable), so
            // assumeIsolated reads the @MainActor `onDeepLink` without a hop.
            MainActor.assumeIsolated { onDeepLink?(url) }
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

    // Appearance (Pro accent theme)
    let appearance: AppearanceStore

    // Profiles (Pro multi-person tracking)
    let profiles: ProfileStore

    // Calculator-contract adapters
    let interstitialAdapter: InterstitialAdapter
    let reviewRequester: ReviewRequesterAdapter
    let logRecorder: LogRecorderAdapter

    init(modelContainer: ModelContainer) {
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

        self.appearance = AppearanceStore()

        // Builds profiles + adopts any legacy records into the default profile.
        self.profiles = ProfileStore(container: modelContainer)

        self.interstitialAdapter = InterstitialAdapter(adsManager)
        self.reviewRequester = ReviewRequesterAdapter(reviewPrompter)
        self.logRecorder = LogRecorderAdapter(streak: streak, notifications: notifications, modelContainer: modelContainer)
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

        // A Pro accent theme must not survive a lost entitlement, and the free
        // tier is a single profile — collapse to the default when not Pro.
        appearance.enforceEntitlement(isPro: storeState.isPro)
        profiles.enforceFreeTier(isPro: storeState.isPro)

        // Register the "Log now" / "Snooze" actions and refresh the auth snapshot.
        notifications.registerCategories()
        // Restore the saved reminder cadence so the first post-launch log honors
        // the person's choice instead of the in-memory .weekly default (which
        // would silently downgrade a Daily user or resurrect an Off one).
        let cadenceRaw = UserDefaults.standard.string(forKey: AppStorageKey.reminderCadence)
        notifications.cadence = NotificationService.ReminderCadence(rawValue: cadenceRaw ?? "") ?? .weekly
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
    @State private var services: AppServices

    /// Routes deep links (URLs / App Intents) to tabs.
    @State private var router = DeepLinkRouter()

    /// Routes notification taps / actions into the app via the deep-link router.
    @State private var notificationDelegate = NotificationDelegate()

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
                // Accent follows the chosen Pro theme; reading `appearance.theme`
                // here makes the tint reactive so a theme change recolors at once.
                .tint(services.appearance.theme.accent)
                .environment(services.appearance)
                .environment(services.profiles)
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
                // Keep ads + theme entitlement in sync the moment Pro flips.
                .onChange(of: services.storeState.isPro) { _, isPro in
                    services.applyProStateToAds()
                    services.appearance.enforceEntitlement(isPro: isPro)
                    services.profiles.enforceFreeTier(isPro: isPro)
                }
                .task {
                    // Route notification taps / "Log now" actions into the app.
                    notificationDelegate.onDeepLink = { url in router.handle(url: url) }
                    UNUserNotificationCenter.current().delegate = notificationDelegate
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
