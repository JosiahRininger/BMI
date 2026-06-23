# BMI Calculator — Xcode 26 Integration Guide

Assemble the freshly-generated SwiftUI source under `BMI/BMICalculator/` into a shippable
Xcode 26 project. This modernizes the published app (App Store id **1467544257**, legacy bundle id
`com.jdr.BMI`). Do everything in order; each section is checkbox-style.

**Ground truth before you start**
- Source lives under `/Users/josiahrininger/Developer/BMI/BMICalculator/` as loose `.swift` files —
  there is **no `.xcodeproj` and no `Package.swift` yet**. You are creating the project shell.
- The **old CocoaPods app** is `/Users/josiahrininger/Developer/BMI/BMI-iOS/` (`BMI.xcodeproj` + `Pods/`).
  Do **not** edit it. Reuse only its bundle id, signing team, App Store metadata, and AdMob ids.
- Conventions enforced repo-wide: Swift 6 strict concurrency, SwiftUI, **deployment target iOS 18.0**,
  iOS 26 Liquid Glass behind `#available(iOS 26.0, *)` with material fallbacks, App Store
  Guideline 5.1.3 health/ad firewall (no health value ever reaches the ad SDK; no iCloud sync of health).

---

## 1. Create the Xcode 26 project + targets

### 1a. App target
- [ ] **File ▸ New ▸ Project ▸ iOS ▸ App.**
- [ ] Product Name: **`BMICalculator`** (the test file uses `@testable import BMICalculator`; the module
      name MUST be `BMICalculator` or you must rename that import).
- [ ] Interface **SwiftUI**, Language **Swift**, Storage **None** (SwiftData is wired manually — do not let
      the template add a default `.modelContainer`).
- [ ] Bundle Identifier: **`com.jdr.BMI`** (reuse the legacy id to keep the same App Store listing).
- [ ] Minimum Deployments: **iOS 18.0**.
- [ ] Save it at `/Users/josiahrininger/Developer/BMI/BMICalculator/` so the generated `.xcodeproj`
      sits next to the existing source folders.
- [ ] Delete the template's `ContentView.swift` and the template `BMICalculatorApp.swift` —
      the real app entry is the one already on disk under `App/`.

