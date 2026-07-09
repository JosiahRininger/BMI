//
//  OnboardingView.swift
//  BMICalculator
//
//  A short, 3-page first-run flow whose single job is to deliver the "aha"
//  in session one: the person enters their height and weight, immediately
//  sees a real BMI result with its category band and a first chart point,
//  and is then offered (optionally) to connect Apple Health and enable a
//  gentle weekly check-in reminder.
//
//  Person-first, non-judgmental language is used throughout. No health value
//  ever touches the ad SDK (see HEALTH/AD FIREWALL in the project rules); this
//  screen only reads/writes the local engine and the Services layer.
//

import SwiftUI
import SwiftData

// MARK: - Onboarding Flow

/// Three-page onboarding presented full-screen on first launch.
///
/// The flow persists a `hasOnboarded` flag (via `@AppStorage`) so it is shown
/// exactly once. Completing the flow also writes the person's first
/// ``BMIRecord`` so the History/Trends screen has an anchor point on day one.
struct OnboardingView: View {

    // MARK: Persistence / Environment

    /// Set once the person finishes (or skips) onboarding. The root view reads
    /// this to decide whether to present onboarding.
    @AppStorage(AppStorageKey.hasOnboarded) private var hasOnboarded: Bool = false

    /// Default unit system, shared with the rest of the app. Seeded from the
    /// device locale on first run by ``onboardingDefaultUnitSystem``.
    @AppStorage(AppStorageKey.unitSystem) private var storedUnitSystemRaw: String = onboardingDefaultUnitSystem.rawValue

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Optional Services injected from the app root. Marked optional so this
    /// view still compiles and previews even before the Services module lands.
    @Environment(HealthKitService.self) private var healthKit

    // MARK: Local State

    @State private var page: Page = .input
    @State private var input = OnboardingInput()
    @State private var result: BMIResult?

    /// Completion callback invoked by the host (defaults to dismiss). Lets the
    /// app root react, e.g. route straight to the main calculator.
    var onFinish: () -> Void = {}

    private enum Page: Int, CaseIterable {
        case input, result, connect
    }

    private var unitSystem: UnitSystem {
        UnitSystem(rawValue: storedUnitSystemRaw) ?? .metric
    }

    /// Page-transition animation, suppressed when Reduce Motion is on so the
    /// large horizontal slide becomes an instant (crossfade-style) change.
    private var pageAnimation: Animation? {
        reduceMotion ? nil : .snappy
    }

    // MARK: Body

    var body: some View {
        ZStack {
            DSColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                TabView(selection: $page) {
                    inputPage.tag(Page.input)
                    resultPage.tag(Page.result)
                    connectPage.tag(Page.connect)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(pageAnimation, value: page)
                // Reaching the result page by swipe (not just the button) must
                // still compute the result, or it shows an endless spinner.
                .onChange(of: page) { _, newPage in
                    if newPage == .result { ensureResultComputed() }
                }

                pageControl
                    .padding(.vertical, DSSpacing.md)
            }
            .padding(.horizontal, DSSpacing.lg)
            // Keep the flow comfortably readable on iPad / large widths instead
            // of stretching the content edge-to-edge.
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .interactiveDismissDisabled()
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text("BMI Calculator")
                .font(DSFont.title2)
                .foregroundStyle(DSColor.brand)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button("Skip") {
                finish(persistRecord: false)
            }
            .font(DSFont.body)
            .foregroundStyle(DSColor.secondaryText)
            .frame(minWidth: 44, minHeight: 44)
            .opacity(page == .connect ? 0 : 1)
            .disabled(page == .connect)
            .accessibilityHidden(page == .connect)
            .accessibilityLabel("Skip onboarding")
            .accessibilityHint("Skips setup and goes straight to the calculator")
        }
        .padding(.top, DSSpacing.lg)
        .padding(.bottom, DSSpacing.sm)
    }

    // MARK: Page 1 — Input

    private var inputPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                OnboardingHeadline(
                    title: "Let's find your number",
                    subtitle: "Enter your height and weight. Everything stays on your device."
                )

                unitPicker

                MeasurementEntry(input: $input, unitSystem: unitSystem)

                Spacer(minLength: DSSpacing.xl)

