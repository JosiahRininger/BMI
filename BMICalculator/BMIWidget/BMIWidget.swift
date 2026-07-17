//
//  BMIWidget.swift
//  BMICalculator — BMIWidget extension
//
//  The home-screen and lock-screen widgets. Shows the person's most recent
//  BMI value, its category, and a seven-point trend sparkline. Tapping the
//  widget deep-links into the app to start a new entry.
//
//  Person-first, non-judgmental copy throughout. Liquid Glass container
//  background is applied only behind `#available(iOS 26.0, *)`, with a
//  `.regularMaterial` / `.ultraThinMaterial` fallback on iOS 18–25.
//

import SwiftUI
import WidgetKit

// MARK: - Deep Links

/// URLs the widget uses to drive the host app. The App target must register
/// the `bmicalculator` URL scheme and route these paths.
enum BMIWidgetDeepLink {
    /// Opens the calculator ready for a new measurement.
    static let newEntry = URL(string: "bmicalculator://new-entry")!
    /// Opens the trend/history screen.
    static let history = URL(string: "bmicalculator://history")!
}

// MARK: - Brand

/// Shared brand palette for the widget. Brand blue is #19BEF4.
private enum BMIWidgetPalette {
    static let brand = Color(red: 0x19 / 255, green: 0xBE / 255, blue: 0xF4 / 255)
}

// MARK: - Category Color

extension BMICategory {

    /// Band color for the category. Underweight blue, healthy green,
    /// overweight yellow/orange, obesity I→III escalating orange→red.
    var bandColor: Color {
        switch self {
        case .underweight: return Color(red: 0.10, green: 0.62, blue: 0.96) // blue
        case .healthy:     return Color(red: 0.18, green: 0.70, blue: 0.42) // green
        case .overweight:  return Color(red: 0.95, green: 0.66, blue: 0.13) // yellow/orange
        case .obesityI:    return Color(red: 0.94, green: 0.49, blue: 0.13) // orange
        case .obesityII:   return Color(red: 0.90, green: 0.33, blue: 0.13) // deep orange
        case .obesityIII:  return Color(red: 0.84, green: 0.18, blue: 0.18) // red
        }
    }

    /// SF Symbol distinguishing the band by shape (not color alone), matching the
    /// app's result card. The widget target lacks the app's `symbolName`, so it's
    /// mirrored here.
    var widgetSymbol: String {
        switch self {
        case .underweight: return "arrow.down.circle.fill"
        case .healthy:     return "checkmark.circle.fill"
        case .overweight:  return "arrow.up.circle.fill"
        case .obesityI, .obesityII, .obesityIII: return "exclamationmark.circle.fill"
        }
    }
}

// MARK: - Sparkline

/// A compact trend line of recent BMI values. Renders nothing meaningful for
/// fewer than two points (caller shows a placeholder instead).
private struct TrendSparkline: View {
    let values: [Double]
    var lineColor: Color

