//
//  GlassComponents.swift
//  BMICalculator — DesignSystem
//
//  Reusable "Liquid Glass" building blocks. On iOS 26+ these use the real
//  glass APIs (`.glassEffect(_:in:)`, `GlassEffectContainer`,
//  `buttonStyle(.glass)` / `.glassProminent`). On iOS 18–25 they degrade
//  gracefully to `.regularMaterial` / `.ultraThinMaterial` so the app stays
//  fully functional on the entire supported range.
//
//  Pure SwiftUI. Depends only on `Theme` from this module.
//

import SwiftUI

// MARK: - Glass Card Modifier

/// A view modifier that gives any content a rounded, glassy card surface.
///
/// Use via the `glassCard()` convenience on `View`. The modifier owns the
/// iOS-26 availability check so call sites stay clean.
struct GlassCardModifier: ViewModifier {

    /// Corner radius of the card.
    var cornerRadius: CGFloat = 24

    /// Inner padding around the wrapped content.
    var padding: CGFloat = 20

    /// When `true`, tints the glass with the brand color for emphasis.
    var tinted: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return content
            .padding(padding)
            .modifier(
                GlassSurface(shape: shape, tinted: tinted)
            )
    }
}

/// Internal surface renderer that branches on OS capability.
private struct GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let tinted: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(glassStyle, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(
                    shape.strokeBorder(Theme.separator.opacity(0.6), lineWidth: 0.5)
                )
                .overlay {
                    if tinted {
                        shape.fill(Theme.brand.opacity(0.10))
                    }
                }
                .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 6)
        }
    }

    @available(iOS 26.0, *)
    private var glassStyle: Glass {
        tinted
            ? .regular.tint(Theme.brand.opacity(0.55)).interactive()
            : .regular
    }
}

// MARK: - View Convenience

extension View {

    /// Wraps the view in a Liquid Glass card (with a material fallback on
    /// pre-iOS-26 systems).
    ///
    /// - Parameters:
    ///   - cornerRadius: Corner radius of the card. Default `24`.
    ///   - padding: Inner padding. Default `20`.
    ///   - tinted: Tint the glass with the brand color. Default `false`.
    func glassCard(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 20,
        tinted: Bool = false
    ) -> some View {
        modifier(
            GlassCardModifier(cornerRadius: cornerRadius, padding: padding, tinted: tinted)
        )
    }
}

// MARK: - Glass Card Container

/// A container that renders its content inside a glass card. Equivalent to
/// `someView.glassCard()` but reads naturally when you want the card to drive
/// layout (e.g. grouping a header + body).
///
/// When several `GlassCard`s sit close together, wrap them in a
/// `GlassCardStack` so their glass effects blend correctly on iOS 26.
struct GlassCard<Content: View>: View {

    var cornerRadius: CGFloat
    var padding: CGFloat
    var tinted: Bool
    @ViewBuilder var content: () -> Content

    init(
        cornerRadius: CGFloat = 24,
        padding: CGFloat = 20,
        tinted: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.tinted = tinted
        self.content = content
    }

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: cornerRadius, padding: padding, tinted: tinted)
    }
}

// MARK: - Glass Effect Container Wrapper

/// Groups multiple glass elements so their shapes merge and morph together on
/// iOS 26. On older systems it is a transparent passthrough that simply applies
/// the requested spacing via the content's own layout.
struct GlassCardStack<Content: View>: View {

    /// Spacing hint passed to `GlassEffectContainer` for blending.
    var spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 16, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

// MARK: - Primary Glass Button Style

/// The app's primary call-to-action button style.
///
/// On iOS 26 it renders as a prominent, brand-tinted glass button. On iOS
/// 18–25 it falls back to a solid brand-gradient capsule that matches the
/// glass version's footprint and contrast.
struct PrimaryGlassButtonStyle: ButtonStyle {

    /// When `true`, uses the prominent (filled brand) glass treatment;
    /// otherwise a lighter, clear glass treatment.
    var prominent: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        PrimaryGlassButton(configuration: configuration, prominent: prominent)
    }

    /// Extracted so we can read `isEnabled` from the environment.
    private struct PrimaryGlassButton: View {
        let configuration: Configuration
        let prominent: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = Capsule(style: .continuous)

            return configuration.label
                .font(.headline.weight(.semibold))
                .foregroundStyle(prominent ? Theme.textOnBrand : Theme.brand)
                .padding(.vertical, 14)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .modifier(
                    GlassButtonBackground(
                        shape: shape,
                        prominent: prominent,
                        isPressed: configuration.isPressed
                    )
                )
                .opacity(isEnabled ? 1 : 0.5)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.7),
                           value: configuration.isPressed)
                .contentShape(shape)
        }
    }
}

/// Background renderer for `PrimaryGlassButtonStyle`, branching on OS support.
private struct GlassButtonBackground<S: InsettableShape>: ViewModifier {
    let shape: S
    let prominent: Bool
    let isPressed: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(glassStyle, in: shape)
        } else {
            content
                .background {
                    if prominent {
                        shape.fill(Theme.brandGradient)
                    } else {
                        shape.fill(.ultraThinMaterial)
                        shape.fill(Theme.brand.opacity(0.12))
                    }
                }
                .overlay {
                    shape.strokeBorder(
                        prominent ? Color.white.opacity(0.18) : Theme.brand.opacity(0.4),
                        lineWidth: prominent ? 0.5 : 1
                    )
                }
                .shadow(
                    color: (prominent ? Theme.brand : .black).opacity(isPressed ? 0.12 : 0.25),
                    radius: isPressed ? 6 : 12,
                    x: 0,
                    y: isPressed ? 2 : 6
                )
        }
    }

    @available(iOS 26.0, *)
    private var glassStyle: Glass {
        let base: Glass = prominent
            ? .regular.tint(Theme.brand)
            : .clear.tint(Theme.brand.opacity(0.35))
        return base.interactive()
    }
}

// MARK: - Button Style Convenience

extension ButtonStyle where Self == PrimaryGlassButtonStyle {

    /// The app's prominent, brand-tinted glass call-to-action style.
    static var primaryGlass: PrimaryGlassButtonStyle { .init(prominent: true) }

    /// A lighter, clear-glass variant for secondary actions.
    static var secondaryGlass: PrimaryGlassButtonStyle { .init(prominent: false) }
}

// MARK: - Previews

#Preview("Glass Components — Light") {
    GlassComponentsPreview()
        .preferredColorScheme(.light)
}

#Preview("Glass Components — Dark") {
    GlassComponentsPreview()
        .preferredColorScheme(.dark)
}

/// Internal preview harness exercising every glass component.
private struct GlassComponentsPreview: View {
    var body: some View {
        ZStack {
            Theme.brandGradient.opacity(0.25).ignoresSafeArea()

            ScrollView {
                GlassCardStack(spacing: 16) {
                    VStack(spacing: 16) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your result")
                                    .font(.headline)
                                    .foregroundStyle(Theme.textPrimary)
                                Text("BMI is a screening tool, not a diagnosis.")
                                    .font(.subheadline)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }

                        GlassCard(tinted: true) {
                            Text("Tinted glass card")
                                .font(.headline)
                                .foregroundStyle(Theme.textPrimary)
                        }

                        Button("Calculate BMI") {}
                            .buttonStyle(.primaryGlass)

                        Button("Remove Ads") {}
                            .buttonStyle(.secondaryGlass)
                    }
                    .padding()
                }
            }
        }
    }
}