                PrimaryGlassButton(title: "See my result", systemImage: "arrow.right") {
                    computeResult()
                }
                .disabled(!input.isComplete(for: unitSystem))
            }
            .padding(.vertical, DSSpacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var unitPicker: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text("Units")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.secondaryText)

            Picker("Units", selection: Binding(
                get: { unitSystem },
                set: { storedUnitSystemRaw = $0.rawValue }
            )) {
                Text("Metric (kg, cm)").tag(UnitSystem.metric)
                Text("Imperial (lb, ft)").tag(UnitSystem.imperial)
                // Stone is offered in Settings + the Calculator (which have real
                // stone weight entry); onboarding keeps metric/imperial to avoid
                // showing pounds fields for a stone selection.
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Measurement units")
        }
    }

    // MARK: Page 2 — Result

    @ViewBuilder
    private var resultPage: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                OnboardingHeadline(
                    title: "Here's your result",
                    subtitle: "This is a screening number, not a diagnosis."
                )

                if let result {
                    ResultHeroCard(result: result)
                    FirstChartPoint(result: result)
                    DisclaimerNote()
                } else {
                    // Should not happen — we only advance after computing.
                    ProgressView().padding(DSSpacing.xl)
                }

                Spacer(minLength: DSSpacing.lg)

                PrimaryGlassButton(title: "Continue", systemImage: "arrow.right") {
                    withAnimation(pageAnimation) { page = .connect }
                }
            }
            .padding(.vertical, DSSpacing.lg)
        }
    }

    // MARK: Page 3 — Connect

    private var connectPage: some View {
        ScrollView {
            VStack(spacing: DSSpacing.lg) {
                OnboardingHeadline(
                    title: "Stay on track",
                    subtitle: "Optional. You can change these any time in Settings."
                )

                ConnectHealthRow(healthKit: healthKit, input: input, unitSystem: unitSystem)

                Spacer(minLength: DSSpacing.xl)

                PrimaryGlassButton(title: "Get started", systemImage: "checkmark") {
                    finish(persistRecord: true)
                }

                Text("BMI is a screening tool, not medical advice.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, DSSpacing.lg)
        }
    }

    // MARK: Page Control

    private var pageControl: some View {
        HStack(spacing: DSSpacing.sm) {
            ForEach(Page.allCases, id: \.rawValue) { p in
                Capsule()
                    .fill(p == page ? DSColor.brand : DSColor.secondaryText.opacity(0.25))
                    .frame(width: p == page ? 22 : 8, height: 8)
                    .animation(pageAnimation, value: page)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Actions

    /// Computes the BMI from the current input and advances to the result page.
    private func computeResult() {
        ensureResultComputed()
        withAnimation(pageAnimation) { page = .result }
    }

    /// Computes (or recomputes) the result from the current inputs. Idempotent and
    /// safe to call on every entry to the result page, so reaching it by SWIPE —
    /// not just the "See my result" button — still shows a result instead of an
    /// endless spinner.
    private func ensureResultComputed() {
        guard let metric = input.metricValues(for: unitSystem) else { return }
        let standard = HealthStandard(
            rawValue: UserDefaults.standard.string(forKey: AppStorageKey.healthStandard) ?? HealthStandard.standard.rawValue
        ) ?? .standard

        result = BMICalculator.result(
            weightKilograms: metric.weightKilograms,
            heightMeters: metric.heightMeters,
            standard: standard
        )
    }

    /// Persists the `hasOnboarded` flag, optionally writes the first record,
    /// and hands control back to the host.
    private func finish(persistRecord: Bool) {
        // Save the first record even if the user swiped past the result page
        // without tapping "See my result" (so `result` is still nil). The engine
        // is non-failing, so compute it on the fly from the validated inputs —
        // an empty day-one History defeats the whole onboarding.
        if persistRecord, let metric = input.metricValues(for: unitSystem) {
            let standard = HealthStandard(
                rawValue: UserDefaults.standard.string(forKey: AppStorageKey.healthStandard)
                    ?? HealthStandard.standard.rawValue
            ) ?? .standard
            let computed = result ?? BMICalculator.result(
                weightKilograms: metric.weightKilograms,
                heightMeters: metric.heightMeters,
                standard: standard
            )
            let record = BMIRecord(
                date: .now,
                bmi: computed.value,
                weightKilograms: metric.weightKilograms,
                heightMeters: metric.heightMeters,
                unitSystemRaw: unitSystem.rawValue
            )
            modelContext.insert(record)
            try? modelContext.save()
        }

        hasOnboarded = true
        onFinish()
        dismiss()
    }
}

// MARK: - Onboarding Input Model

/// Holds the raw text-field values during onboarding and converts them to the
/// canonical metric values the engine expects.
struct OnboardingInput {
    // Metric
    var heightCentimeters: Double = 170
    var weightKilograms: Double = 70

    // Imperial
    var heightFeet: Int = 5
    var heightInches: Double = 7
    var weightPounds: Double = 154

    /// Returns true once the values for the active unit system are usable.
    func isComplete(for unitSystem: UnitSystem) -> Bool {
        metricValues(for: unitSystem) != nil
    }

    /// Converts the active-unit input into metric (kg, m). Returns nil if the
    /// values are non-positive / nonsensical.
    func metricValues(for unitSystem: UnitSystem) -> (weightKilograms: Double, heightMeters: Double)? {
        switch unitSystem {
        case .metric:
            let meters = heightCentimeters / 100.0
            guard weightKilograms > 0, meters > 0 else { return nil }
            return (weightKilograms, meters)
        case .imperial, .stone:
            // Onboarding never selects stone (its default is metric/imperial only);
            // grouped here for exhaustiveness, using the imperial entry fields.
            let meters = BMICalculator.meters(fromFeet: heightFeet, inches: heightInches)
            let kg = BMICalculator.kilograms(fromPounds: weightPounds)
            guard kg > 0, meters > 0 else { return nil }
            return (kg, meters)
        }
    }
}

/// Locale-aware default unit system used to seed onboarding. US/UK/etc. default
/// to imperial; the rest of the world defaults to metric.
var onboardingDefaultUnitSystem: UnitSystem {
    let imperialRegions: Set<String> = ["US", "LR", "MM"]
    let region = Locale.current.region?.identifier ?? ""
    return imperialRegions.contains(region) ? .imperial : .metric
}

// MARK: - Measurement Entry

/// Stepper/field block for entering height and weight in the active units.
private struct MeasurementEntry: View {
    @Binding var input: OnboardingInput
    let unitSystem: UnitSystem

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            switch unitSystem {
            case .metric:
                LabeledValueStepper(
                    title: "Height",
                    value: $input.heightCentimeters,
                    range: 80...250,
                    step: 1,
                    unit: "cm"
                )
                LabeledValueStepper(
                    title: "Weight",
                    value: $input.weightKilograms,
                    range: 20...400,
                    step: 0.5,
                    unit: "kg"
                )
            case .imperial, .stone:
                FeetInchesStepper(feet: $input.heightFeet, inches: $input.heightInches)
                LabeledValueStepper(
                    title: "Weight",
                    value: $input.weightPounds,
                    range: 44...880,
                    step: 1,
                    unit: "lb"
                )
            }
        }
    }
}

/// A titled row with a large value readout and minus/plus controls.
private struct LabeledValueStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String

    var body: some View {
        DSCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.secondaryText)
                    Text("\(formatted) \(unit)")
                        .font(DSFont.title3.monospacedDigit())
                        .foregroundStyle(DSColor.primaryText)
                }
                Spacer()
                StepperButtons(value: $value, range: range, step: step)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(formatted) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private var formatted: String {
        step < 1 ? String(format: "%.1f", value) : String(format: "%.0f", value)
    }
}

