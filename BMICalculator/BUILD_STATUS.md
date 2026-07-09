# BMI Calculator — Rebuild Status (read me first)

_Generated 2026-06-18 in an Opus 4.8 ultracode session, then taken through a real Xcode build._

> ## Scope: slimmed to a focused BMI-only app
> The app is now **BMI-only** — three tabs (**Calculator, History, Settings**). The adjacent
> calculators (body fat, TDEE/BMR, ideal weight, waist-to-height, frame size, lean mass), multiple
> profiles, custom accent themes, CSV/PDF export, the share progress card, consecutive-day streaks,
> and check-in reminder notifications were **removed** in the slim-down. Monetization is a single
> **non-personalized AdMob banner** (`npa=1`) on the free tier plus one non-consumable **Remove Ads**
> IAP (`com.bmi.removeads`) — no subscription, and no interstitial/rewarded/video ads in the shipping
> build (interstitial code exists but is dormant/off). Health data stays on device and is firewalled
> from ads.

> ## ✅ IT COMPILES, LAUNCHES, AND PASSES TESTS
> The full app was generated with `xcodegen` (`project.yml`) and **built for the iOS 26.3 simulator
> with Xcode 26.2** — `** BUILD SUCCEEDED **`. It **launches on iPhone 17** and the bundled
> **Swift Testing suite passes 115/115** (`✔ Test run with 115 tests passed`).
> Two notable workarounds: (1) the project is in **Swift 5 language mode** — Swift 6 mode hit a
> `swift-frontend` IRGen **compiler crash** (an Apple bug) on an async/actor thunk in `SettingsView`;
> the code keeps `@MainActor`/`@Observable` so runtime safety is intact. (2) `makeModelContainer`
> now **guards the App Group** (it only opens the shared store when the capability is provisioned,
> else falls back to a local store) so the app doesn't trap on an unsigned/dev build.
> To reproduce: `xcodegen generate && xcodebuild -scheme BMICalculator -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO test`.

> ## ✅ FEATURES BUILT OUT — all compiling, tests 115/115
> - **Widget + Control Center extension** — now a real `app-extension` target embedded in the app
>   (`project.yml`), compiling Core + the SwiftData-free intents via multi-target membership.
> - **Widget data writer** — `WidgetSync` snapshots the 7 most recent records to the App Group after
>   each calc (`LogRecorderAdapter`) and reloads timelines; shared store/DTO extracted to `BMISharedStore.swift`.
> - **Spotlight/Siri** — `SpotlightResultProvider` installed via `BMIResultStore.configure` at launch,
>   so "recent BMI" resolves in Spotlight/Shortcuts.
>
> **Still open — needs you, or a scoped follow-up:**
> - ✅ **AdMob — DONE (banner).** The `GoogleMobileAds` SPM package is linked (**12.14.0**). A single
>   **non-personalized** banner (`npa=1`) ships on the free tier — real unit
>   `ca-app-pub-6687613409331343/5598406572`, app ID `ca-app-pub-6687613409331343~7486203316`.
>   Interstitial code exists but is **dormant/off** in the shipping build; no rewarded/video ads.
> - ✅ **Stone weight UI (#6) — DONE.** A third `.stone` `UnitSystem` (decimal stone for weight, ft/in
>   for height) wired through Core, `CalculatorViewModel`, `InputControls`, and the `CalculateBMIIntent`.
>   Builds + 115/115 tests pass. *(Future polish: a `st + lb` two-field entry instead of decimal stone.)*
> - **Signing + capabilities** (HealthKit, In-App Purchase, App Groups `group.com.jdr.BMI`) for a device/TestFlight build.
> - **StoreKit**: create `com.bmi.removeads` at $1.99 in App Store Connect + a `.storekit` test config.
> - **App icon** asset catalog; **privacy manifest** + a live privacy-policy URL (replace the placeholder).

---

## ✅ Verified (compiled + runtime-tested here)

- **Core engine is provably correct.** The Foundation-only engine (`Core/UnitSystem`,
  `HealthStandard`, `BMICategory`, `BMIResult`, `BMICalculator`) compiles with `swiftc` and passes
  **all 14 boundary tests**:
  - CDC/standard: 18.5→healthy, 25.0→overweight, 30.0→obesity I, 35.0→II, 40.0→III (half-open, exact).
  - WHO-Asian: 23.0→overweight, 27.5→obesity I.
  - Sample: 215 lb / 5'9" → **BMI 31.7 = Obesity (class 1)**.
  - The original boundary bug (24.95→"Obese", 18.5→"Underweight") is gone.

## ✅ Fixed by two coherence passes (do NOT redo)

Parallel generation produced a few cross-module naming divergences. These are reconciled:

1. **DesignSystem API** — added `DesignSystem/DSCompat.swift` bridging the `DS*` API
   (`DSColor`, `DSFont`, `DSSpacing`, `DSRadius`, `DSCard`, `PrimaryGlassButton`,
   `.dsCircularGlass`/`.dsCompactGlass`) that Onboarding + Settings expected onto the real `Theme` tokens.
2. **Duplicate types** — removed `ResultCard.swift`'s duplicate `BMIGauge` and duplicate
   `BMICategory.bandColor` (hard redeclaration errors); rewired to the canonical DesignSystem versions.
3. **StoreKit naming** — `SettingsView` reconciled to the canonical `StoreService`/`StoreState` API.
4. **Verified already-coherent:** Calculator↔Services↔App wiring (protocol adapters + environment
   injection present); widget↔intents (`OpenBMICalculatorIntent` exists).

`INTEGRATION.md` §8 marks these ✅ RESOLVED inline.

## Removed in the slim-down (was: deep-research fold-in)

