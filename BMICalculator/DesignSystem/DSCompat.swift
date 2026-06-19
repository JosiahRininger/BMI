//
//  DSCompat.swift
//  BMICalculator — DesignSystem
//
//  Compatibility shim. Several feature modules (Onboarding, Settings) were
//  generated in isolation against a `DS*`-prefixed DesignSystem API that was
//  never implemented — the canonical API instead lives on `Theme`, the
//  `glassCard()` modifier, the `GlassCard` container, and the
//  `.primaryGlass` / `.secondaryGlass` button styles (see `Theme.swift`,
//  `GlassComponents.swift`, `BMIGauge.swift`).
//
//  Rather than rewrite those consumers, this file defines thin bridges so the
//  `DS*` names resolve onto the real primitives and the consumers compile
//  UNCHANGED. Every symbol here is referenced by an existing consumer — nothing
//  speculative is defined. This file introduces NO new visual behavior: each
//  bridge forwards to the existing Theme / glass implementation.
//
//  Same App-target module as the rest of the app, so no `import` of the
//  DesignSystem or Core types is required — they are visible directly.
//
//  Referenced by:
//    - Features/Onboarding/OnboardingView.swift
//    - Features/Settings/SettingsView.swift
//

import SwiftUI

// MARK: - DSColor → Theme color tokens

/// Semantic color tokens consumed by Onboarding/Settings, forwarded to the
/// canonical `Theme` palette so there is a single source of truth.
enum DSColor {

    /// App background. → `Theme.background`.
    static var background: Color { Theme.background }

    /// Recessed / secondary surface (list-row & card fills). → `Theme.surfaceSecondary`.
    static var secondaryBackground: Color { Theme.surfaceSecondary }

    /// Primary brand accent. → `Theme.brand`.
    static var brand: Color { Theme.brand }

    /// Primary text color. → `Theme.textPrimary`.
    static var primaryText: Color { Theme.textPrimary }

    /// Secondary / supporting text color. → `Theme.textSecondary`.
    static var secondaryText: Color { Theme.textSecondary }

    /// The band color for a BMI category. → `BMICategory.bandColor`.
    static func category(_ category: BMICategory) -> Color { category.bandColor }
}

// MARK: - DSFont → system fonts

/// Typography tokens consumed by Onboarding/Settings. Each returns a plain
/// `Font` (so call sites can chain `.monospacedDigit()`, `.weight(_:)`, etc.),
/// mapping 1:1 onto the SwiftUI system text styles.
enum DSFont {
    static var largeTitle: Font { .largeTitle }
    static var title2: Font { .title2 }
    static var title3: Font { .title3 }
    static var headline: Font { .headline }
    static var subheadline: Font { .subheadline }
    static var body: Font { .body }
    static var caption: Font { .caption }
    static var caption2: Font { .caption2 }
}

// MARK: - DSSpacing → layout spacing scale

/// Spacing scale (points) consumed by Onboarding/Settings.
enum DSSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - DSRadius → corner radii

/// Corner-radius tokens consumed by Onboarding. `card` matches the `GlassCard`
/// / `glassCard()` default so the overlay strokes line up with the card shape.
enum DSRadius {
    static let card: CGFloat = 24
}

// MARK: - DSCard → glass card container

/// A glass-backed card container. Bridges to the canonical `glassCard()`
/// modifier so it picks up the iOS-26 Liquid Glass treatment (with the
/// `.regularMaterial` fallback) for free.
///
/// Matches the only shape the consumers use: a single trailing `@ViewBuilder`
/// content closure, e.g. `DSCard { ... }`.
struct DSCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
    }
}

// MARK: - PrimaryGlassButton → primary glass Button

/// A primary call-to-action button. Bridges to a `Button` wearing the canonical
/// `.primaryGlass` style. Matches the consumer call shape:
/// `PrimaryGlassButton(title:systemImage:action:)`, used with a trailing action
/// closure and modified with `.disabled(_:)` at the call site (hence a `View`).
struct PrimaryGlassButton: View {
    let title: String
    var systemImage: String?
    let action: () -> Void

    init(title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.primaryGlass)
    }
}

// MARK: - Compact / Circular glass button styles

/// A small, circular glass icon button (used for the +/- steppers in
/// onboarding). Glass on iOS 26, `.ultraThinMaterial` fallback below.
struct DSCircularGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CircularBody(configuration: configuration)
    }

    private struct CircularBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = Circle()
            return configuration.label
                .font(.headline)
                .foregroundStyle(Theme.brand)
                .modifier(DSGlassChrome(shape: shape, isPressed: configuration.isPressed))
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7),
                           value: configuration.isPressed)
                .contentShape(shape)
        }
    }
}

/// A compact, capsule glass button for inline secondary actions (e.g. the
/// "Connect" buttons in Onboarding/Settings).
struct DSCompactGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        CompactBody(configuration: configuration)
    }

    private struct CompactBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = Capsule(style: .continuous)
            return configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.brand)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .modifier(DSGlassChrome(shape: shape, isPressed: configuration.isPressed))
                .opacity(isEnabled ? 1 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.96 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7),
                           value: configuration.isPressed)
                .contentShape(shape)
        }
    }
}

/// Shared glass chrome for the `DS*` button styles. Uses the real Liquid Glass
/// API on iOS 26 and a `.ultraThinMaterial` + hairline border fallback below,
/// mirroring the approach in `GlassComponents.swift`.
private struct DSGlassChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    let isPressed: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(Theme.brand.opacity(0.18)).interactive(), in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(Theme.brand.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(isPressed ? 0.06 : 0.12),
                        radius: isPressed ? 3 : 6, x: 0, y: isPressed ? 1 : 3)
        }
    }
}

// MARK: - Button style conveniences (.dsCircularGlass / .dsCompactGlass)

extension ButtonStyle where Self == DSCircularGlassButtonStyle {
    /// Small circular glass icon button. → `DSCircularGlassButtonStyle`.
    static var dsCircularGlass: DSCircularGlassButtonStyle { .init() }
}

extension ButtonStyle where Self == DSCompactGlassButtonStyle {
    /// Compact capsule glass button. → `DSCompactGlassButtonStyle`.
    static var dsCompactGlass: DSCompactGlassButtonStyle { .init() }
}
