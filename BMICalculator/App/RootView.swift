//
//  RootView.swift
//  BMICalculator
//
//  The post-onboarding shell: a three-tab `TabView` (Calculator / History /
//  Settings) tinted with the brand blue. The tab bar adopts iOS 26's Liquid
//  Glass automatically on a 26 SDK recompile; on iOS 18–25 it renders as the
//  standard system tab bar, so no availability fork is needed here.
//
//  RootView also owns two pieces of app-level navigation glue:
//   • It observes the shared `DeepLinkRouter` and switches tabs when a widget,
//     Control Center control, or App Intent deep-links into the app.
//   • It hosts the app-level sheets: the Pro sheet (from the Calculator's
//     upsells, the banner link, or a `bmicalculator://pro` deep link) and the
//     one-time early supporter thank-you.
//

import SwiftUI
import StoreKit   // RequestReviewAction (the `requestReview` environment value)

// MARK: - Root Tab

/// The selectable tabs. Raw `Int` so the value is trivially `Hashable` and can
/// back a `TabView` selection while staying readable at call sites.
enum RootTab: Int, Hashable, CaseIterable {
    case calculator
    case history
    case settings
}

// MARK: - RootView

/// The app's main tabbed surface, shown once onboarding is complete.
struct RootView: View {

    /// Shared deep-link router (injected by `BMICalculatorApp`).
    @Environment(DeepLinkRouter.self) private var router

    /// Concrete review adapter, bound to the live `RequestReviewAction` below so
    /// the Calculator's `ReviewRequesting.maybePrompt()` can actually present
    /// the App Store review prompt.
    @Environment(ReviewRequesterAdapter.self) private var reviewRequester

    /// SwiftUI's review-prompt action, only available inside a view hierarchy.
    @Environment(\.requestReview) private var requestReview

    /// Purchase state, used for the early supporter thank-you.
    @Environment(StoreState.self) private var storeState

    /// Upsell bookkeeping (the thank-you is shown once).
    @Environment(UpsellStore.self) private var upsellStore

    /// The BMI-cutoff standard chosen in Settings, observed so History re-colors
    /// its rows live when the person changes it (not just on a tab re-render).
    @AppStorage(AppStorageKey.healthStandard) private var standardRaw = HealthStandard.standard.rawValue

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {

            // MARK: Calculator
            CalculatorView(onShowPaywall: { router.presentedSheet = .pro })
                .tabItem {
                    Label("Calculator", systemImage: "function")
                }
                .tag(RootTab.calculator)

            // MARK: History
            HistoryView(standard: currentStandard)
                .tabItem {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
                .tag(RootTab.history)

            // MARK: Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(RootTab.settings)
        }
        .tint(Theme.brand)
        // React to deep links: switch to the matching tab, then clear the
        // one-shot signal so a repeat of the same route still fires.
        .onChange(of: router.pendingRoute) { _, route in
            guard let route else { return }
            apply(route, router: router)
        }
        .onAppear {
            // Hand the live review action to the adapter so review prompts work.
            reviewRequester.bind(requestReview: requestReview)
            // Handle a route that arrived before the view was on screen.
            if let route = router.pendingRoute {
                apply(route, router: router)
            }
            offerEarlySupporterThanksIfNeeded()
        }
        // An early Remove Ads purchase can resolve after launch (StoreKit read,
        // Restore, or a new device), so check again whenever it changes.
        .onChange(of: storeState.isEarlySupporter) { _, _ in
            offerEarlySupporterThanksIfNeeded()
        }
        .sheet(item: $router.presentedSheet) { sheet in
            switch sheet {
            case .pro:
                ProSheet()
            case .earlySupporterThanks:
                EarlySupporterSheet(onAppearOnce: { upsellStore.markEarlySupporterThanked() })
            }
        }
    }

    /// Shows the one-time thank-you to early Remove Ads buyers, never over
    /// another sheet.
    private func offerEarlySupporterThanksIfNeeded() {
        guard router.presentedSheet == nil,
              upsellStore.needsEarlySupporterThanks(storeState.entitlements) else { return }
        router.presentedSheet = .earlySupporterThanks
    }

    // MARK: Routing

    /// Switches to the tab a deep link targets and consumes the pending route.
    private func apply(_ route: AppRoute, router: DeepLinkRouter) {
        switch route {
        case .newEntry:
            router.selectedTab = .calculator
        case .history:
            router.selectedTab = .history
        case .pro:
            router.presentedSheet = .pro
        }
        router.pendingRoute = nil
    }

    /// The current BMI-cutoff standard the person picked in Settings, so History
    /// colors its rows with the same overlay. Backed by `@AppStorage` above, so a
    /// change re-renders RootView and re-passes it to `HistoryView`.
    private var currentStandard: HealthStandard {
        HealthStandard(rawValue: standardRaw) ?? .standard
    }
}

// MARK: - Preview

#Preview("Root") {
    let storeState = StoreState()
    let container = PersistenceController.inMemory()
    let upsell = UpsellStore()
    return RootView()
        .environment(DeepLinkRouter())
        .environment(storeState)
        .environment(StoreService(state: storeState, listensForUpdates: false))
        .environment(upsell)
        .environment(ReviewRequesterAdapter(ReviewPrompter(), upsellStore: upsell))
        .modelContainer(container)
}
