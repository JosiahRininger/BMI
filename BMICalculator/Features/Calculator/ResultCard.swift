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
    "BMI is a screening tool, not a diagnosis. It doesn't measure body fat directly and can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider."
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

    /// Whether to show the inline Pro upsell (non-Pro people only).
    let showsUpsell: Bool

    /// Invoked when the person taps the upsell. The parent presents the IAP /
    /// paywall — this view never touches StoreKit directly.
    var onUpsellTapped: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            BMIGauge(
                bmi: result.value,
                category: result.category,
                scale: result.standard.gaugeScale,
                showsCenterLabel: false
            )
            .frame(height: 160)
            categoryBlock
            disclaimer
            if showsUpsell {
                upsell
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .calcGlassCard()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: Header — big number

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(result.rounded, format: .number.precision(.fractionLength(1)))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(result.category.bandColor)
                .contentTransition(.numericText())
                .animation(.snappy, value: result.rounded)

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
            HStack(spacing: 8) {
                Circle()
                    .fill(result.category.bandColor)
                    .frame(width: 12, height: 12)
                Text(result.category.title)
                    .font(.headline)
                Text(result.category.displayRange)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(result.category.supportiveNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .calcUpsellChrome()
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
                .overlay(shape.strokeBorder(.white.opacity(0.10), lineWidth: 1))
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
        showsUpsell: true
    )
    .padding()
}

#Preview("Obesity II — Asian standard") {
    ResultCard(
        result: BMIResult(value: 28.1, category: .obesityI, standard: .asian, rounded: 28.1),
        showsUpsell: false
    )
    .padding()
    .preferredColorScheme(.dark)
}
