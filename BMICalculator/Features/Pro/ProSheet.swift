//
//  ProSheet.swift
//  BMICalculator — Features/Pro
//
//  The one purchase surface for BMI Calculator Pro (and the ads-only Remove
//  Ads option). It adapts to what the person already owns:
//
//   • Nothing owned: Pro, plus "just remove ads" once the Pro launch cutoff
//     has passed.
//   • Remove Ads owned: "Upgrade to Pro" only.
//   • Pro owned: a quiet "Pro is unlocked" state.
//
//  Every price comes from StoreKit's localized `displayPrice`; nothing is
//  hard-coded. One-time purchases only, no subscription, no countdowns, a plain
//  "Not now", and Restore always reachable (Guidelines 3.1.1, 5.6).
//

import SwiftUI

// MARK: - Copy

/// The Pro copy, kept in one place so every surface says the same thing.
enum ProCopy {
    /// Product name: a brand, not localized.
    static let name = "BMI Calculator Pro"
    static var tagline: String { String(localized: "One purchase. No subscription. No ads.", comment: "Pro sheet subtitle. Pro is a one-time purchase.") }
    static var footer: String { String(localized: "One-time purchase. Restore anytime in Settings.", comment: "Pro sheet footer under the purchase buttons.") }
    static var supporter: String { String(localized: "Made by an independent developer. Thank you for helping keep it going.", comment: "Pro sheet note.") }

    struct Feature: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    static var doctorSummary: Feature { Feature(
        symbol: "doc.text",
        title: String(localized: "Doctor summary", comment: "Pro feature name: a PDF of BMI and weight history to share with a doctor."),
        detail: String(localized: "A clean PDF of your history for your next appointment.", comment: "Pro feature description.")
    ) }
    static var trendWidget: Feature { Feature(
        symbol: "chart.xyaxis.line",
        title: String(localized: "Trend widget", comment: "Pro feature name: a Home Screen widget with a BMI trend chart."),
        detail: String(localized: "Your recent entries, right on your Home Screen.", comment: "Pro feature description.")
    ) }
    static var themes: Feature { Feature(
        symbol: "paintpalette",
        title: String(localized: "Themes", comment: "Pro feature name: app color themes."),
        detail: String(localized: "Choose the colors that feel like yours.", comment: "Pro feature description.")
    ) }
    static var noAds: Feature { Feature(
        symbol: "rectangle.slash",
        title: String(localized: "No ads", comment: "Pro feature name."),
        detail: String(localized: "Anywhere in the app.", comment: "Pro feature description: no ads anywhere in the app.")
    ) }

    /// What Pro adds on top of what the person already has.
    static func features(includingNoAds: Bool) -> [Feature] {
        includingNoAds
            ? [doctorSummary, trendWidget, themes, noAds]
            : [doctorSummary, trendWidget, themes]
    }

    /// The short list for small cards.
    static var shortList: String { String(localized: "a doctor summary, a trend widget, and themes", comment: "Short list of Pro features, used inside a sentence.") }
}

// MARK: - ProSheet