### 1b. Add the existing source folders to the App target
Use **Add Files to "BMICalculator"…** and add each folder as a **group** (create groups, do **not**
copy items — they're already in place). App-target membership:

- [ ] `App/` — `BMICalculatorApp.swift`, `RootView.swift`
- [ ] `Core/` — `UnitSystem.swift`, `HealthStandard.swift`, `BMICategory.swift`, `BMIResult.swift`,
      `BMICalculator.swift`, **`BMIRecord.swift`** (the `@Model` — App target only, it imports SwiftData)
- [ ] `DesignSystem/` — `Theme.swift`, `GlassComponents.swift`, `BMIGauge.swift`
- [ ] `Features/Calculator/`, `Features/History/`, `Features/Onboarding/`, `Features/Settings/`,
      `Features/Calculators/` (the 6 extra calculators), `Features/Share/` (shareable progress card),
      `Features/Streak/` (shame-free streak) — all `.swift`
- [ ] `Core/HealthCalculators.swift` — the 6 adjacent calculators (Foundation-only; same shared-target
      treatment as the other Core files — also widget-safe if you want streak/metrics in the widget)
- [ ] `Services/` — `HealthKitService.swift`, `NotificationService.swift`, `ReviewPrompter.swift`,
      `StoreService.swift`, `AdsManager.swift`, `PersistenceController.swift`
- [ ] `Intents/` — `CalculateBMIIntent.swift`, `BMIShortcuts.swift`, `BMIResultEntity.swift`

> **Shared-target membership (Core + Intents).** The five Foundation-only Core files
> (`UnitSystem`, `HealthStandard`, `BMICategory`, `BMIResult`, `BMICalculator`) plus the widget-safe
> Intents files (`CalculateBMIIntent`, `BMIResultEntity`) are **also** needed by the widget extension
> (§1c). The simplest path is **multi-target file membership** (tick both the App and the Widget target
> in the File Inspector). The cleaner long-term path is a **local Swift Package** named `Core` that both
> targets link — if you do that, the `public`/`Sendable` qualifiers already on those types are required
> (they're present) and the modules that say `import Core` (the widget) will compile as written.
> **`BMIRecord.swift` is App-target ONLY** (SwiftData) — never add it to a Foundation-only Core package.

### 1c. Widget Extension target
- [ ] **File ▸ New ▸ Target ▸ Widget Extension.** Name it **`BMIWidget`**. Uncheck "Include Live Activity".
- [ ] Set its **Minimum Deployments to iOS 18.0** (Controls / `ControlWidget` require 18+).
- [ ] **Delete the auto-generated template files** in the new `BMIWidget` group.
- [ ] Add the four real widget files to the `BMIWidget` target: `BMIWidget/BMIWidgetBundle.swift`,
      `BMIWidget/BMIWidget.swift`, `BMIWidget/BMIWidgetProvider.swift`, `BMIWidget/BMIControl.swift`.
- [ ] Give the widget target the shared **Core** + **Intents** files (per §1b note): either tick both
      targets on those files, or link the `Core` SPM package.
- [ ] **Do NOT** add `BMIShortcuts.swift` (its `AppShortcutsProvider` belongs to the main app only) and
      **never** add any ad-SDK / `AdsManager` code to the widget target (firewall).

### 1d. Unit Test target
- [ ] **File ▸ New ▸ Target ▸ Unit Testing Bundle.** Name it **`BMICalculatorTests`**, Host Application
      **`BMICalculator`**. Xcode 26 enables the **Swift Testing** framework by default (the suite uses
      `import Testing` / `@Suite` / `@Test` / `#expect`).
- [ ] Add `Tests/BMICalculatorTests.swift` to **this test target only** (not the app target).
- [ ] Confirm it builds: it does `@testable import BMICalculator`, so the host app module name must be
      `BMICalculator`.

### Target-membership cheat sheet

| Folder / file | App | BMIWidget | Tests |
|---|:--:|:--:|:--:|
| `App/*` | ✔ | | |
| `Core/{UnitSystem,HealthStandard,BMICategory,BMIResult,BMICalculator}.swift` | ✔ | ✔ | (via `@testable`) |
| `Core/BMIRecord.swift` (SwiftData `@Model`) | ✔ | | |
| `DesignSystem/*`, `Features/*` | ✔ | | |
| `Services/*` | ✔ | | |
| `Intents/{CalculateBMIIntent,BMIResultEntity}.swift` | ✔ | ✔ (optional) | |
| `Intents/BMIShortcuts.swift` | ✔ | | |
| `BMIWidget/*` | | ✔ | |
| `Tests/BMICalculatorTests.swift` | | | ✔ |

- [ ] Set the **Swift Language Version to Swift 6** on every target (Build Settings ▸ Swift Compiler ▸
      Language ▸ Swift Language Version), and enable Strict Concurrency Checking = **Complete**.

---

## 2. Swift Package Manager + retire CocoaPods

### 2a. Add the Google Mobile Ads SDK (the only SPM dependency)
- [ ] **File ▸ Add Package Dependencies…**
- [ ] URL: `https://github.com/googleads/swift-package-manager-google-mobile-ads.git`
- [ ] Dependency rule: **Up to Next Major** from **12.0.0** (code targets the modern prefix-less v11+/v12
      API: `MobileAds.shared`, `Request`, `Extras`, `BannerView`, `AdSizeBanner`,
      `InterstitialAd.load(with:request:)`, `FullScreenContentDelegate`).
- [ ] Add product **`GoogleMobileAds`** to the **App target only** (never the widget).
- [ ] No SPM needed for HealthKit / UserNotifications / StoreKit / Charts / SwiftData / AppIntents /
      CoreSpotlight — those are system frameworks (auto-linked on import).
- [ ] `AdsManager.swift` is wrapped in `#if canImport(GoogleMobileAds)`, so previews/tests still compile
      if the SDK is temporarily absent.

### 2b. Remove the old CocoaPods setup
The legacy project is `BMI-iOS/`; CocoaPods is **not** carried into the new project. Nothing to migrate —
the new project uses SPM exclusively. For hygiene in the old tree (optional, do not ship it):
- [ ] In the **new** `BMICalculator` project, confirm there is **no `Podfile`, no `Pods/`, no
      `*.xcworkspace`** — you open `BMICalculator.xcodeproj` directly.
- [ ] Leave `BMI-iOS/` untouched as the archived legacy app.

---

## 3. Capabilities & entitlements

**Now codified — no manual "+ Capability" clicking needed.** The entitlements live in
`BMICalculator.entitlements` (app) and `BMIWidget/BMIWidget.entitlements` (widget), wired via
`CODE_SIGN_ENTITLEMENTS` in `project.yml`, and a `PrivacyInfo.xcprivacy` ships in each target. After
`xcodegen generate`, the only thing left is signing: **automatic signing** (the dev's team is set in
`project.yml`) registers HealthKit + App Groups on the App ID on first device build — accept the Xcode
prompt if it appears.

- [x] **HealthKit** — `com.apple.developer.healthkit = true` in `BMICalculator.entitlements`. Do **NOT**
      enable "Clinical Health Records". (Consumed by `Services/HealthKitService.swift`.)
- [x] **App Groups** — `group.com.jdr.BMI` in BOTH `BMICalculator.entitlements` and
      `BMIWidget/BMIWidget.entitlements`. Shared by `PersistenceController` (SwiftData store),
      `BMISharedStore` (widget snapshot), the isPro cache, and the cross-process standard mirror.
- [x] **Privacy manifests** — `PrivacyInfo.xcprivacy` in app + widget (local-first: no tracking, no
      collected data, UserDefaults reason CA92.1). GoogleMobileAds ships its own when added.
- [x] **URL scheme** — `bmicalculator://` registered via the partial `Info.plist` (deep links from the
      widget / Control Center / Siri).
- [ ] **In-App Purchase** — enable for the non-consumable "Remove Ads / Pro" (StoreKit 2, §5). This is an
      App Store Connect product, not a signing entitlement — see §5.
- [ ] **Push Notifications** — **NOT** required; the reminder is a local notification. Only add if remote
      push is introduced later.

> If you change the bundle id away from `com.jdr.BMI`, update the App Group id in both `.entitlements`
> files and the constants `BMISharedStore.appGroupID` / `AppConfig.appGroupID` / `PersistenceController`.

> If you later change the bundle id away from `com.jdr.BMI`, update the App Group id on both targets and
> change the single constants `BMISharedStore.appGroupID` and `PersistenceController` group id to match.

---

## 4. Info.plist keys

Add to the **App target** Info (Target ▸ Info, or the `Info.plist`). All HealthKit/AdMob keys are
**mandatory** — the app crashes at the relevant call without them.

- [ ] **`NSHealthShareUsageDescription`** (HealthKit read):
      `BMI Calculator reads your height and weight from Health to prefill the calculator so you don't have to type them. Health data never leaves your device and is never used for ads.`
- [ ] **`NSHealthUpdateUsageDescription`** (HealthKit write):
      `BMI Calculator can save your weight and BMI to Health after a calculation, if you choose.`
- [ ] **`GADApplicationIdentifier`** = **`ca-app-pub-6687613409331343~7486203316`**
      (Google Mobile Ads; `MobileAds.shared.start()` crashes without it.)
- [ ] **`SKAdNetworkItems`** — an array of `SKAdNetworkIdentifier` dicts. Copy the **current** full AdMob
      list from <https://developers.google.com/admob/ios/quick-start#update_your_infoplist> and paste it in.
      Needed for ad attribution.
- [ ] **`CFBundleURLTypes`** — register URL scheme **`bmicalculator`** (one URL Type, URL Schemes entry
      `bmicalculator`). The app's `onOpenURL` routes `bmicalculator://new-entry` → calculator and
      `bmicalculator://history` → history; the home widget's `.widgetURL` and `BMIControl` rely on it.

**Deliberately OMITTED — do not add:**
- [ ] **`NSUserTrackingUsageDescription`** — **NOT added**. We serve only non-personalized (NPA) ads, never
      request App Tracking Transparency, and never touch the IDFA. Adding it would falsely imply tracking.
- [ ] **`NSUserNotificationsUsageDescription`** — **not a real key**; do not add. Local-notification
      permission is requested at runtime via `UNUserNotificationCenter`.
- [ ] **`GADIsAdManagerApp`** — only for Ad Manager; AdMob does not need it. Skip.

---

## 5. StoreKit configuration

- [ ] In **App Store Connect**, create a **Non-Consumable** IAP with product id **`com.bmi.removeads`**
      (must equal `StoreService.removeAdsProductID`), priced at **$4.99** (see [`MONETIZATION.md`](./MONETIZATION.md)
      for the pricing/upsell/Pro-bundle rationale and the StoreKit 2 checklist). **No subscription** anywhere.
- [ ] For local testing: **File ▸ New ▸ File ▸ StoreKit Configuration File** (e.g. `Products.storekit`).
      Add a Non-Consumable with the **same** id `com.bmi.removeads`, a display name ("Remove Ads") and a
      price tier.
- [ ] **Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration** → select `Products.storekit` so purchases
      work in the simulator without a sandbox account.
- [ ] Purchasing flips `StoreState.isPro`; the app calls `AdsManager.setPro(true)` which suppresses the
      banner and interstitial. Verify both disappear after a test purchase.

---

## 6. Privacy manifest + hosted policy

### 6a. `PrivacyInfo.xcprivacy` (App target)
- [ ] **File ▸ New ▸ File ▸ App Privacy** → `PrivacyInfo.xcprivacy`, App target membership.
- [ ] **Tracking: `NSPrivacyTracking` = NO**, `NSPrivacyTrackingDomains` = empty (NPA ads, no ATT).
- [ ] **Collected data types** — declare what **AdMob** collects (health/BMI is on-device only and is
      **not** collected/linked/tracked, so it is **not** listed):
  - `NSPrivacyCollectedDataTypeDeviceID` — used for **Advertising**, **not linked** to identity,
    **not used for tracking**.
  - `NSPrivacyCollectedDataTypeCoarseLocation` and/or `NSPrivacyCollectedDataTypeOtherDiagnosticData`
    if the AdMob version in use declares them — cross-check the AdMob SDK's own bundled
    `PrivacyInfo.xcprivacy` and mirror only what it actually uses, all for **Advertising / Not linked /
    Not tracking**.
  - Purpose strings stay **Third-Party Advertising** / **App Functionality** — never **Tracking**.
- [ ] **Required-reason API** declarations: add `NSPrivacyAccessedAPITypes` entries that the app/SDK use —
      typically `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1` for the App Group defaults) and
      `NSPrivacyAccessedAPICategoryFileTimestamp` if flagged at validation. The bundled AdMob SDK ships its
      own manifest; you only declare the app's own usage.
- [ ] Confirm **no health data type** appears anywhere in the manifest (firewall + privacy requirement).

### 6b. Hosted privacy policy (App Store submission requires a live URL)
- [ ] Publish the real policy and set its URL in App Store Connect. The in-app link placeholder
      `https://josiahrininger.com/bmi/privacy` (in `Features/Settings/SettingsView.swift`, `AppLinks.privacyPolicy`)
      must be **replaced with the live URL** before submission. The policy must state: health data is
      on-device only, never sold/shared, never used for ads; ads are non-personalized via AdMob.

---

## 7. Build, run, and test

- [ ] Select the **`BMICalculator`** scheme + an **iOS 18+** simulator (or device). **⌘B** to build.
- [ ] First-build smoke test:
  - App launches into the tab UI (Liquid Glass tab bar appears automatically when built against the
    iOS 26 SDK; falls back gracefully on iOS 18–25).
  - Onboarding shows on first launch (gated by `@AppStorage(AppStorageKey.hasOnboarded)`), then the
    calculator.
  - Enter 215 lb @ 5'9" → BMI **31.7**, category **Obesity (class I)** band; the screening-tool
    disclaimer is visible near the result.
  - A completed calc inserts a `BMIRecord`; History tab shows the point on the Swift Charts trend.
  - With the `.storekit` config selected, buy "Remove Ads" → banner + interstitial stop appearing.
- [ ] **Widget:** add the BMI widget to the Home Screen; after a calc it should show the latest BMI /
      sparkline (the app writes `widget.recentEntries.v1` to `UserDefaults(suiteName:"group.com.jdr.BMI")`
      and calls `WidgetCenter.shared.reloadAllTimelines()`). The Control Center control deep-links via
      `bmicalculator://new-entry`.
- [ ] **Run unit tests:** **Product ▸ Test (⌘U)**, or
      `xcodebuild test -scheme BMICalculator -destination 'platform=iOS Simulator,name=iPhone 16'`.
      The Swift Testing suite covers the classifier/conversion boundary cases (all 13 pass in the
      standalone check). To exercise SwiftData without disk, use `PersistenceController.inMemory()`.

---

## 8. Known seams / TODO before ship

These are the unresolved cross-module references and per-module notes. Each module was generated in
isolation, so several symbols are **declared in one module and consumed in another** — reconcile names
on first full build.

### Compile-blocking symbol contracts to verify on first build
- [x] ✅ **RESOLVED (coherence pass 2026-06-18):** the `DS*` API consumed by Onboarding + Settings
      (`DSColor`, `DSFont`, `DSSpacing`, `DSRadius`, `DSCard`, `PrimaryGlassButton(title:systemImage:action:)`,
      `.dsCircularGlass` / `.dsCompactGlass`) is now defined in **`DesignSystem/DSCompat.swift`**, a thin
      shim mapping each name onto the real `Theme` tokens + glass primitives (Liquid Glass behind
      `#available(iOS 26.0, *)` with material fallback). Onboarding/Settings compile unchanged. Do not
      redo this; just review the bridged styling in Xcode Previews.
- [ ] **`AppStorageKey` is defined in `App/BMICalculatorApp.swift`** (owning app-config layer) and consumed
      by Onboarding/Settings. Ensure no second definition exists; keys must be exactly
      `hasOnboarded` / `unitSystem` / `healthStandard` / `weeklyReminderEnabled`
      (enum values stored as `.rawValue`).
- [x] ✅ **RESOLVED (coherence pass 2026-06-18):** `SettingsView` was reconciled to the canonical
      `StoreService`/`StoreState` API (`isProcessing` / `displayPrice` / `purchase()` / `restore()` /
      `lastErrorMessage`; `isProProductAvailable` → `displayPrice != nil`). It now injects
      `@Environment(StoreService.self)` like the app-shell paywall. No naming work remains here.
- [ ] **Calculator dependency protocols:** `CalculatorViewModel` declares local `@MainActor` protocols
      `ProState` (`var isPro`), `InterstitialPresenting` (`maybeShowInterstitial()`),
      `ReviewRequesting` (`maybePrompt()`), plus `EnvironmentValues` keys `.proState` /
      `.interstitialPresenter` / `.reviewRequester`. The concrete `StoreState` / `AdsManager` /
      `ReviewPrompter` from Services must **conform** (or be aliased). The app shell injects them and
      `CalculatorView` late-binds in `.task` via `model.lateBind(...)`.
- [x] ✅ **RESOLVED (coherence pass 2026-06-18):** `ResultCard.swift`'s duplicate `struct BMIGauge` and
      duplicate `BMICategory.bandColor` (both redeclaration errors against DesignSystem) were deleted and
      rewired to the canonical `DesignSystem/BMIGauge.swift` (`BMIGauge(bmi:category:scale:showsCenterLabel:)`)
      and `Theme.swift` `bandColor`. ResultCard keeps only its private `calcGlassCard`/`CalcGlassCard`
      helpers (no conflict). Other `Features/Calculator` files may still mirror the brand color locally —
      cosmetic, non-blocking.
- [ ] **`AppConfig` / `AppRoute` / `DeepLinkRouter` / `RootTab`** are defined in `BMICalculatorApp.swift`;
      dedupe if any other module also defines them.

### SwiftData / framework wiring (referenced unresolved imports)
- [ ] **SwiftData** (`ModelContainer` / `@Model` / `@Query` / `ModelContext`) is used by
      Features/Calculator, Features/History, `Core/BMIRecord.swift`, and `Services/PersistenceController.swift`.
      Inject the container at the app root:
      `WindowGroup { RootView() }.modelContainer(PersistenceController.shared)` (or
      `PersistenceController.makeContainer(appGroupID: "group.com.jdr.BMI")` for widget sharing).
      **`cloudKitDatabase` is `.none` in every configuration — do not change it** (health firewall).
- [ ] **Swift Charts** (`import Charts`) — used by `Features/History/TrendChart.swift`; system framework,
      auto-links. `ChartRange` (7/30/90/365) is defined in `TrendChart.swift`; dedupe if another module
      also defines a range type.
- [ ] **Two persistence files exist:** `Services/PersistenceController.swift` (this module) and the
      History module's expectation of an App-target SwiftData setup. Confirm there is exactly **one**
      `PersistenceController` / `ModelContainer` definition before shipping (the Services note flagged a
      possible duplicate).

### Widget ↔ Core/Intents seams
- [ ] Widget consumes `Core.UnitSystem`, `Core.HealthStandard`, `Core.BMICategory`,
      `Core.BMICategory.title`, `Core.BMIResult`, and `Core.BMICalculator.category(forBMI:standard:)` —
      confirm those exact signatures resolve once Core is in the widget's target/package (the widget uses
      `import Core` assuming a separate package; if Core is same-module, drop the import).
