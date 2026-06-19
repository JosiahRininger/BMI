//
//  SettingsView.swift
//  BMICalculator
//
//  The app's Settings screen. It owns the durable preferences (default units,
//  health standard), the optional integrations (Apple Health, weekly reminder),
//  the "Remove Ads / Pro" non-consumable purchase + Restore, and the legal /
//  support rows (full disclaimer, privacy policy, rate us).
//
//  Health/ad firewall: nothing on this screen passes any health value to an ad
//  SDK. The only monetization surface here is the StoreKit 2 purchase flow,
//  which is independent of any weight/height/BMI data.
//

import SwiftUI

// MARK: - Settings

struct SettingsView: View {

    // MARK: Durable Preferences

    @AppStorage(AppStorageKey.unitSystem) private var unitSystemRaw: String = UnitSystem.metric.rawValue
    @AppStorage(AppStorageKey.healthStandard) private var healthStandardRaw: String = HealthStandard.standard.rawValue
    @AppStorage(AppStorageKey.weeklyReminderEnabled) private var weeklyReminderEnabled: Bool = false

    // MARK: Services

    @Environment(StoreState.self) private var store
    @Environment(StoreService.self) private var storeService
    @Environment(HealthKitService.self) private var healthKit
    @Environment(NotificationService.self) private var notifications
    @Environment(\.openURL) private var openURL

    // MARK: Local State

    @State private var isReminderRequesting = false
    @State private var healthState: HealthConnectState = .unknown
    @State private var purchaseError: String?
    @State private var showFullDisclaimer = false

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
            .background(DSColor.background.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .task { await refreshHealthState() }
            .alert("Purchase issue", isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) { purchaseError = nil }
            } message: {
                Text(purchaseError ?? "")
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
                Text("Metric (kg, cm)").tag(UnitSystem.metric)
                Text("Imperial (lb, ft)").tag(UnitSystem.imperial)
            }
            .pickerStyle(.segmented)
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
                Text("Standard (WHO/CDC)").tag(HealthStandard.standard)
                Text("Asian action points").tag(HealthStandard.asian)
            }
            .pickerStyle(.segmented)

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

            // Weekly reminder
            HStack {
                Label {
                    Text("Weekly check-in reminder")
                        .foregroundStyle(DSColor.primaryText)
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(DSColor.brand)
                        .accessibilityHidden(true)
                }
                Spacer()
                if isReminderRequesting {
                    ProgressView()
                        .accessibilityLabel("Setting up weekly reminder")
                } else {
                    Toggle("Weekly check-in reminder", isOn: Binding(
                        get: { weeklyReminderEnabled },
                        set: setReminderEnabled
                    ))
                    .labelsHidden()
                    .tint(DSColor.brand)
                    .accessibilityHint("Sends a gentle reminder to check in once a week")
                }
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

    // MARK: Pro / Remove Ads

    @ViewBuilder
    private var proSection: some View {
        Section {
            if store.isPro {
                HStack {
                    Label {
                        Text("BMI Pro is active")
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
                .accessibilityLabel("BMI Pro is active")
                Text("Thank you. Ads are removed across the app.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Remove Ads & BMI Pro")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.primaryText)
                    Text("A one-time purchase removes the banner and the post-calculation ad. No subscription, ever.")
                        .font(DSFont.caption)
                        .foregroundStyle(DSColor.secondaryText)

                    PrimaryGlassButton(
                        title: store.isProcessing ? "Purchasing…" : purchaseTitle,
                        systemImage: "sparkles"
                    ) {
                        purchasePro()
                    }
                    .disabled(store.isProcessing || store.displayPrice == nil)
                    .accessibilityLabel(store.isProcessing ? "Purchasing BMI Pro" : purchaseTitle)
                    .accessibilityHint("One-time purchase to remove ads")

                    Button("Restore Purchases") { restore() }
                        .font(DSFont.subheadline)
                        .foregroundStyle(DSColor.brand)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .disabled(store.isProcessing)
                        .accessibilityLabel("Restore purchases")
                        .accessibilityHint("Restores a previous BMI Pro purchase on this Apple ID")
                }
                .padding(.vertical, DSSpacing.xs)
            }
        } header: {
            Text("Support the app")
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    private var purchaseTitle: String {
        if let price = store.displayPrice {
            return "Remove Ads (\(price))"
        }
        return "Remove Ads"
    }

    // MARK: About / Legal

    private var aboutSection: some View {
        Section("About") {
            Button {
                openURL(AppLinks.privacyPolicy)
            } label: {
                settingsRow(title: "Privacy Policy", systemImage: "hand.raised.fill", showsChevron: true)
            }

            Button {
                requestReview()
            } label: {
                settingsRow(title: "Rate us on the App Store", systemImage: "star.fill", showsChevron: true)
            }

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
        .sheet(isPresented: $showFullDisclaimer) {
            DisclaimerSheet()
        }
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
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
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

    private func setReminderEnabled(_ newValue: Bool) {
        guard newValue else {
            weeklyReminderEnabled = false
            notifications.cancelWeeklyReminder()
            return
        }
        isReminderRequesting = true
        Task {
            let granted = await notifications.requestAuthorization()
            if granted {
                await notifications.scheduleWeeklyReminder()
                weeklyReminderEnabled = true
            } else {
                weeklyReminderEnabled = false
            }
            isReminderRequesting = false
        }
    }

    private func purchasePro() {
        Task {
            let succeeded = await storeService.purchase()
            if !succeeded, let message = store.lastErrorMessage {
                purchaseError = message
            }
        }
    }

    private func restore() {
        Task {
            let restored = await storeService.restore()
            if !restored {
                purchaseError = store.lastErrorMessage
                    ?? "No previous purchase found to restore."
            }
        }
    }

    private func requestReview() {
        // Prefer the StoreKit review prompt; fall back to a write-review URL.
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

// MARK: - App Links

/// External URLs surfaced from Settings. Replace placeholders with the live
/// destinations before shipping; App Store id is the published BMI Calculator.
enum AppLinks {
    /// Hosted privacy policy (josiahrininger.com-hosted or App Store Connect link).
    static let privacyPolicy = URL(string: "https://josiahrininger.com/bmi/privacy")!

    /// Deep link that opens the App Store review composer for app id 1467544257.
    static let writeReview = URL(string: "https://apps.apple.com/app/id1467544257?action=write-review")!
}

// MARK: - Disclaimer Copy

/// Single source of truth for the mandated disclaimer text (shared with the
/// result screen and onboarding so the wording never drifts).
enum Disclaimer {
    static let full = "BMI is a screening tool, not a diagnosis. It doesn't measure body fat directly and can be inaccurate for athletes, older adults, during pregnancy, and across ethnic groups. Talk to a healthcare provider."
}

// MARK: - Preview

#Preview("Settings") {
    SettingsView()
}
