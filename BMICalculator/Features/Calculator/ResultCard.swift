//
//  ResultCard.swift
//  BMICalculator
//
//  The result surface shown after a calculation: a glass card holding the big
//  BMI number, a category gauge, the person-first category title + numeric
//  range, the required screening disclaimer, and a subtle non-intrusive
//  "Remove Ads / Pro" upsell for people who have not purchased.
//
//  Copy is person-first and non-judgmental throughout ("a person with
//  obesity", never "you are obese").
//

import SwiftUI

// MARK: - Category Copy
//
// The brand band color (`BMICategory.bandColor`) lives in the DesignSystem
// (`Theme.swift`) and is appearance-aware; this file reuses it. Only the
// person-first supportive copy is defined here.

extension BMICategory {

    /// An SF Symbol that distinguishes the band by shape (not color alone), so
    /// the category reads for color-blind people.
    var symbolName: String {
        switch self {
        case .underweight:
            return "arrow.down.circle.fill"
        case .healthy:
            return "checkmark.circle.fill"
        case .overweight:
            return "arrow.up.circle.fill"
        case .obesityI, .obesityII, .obesityIII:
            return "exclamationmark.circle.fill"
        }
    }

    /// A short, supportive one-liner describing the band in person-first terms.
    /// Intentionally avoids second-person blame.
    var supportiveNote: String {
        switch self {
        case .underweight:
            return "This range can mean a person is below a typical healthy weight."
        case .healthy:
            return "This range is considered a healthy weight for many adults."
        case .overweight:
            return "This range sits above the typical healthy band for many adults."
        case .obesityI, .obesityII, .obesityIII:
            return "This range is associated with higher health risk for many adults."
        }
    }
}

// MARK: - Disclaimer Copy

/// Shared screening disclaimer surfaced near every result (and in Settings).
enum BMIDisclaimer {
    static let text =
    "BMI is a screening tool for informational purposes only, not a diagnosis or a substitute for professional medical advice. It doesn't directly measure body fat and can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider."
}

// MARK: - Gauge Scale Mapping

extension HealthStandard {
    /// The canonical DesignSystem gauge scale for this standard.
    var gaugeScale: BMIGaugeScale {
        switch self {
        case .standard: return .standard
        case .asian:    return .asian
        }
    }
}

// MARK: - ResultCard

/// The post-calculation summary card.
struct ResultCard: View {
    let result: BMIResult

    /// The healthy weight range for the person's height, already formatted in
    /// their unit (e.g. "59–79 kg"). `nil` hides the readout. Supplied by the
    /// view model, which owns the height + unit context the engine value lacks.
    var healthyWeightRange: String? = nil

    /// Whether to show the inline Pro upsell (non-Pro people only).
    let showsUpsell: Bool

    /// Invoked when the person taps the upsell. The parent presents the IAP /
    /// paywall — this view never touches StoreKit directly.
    var onUpsellTapped: () -> Void = {}

