//
//  BMIGauge.swift
//  BMICalculator — DesignSystem
//
//  An animatable arc gauge that plots a BMI value across colored category
//  bands. The arc is divided into proportional segments (underweight → obesity)
//  each tinted with its `BMICategory.bandColor`, and a needle / indicator
//  sweeps to the supplied BMI value with a spring animation.
//
//  Pure SwiftUI. Depends on `BMICategory` from Core and `Theme` from this
//  module. The gauge is appearance-aware and works on iOS 18+.
//

import SwiftUI

// MARK: - Gauge Scale

/// Describes the numeric domain the gauge renders and how `BMICategory`
/// boundaries map onto the arc. Kept independent of `BMICalculator` so the
/// gauge can be previewed and reused without the engine.
struct BMIGaugeScale {

    /// Lowest BMI value shown at the start of the arc.
    let minValue: Double

    /// Highest BMI value shown at the end of the arc.
    let maxValue: Double

    /// Ordered (upperBound, category) breakpoints used to color the arc.
    /// The last entry's `upperBound` should equal `maxValue`.
    ///
    /// These mirror the universal CDC/WHO cutoffs. The Asian overlay still maps
    /// cleanly because its action points (23 / 27.5) fall inside the same
    /// rendered domain; callers that want Asian band edges can supply a custom
    /// scale.
    let breakpoints: [(upperBound: Double, category: BMICategory)]

    /// The default scale: 12 → 42 BMI using standard cutoffs. This frames the
    /// clinically meaningful range while keeping a small margin on each end.
    static let standard = BMIGaugeScale(
        minValue: 12,
        maxValue: 42,
        breakpoints: [
            (18.5, .underweight),
            (25,   .healthy),
            (30,   .overweight),
            (35,   .obesityI),
            (40,   .obesityII),
            (42,   .obesityIII)
        ]
    )

    /// Asian-standard scale using WHO public-health action points
    /// (18.5 / 23 / 27.5). Obesity classes II/III are not defined for the Asian
    /// overlay, so the top segment continues as obesity (class 1) shading.
    static let asian = BMIGaugeScale(
        minValue: 12,
        maxValue: 42,
        breakpoints: [
            (18.5, .underweight),
            (23,   .healthy),
            (27.5, .overweight),
            (42,   .obesityI)
        ]
    )

    /// Total span of the rendered domain.
    var span: Double { maxValue - minValue }

    /// Normalizes a BMI value to `0...1` across the rendered domain, clamped.
    func fraction(for value: Double) -> Double {
        guard span > 0 else { return 0 }
        return min(max((value - minValue) / span, 0), 1)
    }

    /// Returns proportional segments as `(start, end, category)` fractions in
    /// `0...1`, ready to be drawn as arc sub-paths.
    var segments: [(start: Double, end: Double, category: BMICategory)] {
        var result: [(Double, Double, BMICategory)] = []
        var lowerValue = minValue
        for breakpoint in breakpoints {
            let start = fraction(for: lowerValue)
            let end = fraction(for: breakpoint.upperBound)
            result.append((start, end, breakpoint.category))
            lowerValue = breakpoint.upperBound
        }
        return result
    }
}

// MARK: - Arc Geometry

/// A stroked arc spanning a fraction of the gauge sweep. Used both for the
/// colored band segments and (conceptually) the track.
private struct GaugeArc: Shape {

    /// Start fraction of the full sweep, `0...1`.
    var startFraction: Double

    /// End fraction of the full sweep, `0...1`.
    var endFraction: Double

    /// Total sweep angle of the gauge, in degrees (e.g. 240 for an open-bottom
    /// gauge). The arc is centered around the top.
    var sweepDegrees: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)

        // The sweep is centered so it opens symmetrically at the bottom.
        let startAngle = Angle.degrees(90 + (360 - sweepDegrees) / 2)
        let totalSweep = sweepDegrees

        let a0 = startAngle + .degrees(totalSweep * startFraction)
        let a1 = startAngle + .degrees(totalSweep * endFraction)

        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: a0,
            endAngle: a1,
            clockwise: false
        )
        return path
    }
}

// MARK: - BMI Gauge

/// A circular/arc gauge that plots a BMI value across colored category bands.
///
/// The gauge animates the indicator to `bmi` whenever the value changes. Pass a
/// `scale` to control the numeric domain and band edges (defaults to the
/// standard CDC/WHO cutoffs).
struct BMIGauge: View {

    // MARK: Inputs

    /// The BMI value to plot. Animatable via `animatedFraction`.
    var bmi: Double

    /// The category the value falls into. Drives the center label color and the
    /// indicator tint so the gauge always agrees with the engine's verdict.
    var category: BMICategory

    /// The scale defining the rendered domain and band edges.
    var scale: BMIGaugeScale

    /// Total sweep of the arc in degrees. 240° leaves an open gap at the
    /// bottom, the classic dashboard-gauge look.
    var sweepDegrees: Double

    /// Stroke width of the colored bands.
    var bandWidth: CGFloat

    /// When `false`, the numeric value and category label inside the gauge are
    /// hidden (useful for compact contexts).
    var showsCenterLabel: Bool

    // MARK: Animation State

    /// Internally tracked, animated fraction the indicator sweeps to. Kept in
    /// state so the needle springs smoothly when `bmi` changes.
    @State private var animatedFraction: Double = 0