- [ ] Widget `BMIControl` currently launches via a self-contained `OpenBMICalculatorIntent`
      (`OpenURLIntent(bmicalculator://new-entry)`). If you'd rather call the **Intents** module's
      `CalculateBMIIntent` directly, repoint `ControlWidgetButton(action:)` at it and delete
      `OpenBMICalculatorIntent`.
- [ ] Align on the widget snapshot DTO: `BMIWidgetEntryData` / `BMISharedStore` and the
      `widget.recentEntries.v1` write contract are defined in the widget. **The App must implement the
      writer** (map recent `BMIRecord`s → `[BMIWidgetEntryData]`, JSON-encode, write to the App Group
      defaults, then `reloadAllTimelines()`) after each completed calc — this encoder was out of the
      widget module's scope.

### Intents / Spotlight activation (otherwise queries return empty)
- [ ] App must make a SwiftData-backed type conform to **`BMIResultProviding`** (map `BMIRecord` →
      `BMIResultEntity`, newest-first, honoring `limit`) **and** call **`BMIResultStore.configure(with:)`**
      early in launch, or Shortcuts "recent results" / id resolution return `[]`.
- [ ] `UnitSystem` gets a `@retroactive AppEnum` conformance **only** in `Intents/CalculateBMIIntent.swift` —
      ensure no other module also conforms `UnitSystem: AppEnum` (duplicate-conformance link error).
