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
//   • It hosts the Pro / "Remove Ads" paywall sheet that the Calculator screen
//     asks to present via its `onShowPaywall` callback.
//

import SwiftUI

// MARK: - Root Tab

/// The selectable tabs. Raw `Int` so the value is trivially `Hashable` and can
/// back a `TabView` selection while staying readable at call sites.
enum RootTab: Int, Hashable, CaseIterable {
    case calculator
    case history
    case metrics
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

    /// Streak service, observed so a newly-earned milestone can be celebrated.
    @Environment(StreakService.self) private var streak

    /// Controls the Pro / Remove-Ads paywall sheet.
    @State private var isPaywallPresented = false

    /// A just-earned milestone awaiting its one-time celebration sheet.
    @State private var milestoneToCelebrate: StreakMilestone?

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {

            // MARK: Calculator
            CalculatorView(onShowPaywall: { isPaywallPresented = true })
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

            // MARK: Metrics (the 6 extra calculators). Wrapped in its own
            // NavigationStack because MoreMetricsView pushes via NavigationLink.
            NavigationStack {
                MoreMetricsView()
            }
            .tabItem {
                Label("Metrics", systemImage: "square.grid.2x2")
            }
            .tag(RootTab.metrics)

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
        }
        .sheet(isPresented: $isPaywallPresented) {
            PaywallSheet()
        }
        // Celebrate a newly-earned streak milestone (fires only on a fresh add,
        // never on initial load — `onChange` doesn't run on first appearance).
        .onChange(of: streak.earnedMilestones) { _, milestones in
            milestoneToCelebrate = milestones.last
        }
        .sheet(item: $milestoneToCelebrate) { milestone in
            MilestoneCelebrationView(milestone: milestone) { milestoneToCelebrate = nil }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Routing

    /// Switches to the tab a deep link targets and consumes the pending route.
    private func apply(_ route: AppRoute, router: DeepLinkRouter) {
        switch route {
        case .newEntry:
            router.selectedTab = .calculator
        case .history:
            router.selectedTab = .history
        }
        router.pendingRoute = nil
    }

    /// The current BMI-cutoff standard, read from shared preferences so History
    /// colors its rows with the same overlay the person picked in Settings.
    private var currentStandard: HealthStandard {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.healthStandard)
        return HealthStandard(rawValue: raw ?? HealthStandard.standard.rawValue) ?? .standard
    }
}

// MARK: - Paywall Sheet

/// A focused "Remove Ads / BMI Pro" sheet for the one-time, non-consumable IAP.
///
/// This is the App-shell's lightweight paywall used when the Calculator surfaces
/// an upsell. The full purchase UI also lives in Settings; both drive the same
/// `StoreService`, so buying here removes ads everywhere immediately. There is
/// no subscription — a single non-consumable unlock.
private struct PaywallSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreState.self) private var storeState
    @Environment(StoreService.self) private var storeService

    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                header

                featureList

                Spacer(minLength: 0)

                actions

                disclaimer
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundFill.ignoresSafeArea())
            .navigationTitle("BMI Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert(
                "Purchase issue",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            // Once Pro is owned, there's nothing left to sell — close the sheet.
            .onChange(of: storeState.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)

            Text("Remove Ads")
                .font(.title.bold())

            Text("A one-time purchase. No subscription, ever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow("rectangle.slash", "No banner ads")
            featureRow("hand.tap", "No post-calculation ads")
            featureRow("heart.text.square", "Support ongoing updates")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(Theme.brand)
                .frame(width: 28)
            Text(text)
                .font(.body)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 12) {
            buyButton
                .disabled(storeState.isProcessing)

            Button("Restore Purchases") { restore() }
                .font(.subheadline)
                .disabled(storeState.isProcessing)

            if storeState.isProcessing {
                ProgressView()
                    .padding(.top, 2)
            }
        }
    }

    /// The primary purchase button. Forks on iOS 26 to use the Liquid Glass
    /// prominent style, falling back to a brand-prominent bordered button on
    /// iOS 18–25. Forking the modifier (rather than erasing the style type)
    /// keeps the real press state intact.
    @ViewBuilder
    private var buyButton: some View {
        let button = Button {
            purchase()
        } label: {
            Text(buyButtonTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }

        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
        }
    }

    private var disclaimer: some View {
        // Single source of truth for the mandated wording (defined in Settings).
        Text(Disclaimer.full)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    // MARK: Derived

    private var buyButtonTitle: String {
        if storeState.isProcessing { return "Purchasing…" }
        if let price = storeState.displayPrice { return "Remove Ads (\(price))" }
        return "Remove Ads"
    }

    /// Subtle glass/material backdrop behind the sheet content.
    @ViewBuilder
    private var backgroundFill: some View {
        if #available(iOS 26.0, *) {
            Rectangle().fill(.clear)
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }

    // MARK: Actions

    private func purchase() {
        Task {
            let succeeded = await storeService.purchase()
            if !succeeded, let message = storeState.lastErrorMessage {
                errorMessage = message
            }
        }
    }

    private func restore() {
        Task {
            let restored = await storeService.restore()
            if !restored {
                errorMessage = storeState.lastErrorMessage
                    ?? "No previous purchase found to restore."
            }
        }
    }
}

// MARK: - Preview

#Preview("Root") {
    let storeState = StoreState()
    RootView()
        .environment(DeepLinkRouter())
        .environment(storeState)
        .environment(StoreService(state: storeState))
        .environment(ReviewRequesterAdapter(ReviewPrompter()))
        .environment(StreakService())
        .modelContainer(for: BMIRecord.self, inMemory: true)
}
