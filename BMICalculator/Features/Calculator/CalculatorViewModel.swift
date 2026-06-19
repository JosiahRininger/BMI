//
//  CalculatorViewModel.swift
//  BMICalculator
//
//  Calculator screen view model. Owns the unit system, the raw weight/height
//  inputs, the chosen health standard, and the most recent BMIResult. It is the
//  single source of truth for the Calculator feature.
//
//  This file imports SwiftUI + SwiftData (it is an App-target type, not a Core
//  type). All numerical work is delegated to the pure `BMICalculator` engine in
//  Core so the math stays testable and widget-shareable.
//
//  HEALTH / AD FIREWALL (App Store Guideline 5.1.3): no weight/height/BMI value
//  is ever passed into the ad layer. `AdsManager.maybeShowInterstitial()` and
//  `ReviewPrompter.maybePrompt()` are called with NO health payload.
//

import Foundation
import Observation
import SwiftData

// MARK: - Dependency Interfaces
//
// These protocols/types are owned by sibling modules (Store, Ads, Persistence).
// They are declared here as the *expected* surface this view model consumes so
// the Calculator feature compiles against a stable contract. The concrete
// conformances live in their own modules and are injected from the environment
// or provided as shared singletons.

/// Read-only purchase state the Calculator needs to decide whether to show the
/// "Remove Ads / Pro" upsell and whether ads may run.
///
/// Implemented by the Store module's `StoreState` (`@Observable`, in the
/// environment). The Calculator only reads `isPro`.
@MainActor
public protocol ProState: AnyObject {
    /// `true` once the one-time non-consumable "Remove Ads / Pro" IAP is owned.
    var isPro: Bool { get }
}

/// Interstitial / banner ad coordinator. Implemented by the Ads module's
/// `AdsManager` singleton.
///
/// CONTRACT: `maybeShowInterstitial()` takes no arguments and receives no
/// health data. The manager itself enforces the cap (~once per 2–3 completed
/// calculations / cooldown), the large obvious close button, and NPA
/// (non-personalized ads) for the firewall.
@MainActor
public protocol InterstitialPresenting: AnyObject {
    /// Called only *after* a calculation completes. No-op when the person is
    /// Pro or when the frequency cap / cooldown has not elapsed.
    func maybeShowInterstitial()
}

/// App Store review prompt coordinator. Implemented by the Store/Review
/// module's `ReviewPrompter` singleton.
///
/// CONTRACT: rate-limited internally (e.g. only after N successful
/// calculations, respecting Apple's annual cap). Receives no health data.
@MainActor
public protocol ReviewRequesting: AnyObject {
    /// Called after a successful calculation. No-op unless the internal
    /// heuristics decide a prompt is appropriate.
    func maybePrompt()
}

// MARK: - Imperial Height Components

/// Imperial height split into whole feet and inches so the UI can bind two
/// independent controls. Kept as a small value type for clean diffing/animation.
public struct ImperialHeight: Equatable, Sendable {
    public var feet: Int
    public var inches: Double

    public init(feet: Int, inches: Double) {
        self.feet = feet
        self.inches = inches
    }
}

// MARK: - CalculatorViewModel

/// Drives the Calculator screen.
///
/// Inputs are stored in the *display* unit the person is currently using
/// (kilograms or pounds; centimeters or feet+inches) and converted to canonical
/// metric (kg, m) only at calculation time via the Core engine. Switching unit
/// systems converts the current values so nothing is silently lost.
@MainActor
@Observable
public final class CalculatorViewModel {

    // MARK: Unit & Standard

    /// The measurement system currently selected. Changing it converts the
    /// existing weight/height values so the displayed body does not change.
    public var unitSystem: UnitSystem {
        didSet {
            guard oldValue != unitSystem else { return }
            convertInputs(from: oldValue, to: unitSystem)
        }
    }

    /// Which cutoff overlay to apply: universal CDC/WHO or the WHO Asian
    /// public-health action points.
    public var standard: HealthStandard {
        didSet {
            guard oldValue != standard else { return }
            // Re-categorize the existing value live so the band updates without
            // forcing a re-tap of "Calculate".
            recomputeCategoryIfNeeded()
        }
    }

    // MARK: Raw Inputs (in the active display unit)

    /// Weight in kilograms when `unitSystem == .metric`, otherwise in pounds.
    public var weight: Double