- [ ] Add a **Spotlight indexing toggle** in Settings that calls `BMIResultEntity.donate(records:)` for
      backfill and `BMIResultEntity.deleteAllDonations()` on clear-history / disable
      (domain `com.bmicalculator.results`, 90-day expiry; not iCloud-synced).
- [ ] Intent height-unit assumption: imperial height is entered as **total inches**, metric as
      **centimeters**, in the single `height` field. If you want feet+inches, add a variant using
      `BMICalculator.meters(fromFeet:inches:)`. AppEnum titles are hardcoded English — localize if needed.

### Services / monetization gating
- [ ] **Replace placeholder ad unit ids** before release: `AdUnit.prodBanner`
      (`ca-app-pub-6687613409331343/0000000000`) and `AdUnit.prodInterstitial`
      (`ca-app-pub-6687613409331343/1111111111`) with real units created under app id
      `ca-app-pub-6687613409331343~7486203316`. DEBUG already uses Google test units.
- [ ] **Do not fire an interstitial AND a review prompt on the same successful calc** — gate so they don't
      collide (prefer review when eligible, else interstitial). On each successful calc the UI should:
      (1) `ReviewPrompter.recordSuccessfulCalc()`, (2) optionally `HealthKitService.write(weightKilograms:bmi:)`,
      (3) `AdsManager.maybeShowInterstitial()`, (4) `ReviewPrompter.maybePrompt(using:)` with
      `@Environment(\.requestReview)` — gated per the previous line.
