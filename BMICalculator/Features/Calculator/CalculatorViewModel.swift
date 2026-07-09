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
    /// Increment the successful-calc counter that gates eligibility. Must be
    /// called on every successful calc, or `maybePrompt()` can never fire.
    func recordSuccessfulCalc()

    /// Called after a successful calculation. Returns `true` if a review prompt
    /// was actually presented, so the caller can avoid stacking an interstitial
    /// on the same calc. No-op returning `false` unless the heuristics allow it.
    @discardableResult
    func maybePrompt() -> Bool
}

/// Records that the person logged a calculation, so app-level surfaces can react
/// (currently: refreshing the home-screen widget). Implemented by an app-level
/// adapter.
///
/// CONTRACT: receives NO health data — only the fact that a calc happened.
@MainActor
public protocol LogRecording: AnyObject {
    /// Called once per successful calculation.
    func recordEntry()
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
            // Remember the choice so the calculator opens in the last-used units
            // next time (and stays in sync with Settings).
            UserDefaults.standard.set(unitSystem.rawValue, forKey: AppStorageKey.unitSystem)
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

    /// Bumped once per *real* calculation — NOT on a standard-toggle
    /// re-categorize. The view keys the result card's identity on this so a
    /// category-overlay change doesn't tear down and re-animate the whole card.
    public private(set) var resultGeneration: Int = 0

    // MARK: Injected Dependencies
    //
    // Held as `@ObservationIgnored` so changing them never invalidates views,
    // and as `var` so the screen can late-bind environment-provided singletons
    // after `init` (the environment is unavailable at construction time).

    @ObservationIgnored private var store: (any ProState)?
    @ObservationIgnored private var ads: (any InterstitialPresenting)?
    @ObservationIgnored private var reviewPrompter: (any ReviewRequesting)?
    @ObservationIgnored private var logRecorder: (any LogRecording)?

    // MARK: Input Bounds (sane, person-first limits)

    /// Allowed weight range in the active unit. Prevents nonsensical entries and
    /// keeps wheel pickers bounded.
    public var weightRange: ClosedRange<Double> {
        switch unitSystem {
        case .metric:   return 2...400        // kg
        case .imperial: return 4...880        // lb
        case .stone:    return 0.5...63       // st — floor aligned to the 0.5 step
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
    /// The person's saved unit preference (chosen in onboarding, then updated on
    /// every change), so the calculator opens in the units they last used.
    /// `nonisolated` so it can seed the init's default argument; reads only the
    /// thread-safe `UserDefaults`.
    public nonisolated static var savedUnitSystem: UnitSystem {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.unitSystem)
        return UnitSystem(rawValue: raw ?? "") ?? .metric
    }

    /// The saved BMI-cutoff standard (chosen in Settings), so the calculator
    /// categorizes with the person's preference without a per-screen toggle.
    public nonisolated static var savedStandard: HealthStandard {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.healthStandard)
        return HealthStandard(rawValue: raw ?? "") ?? .standard
    }

    public init(
        unitSystem: UnitSystem = CalculatorViewModel.savedUnitSystem,
        standard: HealthStandard = CalculatorViewModel.savedStandard,
        store: (any ProState)? = nil,
        ads: (any InterstitialPresenting)? = nil,
        reviewPrompter: (any ReviewRequesting)? = nil,
        logRecorder: (any LogRecording)? = nil
    ) {
        self.unitSystem = unitSystem
        self.standard = standard
        self.store = store
        self.ads = ads
        self.reviewPrompter = reviewPrompter
        self.logRecorder = logRecorder

        // Default body: 70 kg, 170 cm (≈ 5'7", ≈ 154 lb, ≈ 11 st).
        self.heightCentimeters = 170
        self.imperialHeight = ImperialHeight(feet: 5, inches: 7)
        switch unitSystem {
        case .metric:   self.weight = 70
        case .imperial: self.weight = BMICalculator.pounds(fromKilograms: 70).rounded()
        case .stone:    self.weight = (BMICalculator.pounds(fromKilograms: 70) / BMICalculator.poundsPerStone * 10).rounded() / 10
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
        case .stone:    return BMICalculator.kilograms(fromStone: weight)
        }
    }

    /// The canonical metric height (m) for the current inputs.
    public var heightMeters: Double {
        switch unitSystem {
        case .metric:
            return heightCentimeters / 100.0
        case .imperial, .stone:
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

    /// The healthy weight range for the current height, formatted in the active
    /// unit (e.g. "59–79 kg"), or `nil` before a result exists or for a
    /// non-physical height. Uses the *result's* standard so it stays consistent
    /// with the shown category when the standard is toggled live.
    public var healthyWeightRangeText: String? {
        guard let result else { return nil }
        guard let range = BMICalculator.healthyWeightRangeKilograms(
            heightMeters: heightMeters,
            standard: result.standard
        ) else { return nil }
        return unitSystem.weightRangeString(fromKilograms: range)
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
        resultGeneration += 1

        persistRecord(for: computed, into: context)

        // Retention hooks — firewall-safe, none of these receive a health value:
        // count the calc, refresh the home-screen widget, then maybe prompt for a
        // review and maybe show an interstitial.
        reviewPrompter?.recordSuccessfulCalc()
        logRecorder?.recordEntry()
        // Don't stack two modals on one calc: prefer the rare, rate-limited review
        // prompt; show an interstitial only when no review was presented.
        let reviewed = reviewPrompter?.maybePrompt() ?? false
        if !reviewed { ads?.maybeShowInterstitial() }
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
        reviewPrompter: (any ReviewRequesting)?,
        logRecorder: (any LogRecording)? = nil
    ) {
        if let store { self.store = store }
        if let ads { self.ads = ads }
        if let reviewPrompter { self.reviewPrompter = reviewPrompter }
        if let logRecorder { self.logRecorder = logRecorder }
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
        // Convert weight through a canonical kg intermediary so any pair of
        // systems (metric / imperial / stone) round-trips correctly.
        let kg: Double
        switch old {
        case .metric:   kg = weight
        case .imperial: kg = BMICalculator.kilograms(fromPounds: weight)
        case .stone:    kg = BMICalculator.kilograms(fromStone: weight)
        }
        switch new {
        case .metric:   weight = clampToWeight((kg * 10).rounded() / 10)
        case .imperial: weight = clampToWeight((BMICalculator.pounds(fromKilograms: kg) * 10).rounded() / 10)
        case .stone:    weight = clampToWeight((BMICalculator.pounds(fromKilograms: kg) / BMICalculator.poundsPerStone * 10).rounded() / 10)
        }
        // Height: metric uses centimeters; imperial & stone use feet/inches.
        if !old.usesImperialHeight, new.usesImperialHeight {
            imperialHeight = Self.imperial(fromCentimeters: heightCentimeters)
        } else if old.usesImperialHeight, !new.usesImperialHeight {
            // Clamp into the metric wheel's range so the stored value is always a
            // selectable option (a tall imperial height could convert above 250).
            heightCentimeters = min(max((heightMetersFromImperial() * 100).rounded(),
                                        heightCentimetersRange.lowerBound),
                                   heightCentimetersRange.upperBound)
        }
    }

    /// Clamps a weight (in the active display unit) into the allowed range, so a
    /// unit toggle can't leave the value outside the field's stepper bounds.
    private func clampToWeight(_ value: Double) -> Double {
        min(max(value, weightRange.lowerBound), weightRange.upperBound)
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