    var body: some View {
        GeometryReader { geo in
            let path = sparkPath(in: geo.size)
            ZStack(alignment: .bottom) {
                // Soft fill under the line for a little depth.
                path
                    .fill(
                        LinearGradient(
                            colors: [lineColor.opacity(0.28), lineColor.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                strokePath(in: geo.size)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }

    /// A closed path (line + baseline) used for the gradient fill.
    private func sparkPath(in size: CGSize) -> Path {
        var path = strokePath(in: size)
        guard !values.isEmpty else { return path }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }

    /// The open trend line itself.
    private func strokePath(in size: CGSize) -> Path {
        var path = Path()
        guard values.count > 1 else { return path }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = max(maxValue - minValue, 0.0001) // avoid /0 on flat data
        let stepX = size.width / CGFloat(values.count - 1)

        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            // Invert Y so larger BMI is higher on screen; inset 10% top/bottom.
            let normalized = (value - minValue) / span
            let y = size.height * (1 - 0.1 - normalized * 0.8)
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }
}

// MARK: - Category Chip

/// A compact, colored pill naming the category with its shape symbol — the
/// widget's clear, glanceable verdict.
private struct CategoryChip: View {
    let category: BMICategory
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.widgetSymbol)
                .font(.system(size: 10, weight: .bold))
            Text(category.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(category.bandColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(category.bandColor.opacity(0.16)))
        .accessibilityHidden(true)
    }
}

// MARK: - BMI Scale Bar

/// The widget's visual anchor: a rounded spectrum bar spanning underweight →
/// obesity, with a marker showing exactly where this BMI sits. Ties the widget
/// to the app's "where are you on the scale" gauge identity.
private struct BMIScaleBar: View {
    let bmi: Double
    let category: BMICategory

    private let lo = 15.0
    private let hi = 40.0

    /// (BMI span, color) segments proportional to the fixed 15–40 domain.
    private var segments: [(span: Double, color: Color)] {
        [
            (18.5 - 15,  BMICategory.underweight.bandColor),
            (25 - 18.5,  BMICategory.healthy.bandColor),
            (30 - 25,    BMICategory.overweight.bandColor),
            (35 - 30,    BMICategory.obesityI.bandColor),
            (40 - 35,    BMICategory.obesityII.bandColor)
        ]
    }

    private var fraction: Double { min(max((bmi - lo) / (hi - lo), 0), 1) }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let barHeight = 8.0
            let markerSize = 15.0
            let markerX = min(max(fraction * w, markerSize / 2), w - markerSize / 2)

            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                        Rectangle()
                            .fill(seg.color)
                            .frame(width: w * seg.span / (hi - lo))
                    }
                }
                .frame(height: barHeight)
                .clipShape(Capsule())
                .frame(maxHeight: .infinity, alignment: .center)

                Circle()
                    .fill(.white)
                    .overlay(Circle().strokeBorder(category.bandColor, lineWidth: 2.5))
                    .frame(width: markerSize, height: markerSize)
                    .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
                    .offset(x: markerX - markerSize / 2)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}

// MARK: - Accessibility Summaries

/// Builds concise VoiceOver summaries for the widget so categories/values are
/// always spoken with context (and never as a bare number).
enum BMIWidgetAccessibility {

    /// e.g. "BMI 24.1, Healthy weight" — or a friendly prompt when empty.
    static func readoutLabel(for entry: BMIWidgetEntry) -> String {
        guard let latest = entry.latest else {
            return "BMI. No measurement yet. Tap to add a measurement."
        }
        let value = latest.rounded.formatted(.number.precision(.fractionLength(1)))
        return "BMI \(value), \(latest.category.title)"
    }

    /// A short trend summary describing the direction of recent values, so the
    /// otherwise-decorative sparkline conveys meaning to VoiceOver.
    static func trendLabel(for trend: [Double]) -> String? {
        guard let first = trend.first, let last = trend.last, trend.count > 1 else {
            return nil
        }
        let direction: String
        if last < first {
            direction = "trending down"
        } else if last > first {
            direction = "trending up"
        } else {
            direction = "holding steady"
        }
        return "Recent BMI trend, \(direction) over the last \(trend.count) entries"
    }
}

// MARK: - Widget Layouts

/// System small: big category-colored value, category chip, and the scale bar.
private struct BMISmallView: View {
    let entry: BMIWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BMI")
                .font(.caption2.weight(.bold))
                .kerning(0.5)
                .foregroundStyle(.secondary)

            if let latest = entry.latest {
                Text(latest.rounded.formatted(.number.precision(.fractionLength(1))))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(latest.category.bandColor)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                CategoryChip(category: latest.category)
                    .padding(.top, 3)
                Spacer(minLength: 8)
                BMIScaleBar(bmi: latest.rounded, category: latest.category)
            } else {
                Spacer(minLength: 0)
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(BMIWidgetPalette.brand)
                Text("Tap to add your first measurement")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BMIWidgetAccessibility.readoutLabel(for: entry))
    }
}

/// System medium: readout + chip on the left, relative date + trend on the
/// right, and the full-width scale bar anchoring the bottom.
private struct BMIMediumView: View {
    let entry: BMIWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let latest = entry.latest {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("BMI")
                            .font(.caption2.weight(.bold)).kerning(0.5)
                            .foregroundStyle(.secondary)
                        Text(latest.rounded.formatted(.number.precision(.fractionLength(1))))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(latest.category.bandColor)
                            .minimumScaleFactor(0.6).lineLimit(1)
                            .contentTransition(.numericText())
                        CategoryChip(category: latest.category)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(latest.date, format: .relative(presentation: .named))
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(1)
                        if entry.trend.count > 1 {
                            TrendSparkline(values: entry.trend, lineColor: latest.category.bandColor)
                                .frame(width: 132, height: 46)
                        }
                    }
                }
                Spacer(minLength: 0)
                BMIScaleBar(bmi: latest.rounded, category: latest.category)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(BMIWidgetPalette.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No measurement yet")
                            .font(.subheadline.weight(.semibold))
                        Text("Tap to calculate and track your BMI")
                            .font(.caption2).foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mediumAccessibilityLabel)
    }

    private var mediumAccessibilityLabel: String {
        let readout = BMIWidgetAccessibility.readoutLabel(for: entry)
        guard let trend = BMIWidgetAccessibility.trendLabel(for: entry.trend) else { return readout }
        return "\(readout). \(trend)"
    }
}