    /// Height in centimeters when `unitSystem == .metric`. Ignored in imperial.
    public var heightCentimeters: Double

    /// Height in feet + inches when `unitSystem == .imperial`. Ignored in metric.
    public var imperialHeight: ImperialHeight

    // MARK: Output

    /// The most recent computed result, or `nil` before the first calculation.
    public private(set) var result: BMIResult?

    /// Whether the result card should be revealed. Driven separately from
    /// `result` so the view can animate the reveal.
    public private(set) var hasCalculated: Bool = false

    // MARK: Injected Dependencies
    //
    // Held as `@ObservationIgnored` so changing them never invalidates views,
    // and as `var` so the screen can late-bind environment-provided singletons
    // after `init` (the environment is unavailable at construction time).

    @ObservationIgnored private var store: (any ProState)?
    @ObservationIgnored private var ads: (any InterstitialPresenting)?
    @ObservationIgnored private var reviewPrompter: (any ReviewRequesting)?

    // MARK: Input Bounds (sane, person-first limits)

    /// Allowed weight range in the active unit. Prevents nonsensical entries and
    /// keeps wheel pickers bounded.
    public var weightRange: ClosedRange<Double> {
        switch unitSystem {
        case .metric:   return 2...400        // kg
        case .imperial: return 4...880        // lb
        }
    }

    /// Allowed metric height range in centimeters.
    public let heightCentimetersRange: ClosedRange<Double> = 50...250

    /// Allowed imperial feet range.
    public let feetRange: ClosedRange<Int> = 1...8

    /// Allowed imperial inches range (0 up to, but not including, 12).
    public let inchesRange: ClosedRange<Double> = 0...11.5

    // MARK: Init

    /// Creates the view model with sensible default values and optional injected
    /// collaborators.
    ///
    /// Defaults: metric, 70 kg, 170 cm — a neutral mid-range adult so the first
    /// launch shows a believable preview rather than zeros.
    ///
    /// - Parameters:
    ///   - unitSystem: starting unit system.
    ///   - standard: starting health-standard overlay.
    ///   - store: Pro/purchase state (for the upsell and ad gating).
    ///   - ads: interstitial coordinator.
    ///   - reviewPrompter: review-prompt coordinator.
    public init(
        unitSystem: UnitSystem = .metric,
        standard: HealthStandard = .standard,
        store: (any ProState)? = nil,
        ads: (any InterstitialPresenting)? = nil,
        reviewPrompter: (any ReviewRequesting)? = nil
    ) {
        self.unitSystem = unitSystem
        self.standard = standard
        self.store = store
        self.ads = ads
        self.reviewPrompter = reviewPrompter

        // Default body: 70 kg, 170 cm (≈ 5'7", ≈ 154 lb).
        if unitSystem == .metric {
            self.weight = 70
            self.heightCentimeters = 170
            self.imperialHeight = ImperialHeight(feet: 5, inches: 7)
        } else {
            self.weight = BMICalculator.pounds(fromKilograms: 70).rounded()
            self.heightCentimeters = 170
            self.imperialHeight = ImperialHeight(feet: 5, inches: 7)
        }
    }

    // MARK: Derived Display Helpers

    /// `true` when the person has bought Pro; drives whether the upsell shows.
    public var isPro: Bool { store?.isPro ?? false }

    /// Whether the inline "Remove Ads / Pro" upsell should appear on the result
    /// card. Only shown to non-Pro people, and only once a result exists.
    public var showsUpsell: Bool { !isPro && result != nil }

    /// The canonical metric weight (kg) for the current inputs.
    public var weightKilograms: Double {
        switch unitSystem {
        case .metric:   return weight
        case .imperial: return BMICalculator.kilograms(fromPounds: weight)
        }
    }

    /// The canonical metric height (m) for the current inputs.
    public var heightMeters: Double {
        switch unitSystem {
        case .metric:
            return heightCentimeters / 100.0
        case .imperial:
            return BMICalculator.meters(fromFeet: imperialHeight.feet,
                                        inches: imperialHeight.inches)
        }
    }

    /// A live (not-yet-committed) preview of the BMI for the current inputs,
    /// independent of whether "Calculate" has been pressed. Useful for a subtle
    /// gauge preview if a view wants it.
    public var previewBMI: Double {
        BMICalculator.bmi(weightKilograms: weightKilograms,
                          heightMeters: heightMeters)
    }

    // MARK: Actions