/// Height entry for imperial: feet picker + inches stepper.
private struct FeetInchesStepper: View {
    @Binding var feet: Int
    @Binding var inches: Double

    var body: some View {
        DSCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Height")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.secondaryText)
                    Text("\(feet) ft \(String(format: "%.0f", inches)) in")
                        .font(DSFont.title3.monospacedDigit())
                        .foregroundStyle(DSColor.primaryText)
                }
                // Combine only the read-out text; leave the Picker and the
                // inch steppers as individually operable VoiceOver elements.
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Height")
                .accessibilityValue("\(feet) feet \(String(format: "%.0f", inches)) inches")
                Spacer()
                HStack(spacing: DSSpacing.sm) {
                    Picker("Feet", selection: $feet) {
                        ForEach(2...8, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(DSColor.brand)
                    .accessibilityLabel("Height in feet")

                    StepperButtons(
                        value: $inches,
                        range: 0...11,
                        step: 1,
                        wrap: true
                    )
                    .accessibilityLabel("Inches")
                    .accessibilityValue("\(String(format: "%.0f", inches)) inches")
                }
            }
        }
    }
}

/// Reusable minus/plus pair used by the steppers above.
private struct StepperButtons: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    var wrap: Bool = false

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            roundButton(systemImage: "minus") {
                if wrap && value - step < range.lowerBound {
                    value = range.upperBound
                } else {
                    value = max(range.lowerBound, value - step)
                }
            }
            roundButton(systemImage: "plus") {
                if wrap && value + step > range.upperBound {
                    value = range.lowerBound
                } else {
                    value = min(range.upperBound, value + step)
                }
            }
        }
    }

    private func roundButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.dsCircularGlass)
        // Ensure at least a 44x44pt hit target while keeping the 40pt glass visual.
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(systemImage == "plus" ? "Increase" : "Decrease")
    }
}

// MARK: - Result Presentation

/// Large category card shown on the result page (and reused conceptually by the
/// main result screen). Color comes from the DesignSystem band palette.
private struct ResultHeroCard: View {
    let result: BMIResult