/// Lock-screen accessory (rectangular): value, category, mini sparkline.
private struct BMIAccessoryRectangularView: View {
    let entry: BMIWidgetEntry

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                if let latest = entry.latest {
                    Text("BMI \(latest.rounded.formatted(.number.precision(.fractionLength(1))))")
                        .font(.headline)
                        .widgetAccentable()
                    Text(latest.category.title)
                        .font(.caption2)
                        .lineLimit(1)
                } else {
                    Text("BMI")
                        .font(.headline)
                        .widgetAccentable()
                    Text("Tap to add")
                        .font(.caption2)
                }
            }
            Spacer(minLength: 0)
            if entry.trend.count > 1 {
                TrendSparkline(values: entry.trend, lineColor: .primary)
                    .frame(width: 46)
            }
        }
        // One combined summary so the lock-screen accessory never speaks a bare
        // "BMI 24.1" without its category context.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    /// Concise spoken summary for the lock-screen accessory, including the trend
    /// direction when available.
    private var accessibilityLabel: String {
        let readout = BMIWidgetAccessibility.readoutLabel(for: entry)
        guard let trend = BMIWidgetAccessibility.trendLabel(for: entry.trend) else {
            return readout
        }
        return "\(readout). \(trend)"
    }
}

// MARK: - Entry View

/// Switches between layouts by widget family and applies the themed,
/// Liquid-Glass-capable container background.
struct BMIWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BMIWidgetEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { backgroundView }
            .widgetURL(BMIWidgetDeepLink.newEntry)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            BMIMediumView(entry: entry)
        case .accessoryRectangular:
            BMIAccessoryRectangularView(entry: entry)
        default:
            BMISmallView(entry: entry)
        }
    }

    /// Themed background. On iOS 26 we layer a true Liquid Glass effect; on
    /// iOS 18–25 we fall back to a tinted material so the widget still reads as
    /// a frosted, on-brand surface.
    @ViewBuilder
    private var backgroundView: some View {
        switch family {
        case .accessoryRectangular:
            // Lock-screen accessories must stay transparent / vibrant.
            Color.clear
        default:
            glassBackground
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        // Subtly tint the whole widget by the current category (green for healthy,
        // orange for overweight, …) so the surface quietly reflects the verdict;
        // brand blue before any measurement exists.
        let tintColor = entry.latest?.category.bandColor ?? BMIWidgetPalette.brand
        let tint = LinearGradient(
            colors: [
                tintColor.opacity(0.16),
                tintColor.opacity(0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        if #available(iOS 26.0, *) {
            Rectangle()
                .fill(tint)
                .glassEffect(.regular, in: .rect)
        } else {
            ZStack {
                Rectangle().fill(.regularMaterial)
                Rectangle().fill(tint)
            }
        }
    }
}

// MARK: - Widget Definition

/// The home + lock screen BMI widget.
struct BMIWidget: Widget {
    static let kind = "BMIWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: BMIWidgetConfigurationIntent.self,
            provider: BMIWidgetProvider()
        ) { entry in
            BMIWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("BMI")
        .description("See your latest BMI, its category, and your recent trend at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    BMIWidget()
} timeline: {
    BMIWidgetEntry.sample()
    BMIWidgetEntry.empty()
}

#Preview("Medium", as: .systemMedium) {
    BMIWidget()
} timeline: {
    BMIWidgetEntry.sample()
}

#Preview("Rectangular", as: .accessoryRectangular) {
    BMIWidget()
} timeline: {
    BMIWidgetEntry.sample()
}