    /// When Reduce Motion is on, the card crossfades in instead of sliding up.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            BMIGauge(
                bmi: result.value,
                category: result.category,
                scale: result.standard.gaugeScale,
                showsCenterLabel: false
            )
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            categoryBlock
            if showsMuscleNote {
                muscleMassNote
            }
            if let healthyWeightRange {
                healthyRangeRow(healthyWeightRange)
            }
            disclaimer
            if showsUpsell {
                upsell
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calcGlassCard()
        .transition(reduceMotion
            ? .opacity
            : .move(edge: .bottom).combined(with: .opacity))
        // The card speaks a single concise summary so VoiceOver conveys the
        // verdict without the person hunting through child elements.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: resultSummary))
    }

    /// Concise spoken summary of the whole result, e.g.
    /// "BMI 24.1, Healthy weight, range 18.5 – < 25. Healthy weight for your
    /// height, 59 to 79 kg".
    private var resultSummary: String {
        var summary = String(format: "BMI %.1f, %@, range %@",
                             result.rounded,
                             result.category.title,
                             result.category.displayRange)
        if let healthyWeightRange {
            summary += ". Healthy weight for your height, "
                + healthyWeightRange.replacingOccurrences(of: "–", with: " to ")
        }
        return summary
    }

    // MARK: Header — big number

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(result.rounded, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(result.category.bandColor)
                // Fixed-size hero number: let it scale with Dynamic Type up to a
                // sensible cap, and shrink-to-fit rather than clip at AX5.
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .snappy, value: result.rounded)

            Text("BMI")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: String(format: "BMI %.1f", result.rounded)))
    }

    // MARK: Category title + range + supportive note

    private var categoryBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // SF Symbol (shape, not just color) so the band reads for
                // color-blind people.
                Image(systemName: result.category.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(result.category.bandColor)
                    .accessibilityHidden(true)
                Text(result.category.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(result.category.displayRange)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(result.category.supportiveNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Muscle-mass caveat

    /// Whether to surface the muscle-mass caveat. Only shown at or above
    /// "overweight", where a lean, muscular person is most likely to be
    /// mislabeled by BMI (muscle is dense, so it drives the number up).
    private var showsMuscleNote: Bool {
        switch result.category {
        case .overweight, .obesityI, .obesityII, .obesityIII: return true
        case .underweight, .healthy: return false
        }
    }

    /// A prominent, reassuring note that BMI can't distinguish muscle from fat —
    /// so a fit, muscular person seeing a high number isn't necessarily at risk.
    private var muscleMassNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.subheadline)
                .foregroundStyle(CalcPalette.brandBlue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Muscle counts as weight")
                    .font(.footnote.weight(.semibold))
                Text("BMI can't tell muscle from fat. If you're lean and muscular, a higher number here can simply mean more muscle, not excess body fat or added health risk.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CalcPalette.brandBlue.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Healthy weight range for this height

    /// A supportive readout of the weight range that lands in the healthy BMI
    /// band for the person's height — the actionable, personalized companion to
    /// the abstract BMI number.
    private func healthyRangeRow(_ range: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "scalemass")
                .font(.subheadline)
                .foregroundStyle(BMICategory.healthy.bandColor)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text("Healthy weight for your height")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(range)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(BMICategory.healthy.bandColor.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        // Speak an en-dash range as "to" so VoiceOver reads it naturally.
        .accessibilityLabel(
            "Healthy weight for your height, \(range.replacingOccurrences(of: "–", with: " to "))"
        )
    }

    // MARK: Disclaimer

    private var disclaimer: some View {
        Text(BMIDisclaimer.text)
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Disclaimer. \(BMIDisclaimer.text)")
    }

    // MARK: Upsell

    private var upsell: some View {
        Button(action: onUpsellTapped) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Remove Ads with Pro")
                        .font(.subheadline.weight(.semibold))
                    Text("One-time purchase. No subscription.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .calcUpsellChrome()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Remove ads with Pro")
        .accessibilityHint("Opens the one-time purchase to remove ads.")
    }
}

// MARK: - Glass Card / Upsell Chrome

private struct CalcGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Theme.separator.opacity(0.6), lineWidth: 1))
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        }
    }
}

private struct CalcUpsellChrome: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(CalcPalette.brandBlue.opacity(0.18)), in: shape)
        } else {
            content
                .background(CalcPalette.brandBlue.opacity(0.10), in: shape)
                .overlay(shape.strokeBorder(CalcPalette.brandBlue.opacity(0.30), lineWidth: 1))
        }
    }
}

extension View {
    /// The Calculator's primary result-card glass treatment, with a pre-iOS-26
    /// material fallback.
    func calcGlassCard() -> some View { modifier(CalcGlassCard()) }

    /// Subtle tinted chrome for the inline Pro upsell.
    func calcUpsellChrome() -> some View { modifier(CalcUpsellChrome()) }
}

// MARK: - Previews

#Preview("Healthy") {
    ResultCard(
        result: BMIResult(value: 22.4, category: .healthy, standard: .standard, rounded: 22.4),
        healthyWeightRange: "59–79 kg",
        showsUpsell: true
    )
    .padding()
}

#Preview("Obesity II — Asian standard") {
    ResultCard(
        result: BMIResult(value: 28.1, category: .obesityI, standard: .asian, rounded: 28.1),
        healthyWeightRange: "129–159 lb",
        showsUpsell: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