struct ProSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(StoreState.self) private var store
    @Environment(StoreService.self) private var storeService

    /// What the sheet is showing.
    enum Phase: Equatable {
        case offer
        /// Waiting for approval (Ask to Buy) of this product.
        case pending(productID: String)
        case thanks(String)
    }

    @State private var phase: Phase = .offer
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    switch phase {
                    case .offer where store.hasPro:
                        unlocked(message: unlockedMessage)
                    case .offer:
                        offerContent
                    case .pending(let productID):
                        pendingContent(productID)
                    case .thanks(let message):
                        unlocked(message: message)
                    }
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                if showsPurchaseActions {
                    actions
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                        .background(.bar)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        showsPurchaseActions ? Text("Not now") : Text("Done")
                    }
                }
            }
            .alert(
                "Purchase issue",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            // An Ask to Buy approval (or a purchase on another device) arrives
            // through Transaction.updates; reflect it if the sheet is still open.
            .onChange(of: store.hasPro) { _, hasPro in
                if hasPro, case .pending = phase { phase = .thanks(Self.proThanks) }
            }
            .onChange(of: store.adsRemoved) { _, removed in
                if removed, case .pending(ProductID.removeAds) = phase { phase = .thanks(Self.removeAdsThanks) }
            }
            // Products load at launch; if that failed, load them now so the
            // buttons show prices and work.
            .task {
                if store.proProduct == nil || store.removeAdsProduct == nil {
                    await storeService.loadProducts()
                }
            }
        }
        // Full height, so the whole feature list is visible before any price.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: Offer

    private var offer: PurchaseOffer { store.offer }

    private var showsPurchaseActions: Bool {
        phase == .offer && !store.hasPro
    }

    @ViewBuilder
    private var offerContent: some View {
        header(
            title: offer == .upgradeToPro ? String(localized: "Upgrade to Pro") : ProCopy.name,
            subtitle: offer == .upgradeToPro
                ? String(localized: "You already have no ads. Pro adds the doctor summary, the trend widget, and themes.")
                : ProCopy.tagline
        )
        featureList(ProCopy.features(includingNoAds: offer != .upgradeToPro))
        Text(ProCopy.supporter)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    private func pendingContent(_ productID: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "hourglass")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.brand)
                .accessibilityHidden(true)
            Text("Waiting for approval")
                .font(.title2.bold())
            (productID == ProductID.removeAds
                 ? Text("Your purchase needs approval. Ads go away as soon as it's approved, even if you close this.", comment: "Ask to Buy: a parent must approve the Remove Ads purchase.")
                 : Text("Your purchase needs approval. Pro unlocks as soon as it's approved, even if you close this.", comment: "Ask to Buy: a parent must approve the Pro purchase."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 16)
    }

    private func unlocked(message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.brand)
                .accessibilityHidden(true)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .font(.headline)
                .padding(.top, 8)
        }
        .padding(.top, 16)
    }

    private func header(title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.brandGradient)
                .accessibilityHidden(true)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private func featureList(_ features: [ProCopy.Feature]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(features) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.symbol)
                        .font(.headline)
                        .foregroundStyle(Theme.brand)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.body.weight(.semibold))
                        Text(feature.detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: 10) {
            proButton
                .disabled(store.isProcessing)

            if case .pro(includesRemoveAdsOption: true) = offer {
                Button {
                    buy(ProductID.removeAds)
                } label: {
                    Text(removeAdsTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.isProcessing)
                .accessibilityHint("Removes ads only. Pro already includes this.")
                Text("Ads only. Pro already includes this.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Restore Purchases") { restore() }
                .font(.subheadline)
                .disabled(store.isProcessing)

            Text(ProCopy.footer)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if store.isProcessing {
                ProgressView()
            }
        }
    }

    @ViewBuilder
    private var proButton: some View {
        let button = Button {
            buy(ProductID.pro)
        } label: {
            Text(proTitle)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        if #available(iOS 26.0, *) {
            button.buttonStyle(.glassProminent)
        } else {
            button.buttonStyle(.borderedProminent).tint(Theme.brand)
        }
    }

    private var proTitle: String {
        if store.isProcessing { return String(localized: "Purchasing…", comment: "Pro purchase button while the purchase is in progress.") }
        if let price = store.proPrice {
            return String(localized: "Get Pro for \(price)", comment: "Pro purchase button. Argument: the App Store price, already localized (e.g. $4.99).")
        }
        return String(localized: "Get Pro", comment: "Pro purchase button before the price loads.")
    }

    private var removeAdsTitle: String {
        if let price = store.removeAdsPrice {
            return String(localized: "Just remove ads for \(price)", comment: "Remove Ads purchase button. Argument: the App Store price, already localized (e.g. $1.99).")
        }
        return String(localized: "Just remove ads", comment: "Remove Ads purchase button before the price loads.")
    }

    private var unlockedMessage: String {
        store.isEarlySupporter
            ? String(localized: "Pro is unlocked. Thank you for your early support.")
            : String(localized: "Pro is unlocked. Thank you for supporting BMI Calculator.", comment: "BMI Calculator is the app name (not translated).")
    }

    static var proThanks: String {
        String(localized: "Thank you! Pro is unlocked. Your doctor summary, trend widget, and themes are ready. Your purchase stays with your Apple Account, so it comes with you to a new phone.", comment: "Shown after buying Pro. Apple Account is Apple's term: use Apple's official name for it in your language.")
    }
    static var removeAdsThanks: String {
        String(localized: "Thank you! Ads are gone. Your purchase stays with your Apple Account, so it comes with you to a new phone.", comment: "Shown after buying Remove Ads. Apple Account is Apple's term: use Apple's official name for it in your language.")
    }

    private func buy(_ productID: String) {
        Task {
            let outcome = await storeService.purchase(productID)
            switch outcome {
            case .purchased:
                phase = .thanks(productID == ProductID.pro || store.hasPro ? Self.proThanks : Self.removeAdsThanks)
            case .pending:
                phase = .pending(productID: productID)
            case .cancelled:
                break
            case .failed:
                errorMessage = store.lastErrorMessage ?? StoreError.unknown.errorDescription
            }
        }
    }

    private func restore() {
        Task {
            let restored = await storeService.restore()
            if restored {
                phase = .thanks(RestoreCopy.message(for: store.entitlements))
            } else {
                errorMessage = store.lastErrorMessage ?? RestoreCopy.nothingFound
            }
        }
    }
}

// MARK: - Restore copy

enum RestoreCopy {
    /// The "welcome back" line after a successful restore.
    static func message(for entitlements: Entitlements) -> String {
        if entitlements.earlySupporter {
            return String(localized: "Welcome back. Your earlier purchase includes Pro, so everything is unlocked.", comment: "After restoring purchases, for early Remove Ads buyers who get Pro free.")
        }
        if entitlements.pro {
            return String(localized: "Welcome back. Pro is unlocked.", comment: "After restoring purchases.")
        }
        return String(localized: "Welcome back. Your ads are removed.", comment: "After restoring purchases (Remove Ads only).")
    }

    /// Restore found nothing to restore.
    static var nothingFound: String {
        String(localized: "No earlier purchase was found for this Apple Account.", comment: "Restore Purchases found nothing. Apple Account is Apple's term: use Apple's official name for it in your language.")
    }
}

// MARK: - Early supporter thank-you

/// Shown once to people whose early Remove Ads purchase now includes Pro.
/// Non-blocking: a single button closes it, and it never sells anything.
struct EarlySupporterSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onAppearOnce: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Theme.brandGradient)
                    .accessibilityHidden(true)
                Text("A thank-you for you")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text("You removed ads early on, so Pro is now yours at no cost. That includes the doctor summary, the trend widget, and themes.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                Text("Thank you for supporting BMI Calculator.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button {
                    dismiss()
                } label: {
                    Text("Got it")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.brand)
                .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: onAppearOnce)
        // Medium by default; large text sizes can expand it, and it scrolls.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Pro badge

/// A small "Pro" capsule marking Pro features in lists.
struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(Theme.brand)
            .background(Capsule().fill(Theme.brandSoft))
            .accessibilityLabel("Pro feature")
    }
}
