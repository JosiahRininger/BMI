//
//  ShareCardView.swift
//  BMICalculator — Features/Share
//
//  The shareable "progress card" rendered to a 1080×1920 image by
//  `ShareCardRenderer`. Design intent (from growth + stigma research):
//  - Progress / streak / trend framing — NOT an absolute BMI by default.
//  - Branded footer with an App Store deep link so the artifact advertises the app.
//  - Critical content kept inside a ~250px top/bottom safe zone.
//
//  IMPORTANT: this view is rasterized by `ImageRenderer`, which does NOT capture
//  Liquid Glass / material effects reliably — so the card uses SOLID brand
//  styling (gradient + opaque cards), never `.glassEffect`/`.glassCard`.
//

import SwiftUI

public struct ShareCardView: View {

    public let payload: SharePayload

    public init(payload: SharePayload) { self.payload = payload }

    // Fixed design canvas. The renderer produces this at 1:1 → 1080×1920 px.
    public static let canvas = CGSize(width: 1080, height: 1920)
    private let safeInset: CGFloat = 250

    public var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.brand, Theme.brandDeep],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 0) {
                Spacer().frame(height: safeInset)

                // Wordmark
                Text("BMI CALCULATOR")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                // Hero: progress headline (effort, not a verdict)
                VStack(spacing: 28) {
                    Image(systemName: payload.streakDays >= 2 ? "flame.fill" : "chart.line.uptrend.xyaxis")
                        .font(.system(size: 120, weight: .bold))
                        .foregroundStyle(.white)
                    Text(payload.progressHeadline)
                        .font(.system(size: 84, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 80)
                    Text(payload.dateRangeText)
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Spacer().frame(height: 60)

                // Trend sparkline card (no axis numbers — it's a shape, not data leakage)
                trendCard
                    .padding(.horizontal, 110)

                // Opt-in number block
                if payload.includeNumber, let bmi = payload.latestRoundedBMI {
                    numberCard(bmi: bmi)
                        .padding(.top, 48)
                        .padding(.horizontal, 110)
                }

                Spacer()

                footer
                Spacer().frame(height: safeInset - 80)
            }
        }
        .frame(width: Self.canvas.width, height: Self.canvas.height)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("My trend")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
            Sparkline(values: payload.recentTrend)
                .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                .frame(height: 220)
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 44, style: .continuous))
    }

    private func numberCard(bmi: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Current BMI")
                    .font(.system(size: 34, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                Text(String(format: "%.1f", bmi))
                    .font(.system(size: 96, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            if let cat = payload.latestCategoryTitle {
                Text(cat)
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 16)
                    .background(.white.opacity(0.22), in: Capsule())
            }
        }
        .padding(48)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 44, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 24) {
            // Brand badge (avoids depending on a shipped app-icon asset in the renderer)
            Text("BMI")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.brand)
                .frame(width: 96, height: 96)
                .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text("Made with BMI Calculator")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Free on the App Store")
                    .font(.system(size: 32, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

/// A normalized sparkline of the supplied values (oldest → newest). Renders only
/// the shape; never any numeric labels.
struct Sparkline: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard values.count > 1 else {
            if values.count == 1 { // flat line
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            }
            return path
        }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        // Degenerate (all-equal) trend: draw a centered flat line, matching the
        // single-value branch, instead of pinning it to the bottom edge.
        guard maxV - minV > 0.0001 else {
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
        let span = maxV - minV
        let stepX = rect.width / CGFloat(values.count - 1)

        for (i, v) in values.enumerated() {
            let x = rect.minX + CGFloat(i) * stepX
            // invert y so higher values sit higher on screen
            let y = rect.maxY - CGFloat((v - minV) / span) * rect.height
            let pt = CGPoint(x: x, y: y)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        return path
    }
}

#Preview {
    // The card is a fixed 1080×1920 render canvas. For an on-screen Xcode preview
    // we only scale the DISPLAY of that canvas to fit; the canvas itself is never
    // restructured or made adaptive (that is owned by the share sheet's preview).
    GeometryReader { proxy in
        let scale = proxy.size.width / ShareCardView.canvas.width
        ShareCardView(payload: .preview)
            .frame(width: ShareCardView.canvas.width, height: ShareCardView.canvas.height)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: proxy.size.width, height: ShareCardView.canvas.height * scale)
    }
}
