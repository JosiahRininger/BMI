//
//  CalculatorView.swift
//  BMICalculator
//
//  The Calculator screen. Composes the unit/standard toggles, adaptive
//  weight/height inputs, the Calculate action, and the animated result card.
//
//  Dependency wiring:
//   - SwiftData `modelContext` comes from the environment and is passed into the
//     view model's `calculate(persistingInto:)`.
//   - `StoreState` (Pro state), `AdsManager`, and `ReviewPrompter` are read from
//     the environment by the App and injected into the view model. This file
//     declares the *expected* environment surface via lightweight accessors so
//     the Calculator compiles against the contract.
//
//  HEALTH / AD FIREWALL: the non-personalized banner slot below renders no
//  health values, and no health data crosses into the ad layer.
//

import SwiftUI
import SwiftData

// MARK: - Environment Bridges
//
// The sibling Store/Ads modules install their `@Observable` singletons into the
// environment. The Calculator only needs read access to drive the upsell and to
// host the banner slot. These optional environment values keep the screen
// decoupled: if a collaborator is absent (previews/tests), the screen still
// works and simply hides ads / upsell.

// The collaborator protocols are `@MainActor`-isolated (their concrete
// conformers are main-actor `@Observable` singletons). The `@Entry` macro
// generates environment storage with the correct isolation, avoiding the
// `EnvironmentKey.defaultValue` concurrency pitfalls under Swift 6.

extension EnvironmentValues {
    /// Read-only Pro/purchase state. Injected by the App from `StoreState`.
    @Entry var proState: (any ProState)? = nil

    /// Interstitial coordinator. Injected by the App from `AdsManager`.
    @Entry var interstitialPresenter: (any InterstitialPresenting)? = nil

    /// Review-prompt coordinator. Injected by the App from `ReviewPrompter`.
    @Entry var reviewRequester: (any ReviewRequesting)? = nil

    /// Streak / weigh-in-reminder coordinator. Injected by the App over
    /// `StreakService` + `NotificationService`.
    @Entry var logRecorder: (any LogRecording)? = nil
}

// MARK: - Banner Slot
//
// The actual banner is owned by the Ads module. The Calculator only reserves
// space and conditionally hides it for Pro people. The Ads module is expected to
// provide a `BannerAdView` (a `View`); we reference it through a thin protocol so
// this file compiles standalone, and the App swaps in the concrete view.

/// A placeholder banner that the Ads module replaces with a real (NPA) banner.
/// Renders nothing when the person is Pro.
struct BannerSlot: View {
    let isPro: Bool

    var body: some View {
        if isPro {
            EmptyView()
        } else {
            // The Ads module installs the concrete `BannerAdView` here via the
            // App layer. Until then this reserves the standard banner height so
            // layout does not jump when the real banner loads.
            Color.clear
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .overlay(
                    Text("Advertisement")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                )
                .accessibilityHidden(true)
        }
    }
}

// MARK: - CalculatorView

/// The Calculator screen.
struct CalculatorView: View {

    // MARK: Environment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.proState) private var proState
    @Environment(\.interstitialPresenter) private var interstitialPresenter
    @Environment(\.reviewRequester) private var reviewRequester
    @Environment(\.logRecorder) private var logRecorder

    // MARK: State

    @State private var model: CalculatorViewModel

    /// When Reduce Motion is on, result insertion crossfades rather than springs.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Forwarded to the parent to present the Pro paywall / IAP sheet.
    var onShowPaywall: () -> Void

    // MARK: Init

    /// Creates the screen. The view model is built here with `nil` collaborators
    /// and then has its environment-provided collaborators bound in `.task`,
    /// because environment values are not available at `init` time.
    init(onShowPaywall: @escaping () -> Void = {}) {
        self.onShowPaywall = onShowPaywall
        _model = State(initialValue: CalculatorViewModel())
    }

    /// Test/preview seam: inject a pre-configured view model.
    init(model: CalculatorViewModel, onShowPaywall: @escaping () -> Void = {}) {
        self.onShowPaywall = onShowPaywall
        _model = State(initialValue: model)
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                inputsSection
                calculateButton

                if let result = model.result {
                    ResultCard(
                        result: result,
                        showsUpsell: model.showsUpsell,
                        onUpsellTapped: onShowPaywall
                    )
                    .id(model.resultGeneration) // identity per real calc, not per re-categorize
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            // Constrain primary content on iPad / large widths so the form
            // isn't stretched edge-to-edge; centered within the scroll view.
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85),
                       value: model.result)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(backgroundGradient)
        .safeAreaInset(edge: .bottom) {
            BannerSlot(isPro: model.isPro)
        }
        .navigationTitle("BMI Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            bindCollaborators()
        }
    }

    // MARK: Inputs

    private var inputsSection: some View {
        VStack(spacing: 16) {
            UnitSystemToggle(unitSystem: $model.unitSystem)

            WeightField(
                value: $model.weight,
                range: model.weightRange,
                unitLabel: model.unitSystem.weightUnitLabel
            )

            AdaptiveHeightField(
                unitSystem: model.unitSystem,
                centimeters: $model.heightCentimeters,
                imperialHeight: $model.imperialHeight,
                centimetersRange: model.heightCentimetersRange,
                feetRange: model.feetRange,
                inchesRange: model.inchesRange
            )

            HealthStandardToggle(standard: $model.standard)
        }
    }

    // MARK: Calculate

    private var calculateButton: some View {
        Button {
            model.calculate(persistingInto: modelContext)
        } label: {
            Text("Calculate")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .calcPrimaryButtonStyle()
        .accessibilityHint("Calculates your BMI from the entered weight and height.")
    }

    // MARK: Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                CalcPalette.brandBlue.opacity(0.10),
                Color.clear
            ],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
    }

    // MARK: Collaborator Binding

    /// Binds the environment-provided Store/Ads/Review singletons into the view
    /// model. Runs in `.task` because the environment is unavailable at `init`.
    @MainActor
    private func bindCollaborators() {
        model.lateBind(
            store: proState,
            ads: interstitialPresenter,
            reviewPrompter: reviewRequester,
            logRecorder: logRecorder
        )
    }
}

// MARK: - Primary Button Style

private struct CalcPrimaryButton: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(CalcPalette.brandBlue)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(CalcPalette.brandBlue)
                .controlSize(.large)
        }
    }
}

private extension View {
    /// The Calculator's primary call-to-action button styling: Liquid Glass
    /// prominent on iOS 26, bordered-prominent fallback below.
    func calcPrimaryButtonStyle() -> some View { modifier(CalcPrimaryButton()) }
}

// MARK: - Previews

#Preview("Default") {
    NavigationStack {
        CalculatorView()
    }
    .modelContainer(for: BMIRecord.self, inMemory: true)
}

#Preview("With result, non-Pro") {
    let vm = CalculatorViewModel()
    vm.calculate(persistingInto: nil)
    return NavigationStack {
        CalculatorView(model: vm)
    }
    .modelContainer(for: BMIRecord.self, inMemory: true)
}
