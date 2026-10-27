//
//  SettingsView.swift
//  BMICalculator
//
//  The app's Settings screen. It owns the durable preferences (default units,
//  health standard), the Apple Health connection, BMI Calculator Pro (the Pro
//  sheet, Restore, and the theme picker), the "Report an ad" row, and the
//  legal / support rows (full disclaimer, privacy policy, rate us).
//
//  Health/ad firewall: nothing on this screen passes any health value to an ad
//  SDK. The only monetization surface here is the StoreKit 2 purchase flow,
//  which is independent of any weight/height/BMI data.
//

import SwiftUI
import SafariServices
import SwiftData

// MARK: - Settings

struct SettingsView: View {

    // MARK: Durable Preferences

    @AppStorage(AppStorageKey.unitSystem) private var unitSystemRaw: String = UnitSystem.metric.rawValue
    @AppStorage(AppStorageKey.healthStandard) private var healthStandardRaw: String = HealthStandard.standard.rawValue

    // MARK: Services

    @Environment(StoreState.self) private var store
    @Environment(StoreService.self) private var storeService
    @Environment(HealthKitService.self) private var healthKit
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext

    // MARK: Local State

    @State private var healthState: HealthConnectState = .unknown
    @State private var purchaseError: String?
    @State private var restoreMessage: String?
    @State private var showsPro = false
    @State private var showFullDisclaimer = false
    @State private var showPrivacy = false

    private enum HealthConnectState { case unknown, connected, notConnected, working }

    // MARK: Derived