The earlier growth/feature fold-in — the 6 adjacent calculators (`Core/HealthCalculators.swift`,
`Features/Calculators/`), the shareable progress card (`Features/Share/`), streaks
(`Features/Streak/`), and the multi-feature Pro bundle — was **removed**
when the app was slimmed to BMI-only. What remains:

- **`StoreService.swift`** — the single **Remove Ads** unlock (local `isPro` cache; a refund still
  clears it, and it soft-falls-back through the iOS 26.x entitlement regression).

---

## 🔬 Bug & performance audit (2026-06-18)

A read-only adversarial audit (5 finders + per-finding skeptic verify) surfaced **28 candidates → 11
confirmed**. **Fixed** (BMI-relevant items shown; other confirmed fixes were in features — the share
card, streaks — that have since been removed):
- **Result-card perf** — `.id(result)` tore down + re-animated the whole `ResultCard`/gauge on a standard toggle; now keyed on a `resultGeneration` counter bumped only per real calc.
- **Swift-6 concurrency** — `AdsManager`'s `FullScreenContentDelegate` methods are `nonisolated` + `assumeIsolated` (no non-Sendable `self` capture).
- **Refund left ads off (revenue)** — `AdsManager.setPro(false)` now boots the SDK if the app launched ad-free (Remove Ads) then reverted.
- **Chart range off-by-one** — `ChartRange.startDate` anchored to start-of-day so "7D" = exactly 7 calendar days.

**Documented, still open:**
- [ ] **Spotlight provider race** — `BMIResultStore.configure(with:)` installs the provider asynchronously; an early `EntityQuery` can see an empty store. Make `configure` deterministic (await provider install) before relying on Shortcuts "recent results". (Spotlight is already an unwired TODO below.)
- [ ] Low-sev: Siri `CalculateBMIIntent` ignores the chosen `HealthStandard`; `BMIResultEntity.deterministicID` can collide within one second at the same rounded BMI.

## 🔧 Remaining work (yours, in Xcode) — none verifiable without a build

### A. Project assembly (mechanical — follow `INTEGRATION.md` §1–7)
- Create the Xcode 26 project + **App / Widget / Tests** targets; assign files per the
  target-membership cheat sheet (Core + widget-safe Intents need **multi-target membership** or a local
  `Core` Swift package).
- Capabilities: **HealthKit, In-App Purchase, App Groups (`group.com.jdr.BMI`)** on app **and** widget.
- Info.plist keys (HealthKit usage strings, `GADApplicationIdentifier`, `SKAdNetworkItems`,
  `bmicalculator` URL scheme). **Do not** add `NSUserTrackingUsageDescription` (NPA ads only).
- StoreKit: non-consumable `com.bmi.removeads` + a `.storekit` test config.
- `PrivacyInfo.xcprivacy` (AdMob only, health never listed) + a **live privacy-policy URL** (replace the
  `josiahrininger.com/bmi/privacy` placeholder).

### B. Real code TODOs the generators left as integration points (small, but functional gaps)

> **✅ Wired this session** (symbol-verified): the **review-prompt counter**
> (`recordSuccessfulCalc()` now called on every calc via the `ReviewRequesting` protocol + adapter — the
> ratings strategy is no longer dark). Still open below: the **widget writer**, **Spotlight activation**,
> and the **dedupe/preview checks**.

- [ ] **Widget data writer** — the app must, after each calc, map recent `BMIRecord`s →
      `[BMIWidgetEntryData]`, JSON-encode to `UserDefaults(suiteName:"group.com.jdr.BMI")` key
      `widget.recentEntries.v1`, then `WidgetCenter.shared.reloadAllTimelines()`. (Widget reads it; writer was out of widget scope.)
- [ ] **Spotlight activation** — make a SwiftData type conform to `BMIResultProviding` and call
      `BMIResultStore.configure(with:)` at launch, else Shortcuts/Spotlight "recent results" return empty.
- [ ] **Review-prompt counter** — `ReviewPrompter.recordSuccessfulCalc()` is never called, so the
      ratings gate never advances. Call it on each successful calc (this is the ASO ratings strategy — important).
- [x] ✅ **Real banner ad-unit id wired** — `ca-app-pub-6687613409331343/5598406572`
      (app ID `ca-app-pub-6687613409331343~7486203316`). The interstitial placeholder remains in code but is dormant/off.
- [ ] Dedupe check: confirm a single `PersistenceController`/`ModelContainer`, single `AppStorageKey`,
      single `ChartRange` (flagged as possible duplicates).
- [ ] `SettingsView` `#Preview` needs its environment objects injected or it crashes at preview time (not a build error).

### C. Strategy/content (from `ASO.md`)
- [ ] **Localization** (see `LOCALIZATION.md`): roadmap is EN-GB → German → Spanish (ES-MX doubles as a
      US-reach keyword hack). EN-GB needs the **stone** UI (below); the rest are metadata-only (MVL).
- [ ] **Stone weight UI (UK)** — Core conversions are done + tested (`BMICalculator.kilograms(fromStone:pounds:)`,
      `stoneAndPounds(fromKilograms:)`). Wire a 3rd weight option ("st", formatted `12 st 5 lb`) into the
      weight picker / `UnitSystem` path using those helpers; height stays ft-in or cm; BMI math is unchanged.

---

## Definition of done
App + Widget + Tests build under Swift 6 / iOS 18 (iOS 26 paths behind `#available`); capabilities +
App Group + Info.plist set; `.storekit` wired; privacy manifest + live policy URL; §B code TODOs done;
health→ad firewall verified; screening-tool disclaimer surfaced in Calculator/History/Settings/Onboarding.

See `INTEGRATION.md` for step-by-step Xcode wiring and `ASO.md` for the App Store metadata/screenshot/ratings plan.