    /// When the person has Reduce Motion enabled, the indicator snaps instead of
    /// springing so the sweep doesn't trigger motion discomfort.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Init

    init(
        bmi: Double,
        category: BMICategory,
        scale: BMIGaugeScale = .standard,
        sweepDegrees: Double = 240,
        bandWidth: CGFloat = 18,
        showsCenterLabel: Bool = true
    ) {
        self.bmi = bmi
        self.category = category
        self.scale = scale
        self.sweepDegrees = sweepDegrees
        self.bandWidth = bandWidth
        self.showsCenterLabel = showsCenterLabel
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            // Inset so the stroked band (and indicator knob) fit inside bounds.
            let inset = bandWidth / 2 + 10
            let arcRect = CGRect(
                x: (geo.size.width - side) / 2 + inset,
                y: (geo.size.height - side) / 2 + inset,
                width: side - inset * 2,
                height: side - inset * 2
            )

            ZStack {
                trackArc(in: arcRect)
                bandArcs(in: arcRect)
                indicator(in: arcRect)
                if showsCenterLabel {
                    centerLabel
                        .frame(width: arcRect.width, height: arcRect.height)
                        .position(x: arcRect.midX, y: arcRect.midY)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BMI gauge")
        .accessibilityValue(accessibilityDescription)
        .onAppear {
            animateIndicator(to: scale.fraction(for: bmi))
        }
        .onChange(of: bmi) { _, newValue in
            animateIndicator(to: scale.fraction(for: newValue))
        }
    }

    // MARK: Sub-views

    /// The faint background track behind the colored bands.
    private func trackArc(in rect: CGRect) -> some View {
        GaugeArc(startFraction: 0, endFraction: 1, sweepDegrees: sweepDegrees)
            .stroke(
                Theme.separator.opacity(0.5),
                style: StrokeStyle(lineWidth: bandWidth, lineCap: .round)
            )
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }

    /// The colored category band segments.
    private func bandArcs(in rect: CGRect) -> some View {
        ZStack {
            ForEach(Array(scale.segments.enumerated()), id: \.offset) { _, segment in
                GaugeArc(
                    startFraction: segment.start,
                    endFraction: segment.end,
                    sweepDegrees: sweepDegrees
                )
                .stroke(
                    segment.category.bandColor,
                    style: StrokeStyle(lineWidth: bandWidth, lineCap: .butt)
                )
            }
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
    }

    /// The sweeping indicator: a knob riding the arc at the current fraction.
    private func indicator(in rect: CGRect) -> some View {
        let radius = min(rect.width, rect.height) / 2
        let startAngle = 90 + (360 - sweepDegrees) / 2
        let angle = Angle.degrees(startAngle + sweepDegrees * animatedFraction)
        let knob = CGPoint(
            x: rect.midX + radius * cos(angle.radians),
            y: rect.midY + radius * sin(angle.radians)
        )

        return Circle()
            .fill(Theme.surface)
            .frame(width: bandWidth + 8, height: bandWidth + 8)
            .overlay(
                Circle()
                    .strokeBorder(category.bandColor, lineWidth: 4)
            )
            .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
            .position(x: knob.x, y: knob.y)
    }

    /// The numeric value + category label shown in the gauge's open center.
    private var centerLabel: some View {
        VStack(spacing: 4) {
            Text(formattedBMI)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                // Fixed-size hero number: allow Dynamic Type to scale it up to a
                // sensible cap so it never grows past the gauge's open center.
                .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: bmi))
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: bmi)

            // Category is conveyed by an SF Symbol + text (not color alone) so
            // the band reads for color-blind people.
            Label {
                Text(category.title)
            } icon: {
                Image(systemName: categorySymbolName)
            }
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(category.bandOnSoftColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(category.bandSoftColor)
            )

            Text("BMI")
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    /// SF Symbol that distinguishes the category without relying on band color,
    /// for color-blind safety.
    private var categorySymbolName: String {
        switch category {
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

    // MARK: Helpers

    /// BMI rounded to one decimal for display.
    private var formattedBMI: String {
        String(format: "%.1f", bmi)
    }

    /// Spoken description for VoiceOver. Conveys the value, the named category,
    /// and its numeric range so the verdict never depends on band color.
    private var accessibilityDescription: String {
        "BMI \(formattedBMI), \(category.title), range \(category.displayRange)"
    }

    /// Springs the indicator to a new normalized fraction. Snaps without
    /// animation when Reduce Motion is enabled.
    private func animateIndicator(to fraction: Double) {
        if reduceMotion {
            animatedFraction = fraction
        } else {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedFraction = fraction
            }
        }
    }
}

// MARK: - Previews

#Preview("BMI Gauge — Standard, Light") {
    VStack(spacing: 32) {
        BMIGauge(bmi: 22.4, category: .healthy)
            .frame(height: 260)
        BMIGauge(bmi: 31.2, category: .obesityI)
            .frame(height: 200)
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("BMI Gauge — Dark") {
    BMIGauge(bmi: 17.1, category: .underweight)
        .frame(height: 280)
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.dark)
}

#Preview("BMI Gauge — Asian scale") {
    BMIGauge(
        bmi: 24.0,
        category: .overweight,
        scale: .asian
    )
    .frame(height: 280)
    .padding()
    .background(Theme.background)
}
