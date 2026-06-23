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
import SafariServices

// MARK: - Settings

struct SettingsView: View {

    // MARK: Durable Preferences

    @AppStorage(AppStorageKey.unitSystem) private var unitSystemRaw: String = UnitSystem.metric.rawValue
    @AppStorage(AppStorageKey.healthStandard) private var healthStandardRaw: String = HealthStandard.standard.rawValue
    @AppStorage(AppStorageKey.reminderCadence) private var reminderCadenceRaw: String = NotificationService.ReminderCadence.weekly.rawValue

    // MARK: Services

    @Environment(StoreState.self) private var store
    @Environment(StoreService.self) private var storeService
    @Environment(HealthKitService.self) private var healthKit
    @Environment(NotificationService.self) private var notifications
    @Environment(AppearanceStore.self) private var appearance
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.openURL) private var openURL

    // MARK: Local State

    @State private var isReminderRequesting = false
    @State private var healthState: HealthConnectState = .unknown
    @State private var purchaseError: String?
    @State private var showFullDisclaimer = false
    @State private var showPaywall = false
    @State private var showProfiles = false
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
                appearanceSection
                profilesSection
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
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
            .sheet(isPresented: $showProfiles) {
                ProfilesView()
            }
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

    // MARK: Appearance (Pro accent theme)

    private var appearanceSection: some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 64, maximum: 84), spacing: DSSpacing.md)],
                spacing: DSSpacing.md
            ) {
                ForEach(AppTheme.allCases) { theme in
                    ThemeSwatch(
                        theme: theme,
                        isSelected: appearance.theme == theme,
                        isLocked: theme.isPro && !store.isPro
                    ) {
                        selectTheme(theme)
                    }
                }
            }
            .padding(.vertical, DSSpacing.xs)

            if !store.isPro {
                Text("More palettes are part of BMI Pro.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.secondaryText)
            }
        } header: {
            Text("Accent theme")
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    private func selectTheme(_ theme: AppTheme) {
        if theme.isPro && !store.isPro {
            showPaywall = true
        } else {
            appearance.theme = theme
        }
    }

    // MARK: Profiles (Pro multi-person tracking)

    private var profilesSection: some View {
        Section {
            Button {
                showProfiles = true
            } label: {
                HStack {
                    Label {
                        Text("Profiles").foregroundStyle(DSColor.primaryText)
                    } icon: {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(DSColor.brand)
                            .accessibilityHidden(true)
                    }
                    Spacer()
                    Text(profilesSummary)
                        .foregroundStyle(DSColor.secondaryText)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DSColor.secondaryText)
                        .accessibilityHidden(true)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Profiles")
            .accessibilityValue(profilesSummary)
            .accessibilityHint("Track more than one person with BMI Pro")
        } header: {
            Text("People")
        }
        .listRowBackground(DSColor.secondaryBackground)
    }

    private var profilesSummary: String {
        let count = profiles.profiles.count
        if count <= 1 {
            return profiles.activeProfile?.name ?? "Me"
        }
        return "\(count) profiles"
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

            // Check-in reminder cadence
            HStack {
                Label {
                    Text("Check-in reminder")
                        .foregroundStyle(DSColor.primaryText)
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(DSColor.brand)
                        .accessibilityHidden(true)
                }
                Spacer()
                if isReminderRequesting {
                    ProgressView()
                        .accessibilityLabel("Setting up reminder")
                } else {
                    Picker("Check-in reminder", selection: Binding(
                        get: { reminderCadence },
                        set: setCadence
                    )) {
                        ForEach(NotificationService.ReminderCadence.allCases) { cadence in
                            Text(cadence.title).tag(cadence)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .tint(DSColor.brand)
                    .accessibilityHint("Choose how often to get a gentle check-in reminder")
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
                Text("Thank you. Pro is unlocked across the app.")
                    .font(DSFont.caption)
                    .foregroundStyle(DSColor.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    Text("Unlock BMI Pro")
                        .font(DSFont.headline)
                        .foregroundStyle(DSColor.primaryText)
                    Text("One purchase removes all ads, unlocks history export and custom themes, and lets you track multiple people. No subscription, ever.")
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
                    .accessibilityHint("One-time purchase to unlock BMI Pro")

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
            return "Unlock Pro (\(price))"
        }
        return "Unlock Pro"
    }

    // MARK: About / Legal

    private var aboutSection: some View {
        Section("About") {
            Button {
                showPrivacy = true
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
        .sheet(isPresented: $showPrivacy) {
            // Open the policy in an in-app browser rather than leaving the app.
            SafariView(url: AppLinks.privacyPolicy)
                .ignoresSafeArea()
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

    private var reminderCadence: NotificationService.ReminderCadence {
        NotificationService.ReminderCadence(rawValue: reminderCadenceRaw) ?? .weekly
    }

    private func setCadence(_ cadence: NotificationService.ReminderCadence) {
        reminderCadenceRaw = cadence.rawValue
        guard cadence != .off else {
            notifications.cancelAll()
            return
        }
        isReminderRequesting = true
        Task {
            let granted = await notifications.requestAuthorization()
            if granted {
                await notifications.schedule(cadence: cadence)
            } else {
                reminderCadenceRaw = NotificationService.ReminderCadence.off.rawValue
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

// MARK: - Theme Swatch

/// A single accent-palette swatch in the Settings theme grid: a gradient circle
/// with a selection ring, a checkmark when active, and a lock when it's a Pro
/// palette the person doesn't own yet.
private struct ThemeSwatch: View {
    let theme: AppTheme
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(theme.gradient)
                        .frame(width: 46, height: 46)
                        .overlay(
                            Circle().strokeBorder(
                                // Unselected ring must read on both surfaces: a flat
                                // black hairline vanishes on the dark-mode row.
                                isSelected ? DSColor.primaryText
                                           : Color.dynamic(light: .black.opacity(0.06),
                                                           dark: .white.opacity(0.18)),
                                lineWidth: isSelected ? 2.5 : 1
                            )
                        )
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    } else if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                }

                Text(theme.displayName)
                    .font(DSFont.caption2)
                    .foregroundStyle(DSColor.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.displayName)
        .accessibilityValue(isSelected ? "Selected" : (isLocked ? "Locked, BMI Pro" : "Available"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isLocked ? "Unlock with BMI Pro" : "Use this accent")
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
    let container = PersistenceController.inMemory()
    let storeState = StoreState()
    return SettingsView()
        .environment(storeState)
        .environment(StoreService(state: storeState))
        .environment(HealthKitService())
        .environment(NotificationService())
        .environment(AppearanceStore())
        .environment(ProfileStore(container: container))
        .modelContainer(container)
}