    /// Computes the BMI, stores the result, persists a `BMIRecord` into the
    /// supplied SwiftData context, then nudges the review prompt and ad layer.
    ///
    /// The model context is passed in (rather than held) so the view can take it
    /// from `@Environment(\.modelContext)` and this type stays free of any
    /// environment plumbing.
    ///
    /// - Parameter context: the SwiftData context to persist the record into.
    ///   Pass `nil` (e.g. in previews/tests) to skip persistence.
    public func calculate(persistingInto context: ModelContext?) {
        let computed = BMICalculator.result(
            weightKilograms: weightKilograms,
            heightMeters: heightMeters,
            standard: standard
        )

        // `@Observable` auto-tracks these assignments; no manual withMutation.
        result = computed
        hasCalculated = true

        persistRecord(for: computed, into: context)

        // Health firewall: neither of these calls receives any health value.
        reviewPrompter?.maybePrompt()
        ads?.maybeShowInterstitial()
    }

    /// Resets the result (e.g. when a person heavily edits inputs) without
    /// touching the entered values.
    public func clearResult() {
        result = nil
        hasCalculated = false
    }

    /// Late-binds environment-provided collaborators after construction. The
    /// SwiftUI environment is not available at `init`, so `CalculatorView` calls
    /// this from `.task`. Idempotent: only swaps in non-`nil` references, so a
    /// preview/test that passed concrete fakes at `init` is never clobbered by a
    /// later `nil` from an empty environment.
    public func lateBind(
        store: (any ProState)?,
        ads: (any InterstitialPresenting)?,
        reviewPrompter: (any ReviewRequesting)?
    ) {
        if let store { self.store = store }
        if let ads { self.ads = ads }
        if let reviewPrompter { self.reviewPrompter = reviewPrompter }
    }

    // MARK: Persistence

    /// Inserts a `BMIRecord` describing this calculation. Stores canonical metric
    /// values plus the unit the person was using, so history can render in their
    /// preferred unit later.
    private func persistRecord(for result: BMIResult, into context: ModelContext?) {
        guard let context else { return }
        let record = BMIRecord(
            date: Date(),
            bmi: result.value,
            weightKilograms: weightKilograms,
            heightMeters: heightMeters,
            unitSystemRaw: unitSystem.rawValue
        )
        context.insert(record)
        // Best-effort save; SwiftData autosaves on most contexts, but an
        // explicit save surfaces obvious failures during development.
        try? context.save()
    }

    // MARK: Unit Conversion

    /// Converts the stored weight/height when the person flips the unit toggle so
    /// the represented body is unchanged.
    private func convertInputs(from old: UnitSystem, to new: UnitSystem) {
        switch (old, new) {
        case (.metric, .imperial):
            weight = (BMICalculator.pounds(fromKilograms: weight) * 10).rounded() / 10
            imperialHeight = Self.imperial(fromCentimeters: heightCentimeters)
        case (.imperial, .metric):
            weight = (BMICalculator.kilograms(fromPounds: weight) * 10).rounded() / 10
            heightCentimeters = (heightMetersFromImperial() * 100).rounded()
        default:
            break
        }
    }

    /// Current imperial height expressed in meters (helper for conversion).
    private func heightMetersFromImperial() -> Double {
        BMICalculator.meters(fromFeet: imperialHeight.feet, inches: imperialHeight.inches)
    }

    /// Splits a centimeter height into whole feet + inches.
    private static func imperial(fromCentimeters cm: Double) -> ImperialHeight {
        let totalInches = (cm / 100.0) / 0.0254
        let feet = Int(totalInches / 12.0)
        let inches = (totalInches - Double(feet) * 12.0)
        // Round inches to the nearest half for tidy wheel values.
        let roundedInches = (inches * 2).rounded() / 2
        if roundedInches >= 12 {
            return ImperialHeight(feet: feet + 1, inches: 0)
        }
        return ImperialHeight(feet: feet, inches: roundedInches)
    }

    // MARK: Live Re-categorization

    /// When the standard overlay changes, re-derive the category for the existing
    /// BMI value without re-persisting (no new history row for a view toggle).
    private func recomputeCategoryIfNeeded() {
        guard let current = result else { return }
        let category = BMICalculator.category(forBMI: current.value, standard: standard)
        result = BMIResult(
            value: current.value,
            category: category,
            standard: standard,
            rounded: current.rounded
        )
    }
}