    var body: some View {
        DSCard {
            VStack(spacing: DSSpacing.sm) {
                Text(String(format: "%.1f", result.rounded))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(DSColor.category(result.category))
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.5)
                    // Let the hero number grow with Dynamic Type but cap it so it
                    // can't run away and clip the rest of the card at AX5.
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                    .accessibilityHidden(true)

                // Category conveyed via text (and the band color), so it is never
                // color-alone for color-blind readers.
                Text(result.category.title)
                    .font(DSFont.title3)
                    .foregroundStyle(DSColor.primaryText)
                    .multilineTextAlignment(.center)

                Text(result.category.displayRange)
                    .font(DSFont.subheadline.monospacedDigit())
                    .foregroundStyle(DSColor.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSSpacing.md)
        }
        .overlay(
            RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous)
                .strokeBorder(DSColor.category(result.category).opacity(0.4), lineWidth: 1)
        )
        // Speak a single concise summary, e.g. "BMI 24.1, Healthy weight,
        // range 18.5 – < 25", instead of three separate fragments.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BMI \(String(format: "%.1f", result.rounded)), \(result.category.title)")
        .accessibilityValue("Range \(result.category.displayRange)")
    }
}

/// A tiny "your first data point" teaser so the chart on Trends doesn't feel
/// empty the first time it's opened.
private struct FirstChartPoint: View {
    let result: BMIResult

    var body: some View {
        DSCard {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(DSColor.brand)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your first data point")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.primaryText)
                    Text("Saved to your private history so you can watch your trend over time.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.secondaryText)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Connect Rows

/// "Connect Apple Health" row. Requests read/write authorization and, on
/// success, writes the body-mass sample captured during onboarding.
private struct ConnectHealthRow: View {
    let healthKit: HealthKitService
    let input: OnboardingInput
    let unitSystem: UnitSystem

    @State private var state: ConnectState = .idle

    private enum ConnectState: Equatable { case idle, working, connected, failed }

    var body: some View {
        DSCard {
            HStack(spacing: DSSpacing.md) {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                    .frame(width: 32)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect Apple Health")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.primaryText)
                    Text(subtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.secondaryText)
                        // Reserve two lines so the card height stays constant as the
                        // subtitle switches between states (a source of the jolt);
                        // scale slightly rather than truncate on narrow widths.
                        .lineLimit(2, reservesSpace: true)
                        .minimumScaleFactor(0.85)
                }
                Spacer()

                // Fixed-size slot so swapping Connect button → spinner → checkmark
                // never resizes the row.
                connectControl
                    .frame(minWidth: 92, minHeight: 36, alignment: .trailing)
            }
        }
        // Ease the state change instead of snapping the layout.
        .animation(.smooth(duration: 0.25), value: state)
    }

    private var subtitle: String {
        switch state {
        case .connected: return "Connected. Your weight will sync privately."
        case .failed: return "Couldn't connect. You can try again in Settings."
        default: return "Sync your weight so you don't have to type it each time."
        }
    }

    @ViewBuilder
    private var connectControl: some View {
        switch state {
        case .idle, .failed:
            Button("Connect") { connect() }
                .buttonStyle(.dsCompactGlass)
                .accessibilityLabel("Connect Apple Health")
                .accessibilityHint("Syncs your weight privately so you don't have to type it each time")
        case .working:
            ProgressView()
                .accessibilityLabel("Connecting to Apple Health")
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(DSColor.category(.healthy))
                .accessibilityLabel("Connected")
        }
    }

    private func connect() {
        state = .working
        Task {
            try? await healthKit.requestAuthorization()
            // HealthKit doesn't reliably report read-grant; treat a completed
            // request as connected (prefill simply no-ops if the user declined).
            state = healthKit.hasRequestedAuthorization ? .connected : .failed
        }
    }
}

// MARK: - Shared Small Components

/// Page headline + supporting copy block.
private struct OnboardingHeadline: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(title)
                .font(DSFont.largeTitle)
                .foregroundStyle(DSColor.primaryText)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(DSFont.body)
                .foregroundStyle(DSColor.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The short disclaimer surfaced near the first result. The full disclaimer
/// lives in Settings; this is the abbreviated reminder.
private struct DisclaimerNote: View {
    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(DSColor.secondaryText)
                .accessibilityHidden(true)
            Text("BMI is a screening tool, not a diagnosis. It can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider.")
                .font(DSFont.caption)
                .foregroundStyle(DSColor.secondaryText)
        }
        .padding(DSSpacing.md)
        .background(DSColor.secondaryBackground, in: RoundedRectangle(cornerRadius: DSRadius.card, style: .continuous))
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
        .environment(HealthKitService())
        .modelContainer(PersistenceController.inMemory())
}