    private var unitSystem: UnitSystem {
        get { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
        nonmutating set { unitSystemRaw = newValue.rawValue }
    }

    private var healthStandard: HealthStandard {
        get { HealthStandard(rawValue: healthStandardRaw) ?? .standard }
        nonmutating set { healthStandardRaw = newValue.rawValue }
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Form {
                preferencesSection
                healthStandardSection
                integrationsSection
                proSection
                aboutSection
                disclaimerSection
            }
            .scrollContentBackground(.hidden)
            // Constrain to a readable, centered column so Settings doesn't
            // stretch edge-to-edge on iPad. No effect on iPhone (narrower than 640).
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(DSColor.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task { await refreshHealthState() }
            .onChange(of: healthStandardRaw) { _, raw in
                // Mirror the chosen standard into the App Group so other processes
                // (the Siri/Shortcut intent) categorize the same way the app does.
                UserDefaults(suiteName: AppConfig.appGroupID)?.set(raw, forKey: AppStorageKey.healthStandard)
                // Re-snapshot the widget so it re-categorizes with the new standard
                // immediately, not just after the next calculation.
                WidgetSync.update(from: modelContext.container)
            }
            .alert("Purchase issue", isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) { purchaseError = nil }
            } message: {
                Text(purchaseError ?? "")
            }
            .alert("Purchases restored", isPresented: Binding(
                get: { restoreMessage != nil },
                set: { if !$0 { restoreMessage = nil } }
            )) {
                Button("OK", role: .cancel) { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
            // Sheets go here on the Form, never on a Section. Inside a Form a
            // Section passes its modifiers to its header and to every row, so a
            // `.sheet` on a Section becomes one presenter per row, all bound to
            // the same Bool. On the first tap they race to present and SwiftUI
            // dismisses the sheet that won (2.1 "See Pro" closed itself).
            .sheet(isPresented: $showsPro) {
                ProSheet()
            }
            .sheet(isPresented: $showFullDisclaimer) {
                DisclaimerSheet()
            }
            .sheet(isPresented: $showPrivacy) {
                // Open the policy in an in-app browser rather than leaving the app.
                SafariView(url: AppLinks.privacyPolicy)
                    .ignoresSafeArea()
            }
        }
    }

    // MARK: Preferences

    private var preferencesSection: some View {
        Section("Units") {
            Picker("Default units", selection: Binding(
                get: { unitSystem },
                set: { unitSystem = $0 }
            )) {
                // Short labels: three segments with the parenthetical unit hints
                // ("Imperial (lb, ft)") overflow ~111pt/segment and truncate.
                Text("Metric").tag(UnitSystem.metric)
                Text("Imperial").tag(UnitSystem.imperial)
                Text("Stone").tag(UnitSystem.stone)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Default units")
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    // MARK: Health Standard

    private var healthStandardSection: some View {
        Section {
            Picker("BMI cutoffs", selection: Binding(
                get: { healthStandard },
                set: { healthStandard = $0 }
            )) {
                // Short labels: the parenthetical detail ("Standard (WHO/CDC)" /
                // "Asian action points") truncates in a 2-segment control once
                // Dynamic Type steps up. The note + footer below spell it out.
                Text("Standard").tag(HealthStandard.standard)
                Text("Asian").tag(HealthStandard.asian)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("BMI category cutoffs")

            Text(healthStandardNote)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.secondaryText)
        } header: {
            Text("Category standard")
        } footer: {
            Text("These population-level cutoffs guide screening; they are not a personal diagnosis. Talk to a healthcare provider about what's right for you.")
                .font(DSFont.caption2)
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    private var healthStandardNote: String {
        switch healthStandard {
        case .standard:
            return "Universal WHO/CDC cutoffs: healthy weight is 18.5 to under 25."
        case .asian:
            return "WHO Asian action points (lower thresholds: overweight at 23, higher risk at 27.5) are population-level public-health guidance for some Asian groups, not a replacement for individual medical advice."
        }
    }

    // MARK: Integrations

    private var integrationsSection: some View {
        Section("Connections") {
            // Apple Health
            HStack {
                Label {
                    Text("Apple Health")
                        .foregroundStyle(DSColor.primaryText)
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.pink)
                        .accessibilityHidden(true)
                }
                Spacer()
                healthConnectControl
            }
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    @ViewBuilder
    private var healthConnectControl: some View {
        switch healthState {
        case .working:
            ProgressView()
                .accessibilityLabel("Connecting to Apple Health")
        case .connected:
            Text("Connected")
                .font(DSFont.subheadline)
                .foregroundStyle(DSColor.category(.healthy))
                .accessibilityLabel("Apple Health connected")
        case .notConnected, .unknown:
            Button("Connect") { connectHealth() }
                .buttonStyle(.dsCompactGlass)
                .accessibilityLabel("Connect Apple Health")
                .accessibilityHint("Syncs your weight privately with Apple Health")
        }
    }

    // MARK: BMI Calculator Pro

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.hasPro {
                HStack {
                    Label {
                        Text("Pro: unlocked")
                            .foregroundStyle(DSColor.primaryText)
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(DSColor.brand)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DSColor.category(.healthy))
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Pro unlocked")
                Text(store.isEarlySupporter
                     ? "Thank you for your early support."
                     : "Thank you for supporting the app.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.secondaryText)
            } else {
                if store.adsRemoved {
                    HStack {
                        Label {
                            Text("Ads removed")
                                .foregroundStyle(DSColor.primaryText)
                        } icon: {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(DSColor.brand)
                                .accessibilityHidden(true)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(DSColor.category(.healthy))
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Ads removed")
                }
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text(store.adsRemoved ? "Upgrade to Pro" : ProCopy.name)
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.primaryText)
                    Text(proSubtitle)
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.secondaryText)

                    PrimaryGlassButton(
                        title: store.adsRemoved ? "Upgrade to Pro" : "See Pro",
                        systemImage: "sparkles"
                    ) {
                        showsPro = true
                    }
                    .accessibilityHint("Shows what Pro includes and its one-time price")

                    Button("Restore Purchases") { restore() }
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.brand)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .disabled(store.isProcessing)
                        .accessibilityLabel("Restore purchases")
                        .accessibilityHint("Restores an earlier purchase on this Apple Account")
                }
                .padding(.vertical, DSSpacing.xs)
            }

            NavigationLink {
                ThemePickerView()
            } label: {
                HStack {
                    Label {
                        Text("Theme").foregroundStyle(DSColor.primaryText)
                    } icon: {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(DSColor.brand)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    if !store.hasPro { ProBadge() }
                }
                .frame(minHeight: 44)
            }

            if store.isResolved && !store.adsRemoved {
                Button {
                    openURL(AppLinks.reportAd)
                } label: {
                    settingsRow(title: "Report an ad", systemImage: "flag.fill", showsChevron: true)
                }
                .accessibilityHint("Emails the developer about an inappropriate ad")
            }
        } header: {
            Text(ProCopy.name)
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    /// The Pro pitch line for Settings.
    private var proSubtitle: String {
        store.adsRemoved
            ? "Adds a doctor summary, a trend widget, and themes. One-time purchase."
            : "A doctor summary, a trend widget, themes, and no ads. One-time purchase, no subscription."
    }

    // MARK: About / Legal

    private var aboutSection: some View {
        Section("About") {
            Button {
                showPrivacy = true
            } label: {
                settingsRow(title: "Privacy Policy", systemImage: "hand.raised.fill", showsChevron: true)
            }
            .accessibilityHint("Opens the privacy policy in an in-app browser")

            Button {
                requestReview()
            } label: {
                settingsRow(title: "Rate us on the App Store", systemImage: "star.fill", showsChevron: true)
            }
            .accessibilityHint("Opens the App Store to write a review")

            Button {
                showFullDisclaimer = true
            } label: {
                settingsRow(title: "Medical disclaimer", systemImage: "cross.case.fill", showsChevron: true)
            }

            LabeledContent {
                Text(appVersionString)
                    .foregroundStyle(DSColor.secondaryText)
            } label: {
                settingsRow(title: "Version", systemImage: "info.circle.fill", showsChevron: false)
            }
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    // MARK: Disclaimer (always-visible short form)

    private var disclaimerSection: some View {
        Section {
            Text(Disclaimer.full)
                .font(DSFont.caption)
                .foregroundStyle(DSColor.secondaryText)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: Row Helper

    private func settingsRow(title: String, systemImage: String, showsChevron: Bool) -> some View {
        HStack {
            Label {
                Text(title).foregroundStyle(DSColor.primaryText)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(DSColor.brand)
                    .accessibilityHidden(true)
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DSColor.secondaryText)
                    .accessibilityHidden(true)
            }
        }
        // Guarantee the whole row is a single ~44pt-tall tap target and reads as
        // one VoiceOver element with the row title as its label.
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var appVersionString: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return b.isEmpty ? v : "\(v) (\(b))"
    }

    // MARK: Actions

    private func refreshHealthState() async {
        healthState = healthKit.hasRequestedAuthorization ? .connected : .notConnected
    }

    private func connectHealth() {
        healthState = .working
        Task {
            try? await healthKit.requestAuthorization()
            healthState = healthKit.hasRequestedAuthorization ? .connected : .notConnected
        }
    }

    private func restore() {
        Task {
            let restored = await storeService.restore()
            if restored {
                restoreMessage = RestoreCopy.message(for: store.entitlements)
            } else {
                purchaseError = store.lastErrorMessage
                    ?? "No earlier purchase was found for this Apple Account."
            }
        }
    }

    private func requestReview() {
        // An explicit "Rate us" tap must always do something. StoreKit's
        // requestReview is rate-limited and silently no-ops when throttled, so
        // for a user-initiated tap open the write-review composer instead (that
        // in-app prompt is reserved for app-initiated moments via ReviewPrompter).
        openURL(AppLinks.writeReview)
    }
}

// MARK: - Disclaimer Sheet

/// Full-screen-style sheet presenting the complete medical disclaimer.
private struct DisclaimerSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.lg) {
                    Image(systemName: "cross.case.fill")
                        .font(.largeTitle)
                        .foregroundStyle(DSColor.brand)
                        .accessibilityHidden(true)

                    Text("About BMI")
                        .font(DSFont.title2)
                        .foregroundStyle(DSColor.primaryText)

                    Text(Disclaimer.full)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.primaryText)

                    Text("BMI was developed from population averages. It does not account for muscle mass, bone density, body-fat distribution, sex, or ethnicity at the individual level. Use it as a starting point for a conversation with a healthcare provider, not as a verdict about a person's health.")
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.secondaryText)
                }
                .padding(DSSpacing.lg)
            }
            .background(DSColor.background.ignoresSafeArea())
            .navigationTitle("Medical disclaimer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - In-app Browser

/// Presents a URL in an in-app `SFSafariViewController` so links (e.g. the
/// privacy policy) open inside the app instead of switching to Safari.
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}

// MARK: - App Links

/// External URLs surfaced from Settings. Both are live: the privacy policy is
/// hosted at josiahrininger.com/bmi/privacy and the review link targets the
/// published BMI Calculator (App Store id 1467544257).
enum AppLinks {
    /// Hosted privacy policy (josiahrininger.com-hosted or App Store Connect link).
    static let privacyPolicy = URL(string: "https://josiahrininger.com/bmi/privacy")!

    /// Deep link that opens the App Store review composer for app id 1467544257.
    static let writeReview = URL(string: "https://apps.apple.com/app/id1467544257?action=write-review")!

    /// Emails the support address published on the support page, so anyone can
    /// report an inappropriate ad (Guideline 2.5.18).
    static let reportAd = URL(string: "mailto:josiahrininger@gmail.com?subject=BMI%20Calculator%3A%20report%20an%20ad&body=What%20did%20the%20ad%20show%2C%20and%20roughly%20when%3F")!
}

// MARK: - Disclaimer Copy

/// Single source of truth for the mandated disclaimer text (shared with the
/// result screen and onboarding so the wording never drifts).
enum Disclaimer {
    static let full = "BMI is a screening tool for informational purposes only, not a diagnosis or a substitute for professional medical advice. It doesn't directly measure body fat and can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider."
}

// MARK: - Preview

#Preview("Settings") {
    let container = PersistenceController.inMemory()
    let storeState = StoreState()
    return SettingsView()
        .environment(storeState)
        .environment(StoreService(state: storeState))
        .environment(HealthKitService())
        .modelContainer(container)
}