- [ ] Create `AdsManager` + `StoreService` once at the app root; on every `StoreState.isPro` change call
      `AdsManager.setPro(storeState.isPro)`. Call `StoreService.start()` and `AdsManager.start()` in `.task`
      on the root view (`AdsManager.start()` no-ops when Pro). `BannerSlot` (50pt placeholder in Calculator)
      must be replaced by the real NPA `BannerAdView` at the App layer and auto-hide when `isPro`.
- [ ] **Firewall re-check before ship:** no weight/height/BMI/HealthKit value may enter `Request`/`Extras`
      or any ad call; every request must register `Extras additionalParameters ["npa":"1"]`. Health data
      flows only to Core (compute), SwiftData (`BMIRecord`), and `HealthKitService`.

### Copy / compliance
- [ ] The full screening-tool **disclaimer** must surface near results, in History (`DisclaimerFootnote`),
      in Settings, and in Onboarding. Verify the exact required copy is present (it lives as `Disclaimer.full`).
- [ ] Keep all copy **person-first / non-judgmental** ("a person with obesity", never "you are obese").
- [ ] Replace the privacy-policy placeholder URL (see §6b) before submission.

---

### Quick definition-of-done
- [ ] App + Widget + Tests targets build under Swift 6 / iOS 18 with iOS 26 paths behind `#available`.
- [ ] HealthKit + IAP + App Group capabilities on; App Group id matches across app, widget, and code.
- [ ] All Info.plist keys present; `NSUserTrackingUsageDescription` absent.
- [ ] `.storekit` config wired; test purchase removes ads.
- [ ] `PrivacyInfo.xcprivacy` reflects AdMob only (no health), tracking = NO; live privacy-policy URL set.
- [ ] All §8 cross-module symbol mismatches reconciled; firewall verified; disclaimer surfaced everywhere.
