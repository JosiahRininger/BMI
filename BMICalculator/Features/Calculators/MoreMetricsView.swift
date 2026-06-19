//
//  MoreMetricsView.swift
//  BMICalculator — Features/Calculators
//
//  The "More metrics" hub. A scrolling list of glass cards, each linking to one
//  adjacent health calculator (TDEE, body fat, waist-to-height, ideal weight,
//  lean mass, frame size). A persistent, person-first screening disclaimer is
//  pinned to the footer so the framing is visible no matter where the person is
//  in the list.
//
//  Navigation: this view expects to live inside a `NavigationStack` provided by
//  the app shell (e.g. a new "Metrics" tab, or pushed from Settings / the
//  Calculator). It uses `NavigationLink(value:)` + `.navigationDestination` so the
//  destinations are decoupled from how the hub itself is presented.
//
//  HEALTH / AD FIREWALL: none of these screens touch the ad layer.
//

import SwiftUI

// MARK: - Metric Destinations

/// The set of adjacent calculators reachable from the hub. `Hashable` so it can
/// drive `NavigationLink(value:)`.
enum MetricDestination: String, CaseIterable, Identifiable, Hashable {
    case energy          // BMR & TDEE
    case bodyFat         // US Navy body fat %
    case waistHeight     // waist-to-height ratio
    case idealWeight     // ideal body weight range
    case leanMass        // lean body mass range
    case frameSize       // body frame size

    var id: String { rawValue }

    var title: String {
        switch self {
        case .energy:       return "Calorie needs"
        case .bodyFat:      return "Body fat estimate"
        case .waistHeight:  return "Waist-to-height"
        case .idealWeight:  return "Ideal weight range"
        case .leanMass:     return "Lean body mass"
        case .frameSize:    return "Body frame size"
        }
    }

    var subtitle: String {
        switch self {
        case .energy:       return "BMR and daily calories (TDEE)"
        case .bodyFat:      return "US Navy circumference method"
        case .waistHeight:  return "A quick central-adiposity screen"
        case .idealWeight:  return "A range from classic formulas"
        case .leanMass:     return "Estimated non-fat body mass"
        case .frameSize:    return "Small, medium, or large from your wrist"
        }
    }

    var systemImage: String {
        switch self {
        case .energy:       return "flame"
        case .bodyFat:      return "figure.arms.open"
        case .waistHeight:  return "ruler"
        case .idealWeight:  return "scalemass"
        case .leanMass:     return "figure.strengthtraining.traditional"
        case .frameSize:    return "hand.raised"
        }
    }
}

// MARK: - MoreMetricsView

/// The "More metrics" hub screen.
struct MoreMetricsView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                introCard

                GlassCardStack(spacing: 14) {
                    VStack(spacing: 14) {
                        ForEach(MetricDestination.allCases) { destination in
                            NavigationLink(value: destination) {
                                MetricRowCard(destination: destination)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            // Constrain primary content on iPad / large widths so the cards don't
            // stretch edge-to-edge; centered within the scroll view.
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(metricsBackground)
        .navigationTitle("More metrics")
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .bottom) {
            // Persistent person-first screening disclaimer footer.
            MetricsDisclaimerFooter()
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
        }
        .navigationDestination(for: MetricDestination.self) { destination in
            destinationView(for: destination)
        }
    }

    // MARK: Sections

    private var introCard: some View {
        GlassCard(tinted: true) {
            VStack(alignment: .leading, spacing: 6) {
                Text("A few more ways to look at your body")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text("Each of these is a quick screening estimate that goes a little beyond BMI. None of them is a diagnosis.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Routing

    @ViewBuilder
    private func destinationView(for destination: MetricDestination) -> some View {
        switch destination {
        case .energy:      TDEEView()
        case .bodyFat:     BodyFatView()
        case .waistHeight: WaistHeightView()
        case .idealWeight: IdealWeightView()
        case .leanMass:    LeanMassView()
        case .frameSize:   FrameSizeView()
        }
    }

    // MARK: Background

    private var metricsBackground: some View {
        LinearGradient(
            colors: [Theme.brand.opacity(0.10), Color.clear],
            startPoint: .top,
            endPoint: .center
        )
        .background(Theme.background)
        .ignoresSafeArea()
    }
}

// MARK: - MetricRowCard

/// A single tappable glass row for the hub.
private struct MetricRowCard: View {
    let destination: MetricDestination

    var body: some View {
        GlassCard {
            HStack(spacing: 16) {
                Image(systemName: destination.systemImage)
                    .font(.title2)
                    .foregroundStyle(Theme.brand)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.brand.opacity(0.14))
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(destination.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(destination.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(destination.title)
        .accessibilityHint(destination.subtitle)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("More metrics") {
    NavigationStack {
        MoreMetricsView()
    }
    .environment(HealthKitService())
}
