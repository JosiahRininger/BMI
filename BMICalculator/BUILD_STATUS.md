# BMI Calculator — Rebuild Status (read me first)

_Generated 2026-06-18 in an Opus 4.8 ultracode session. This is a complete SwiftUI/iOS 26
source scaffold, **not a compiled app** — it has never been through an Xcode build (no iOS SDK
in the generating environment). It's designed to drop into an Xcode 26 project per
`INTEGRATION.md`. Below is exactly what's verified, what was fixed, and what's left._

---

## ✅ Verified (compiled + runtime-tested here)

- **Core engine is provably correct.** The Foundation-only engine (`Core/UnitSystem`,
  `HealthStandard`, `BMICategory`, `BMIResult`, `BMICalculator`) compiles with `swiftc` and passes
  **all 14 boundary tests**:
  - CDC/standard: 18.5→healthy, 25.0→overweight, 30.0→obesity I, 35.0→II, 40.0→III (half-open, exact).
  - WHO-Asian: 23.0→overweight, 27.5→obesity I.
  - Sample: 215 lb / 5'9" → **BMI 31.7 = Obesity (class 1)**.
  - The original boundary bug (24.95→"Obese", 18.5→"Underweight") is gone.
- **6 adjacent calculators are compiled + verified** (`Core/HealthCalculators.swift`): BMR/TDEE
  (Mifflin-St Jeor + Harris-Benedict), waist-to-height (NICE NG246 bands), US Navy body-fat %,
  ideal body weight (Devine/Robinson/Hamwi/Miller), lean body mass (Boer/James/Hume), body frame
  size. All formulas asserted against known values — Mifflin 1780, Harris 1853.632, Navy 17.5%,
  Devine 70.46 kg, Boer 61.42 kg — **0 failures**.

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

## ✅ Added this session (deep-research fold-in)

From the two growth/feature research reports:

- **`Core/HealthCalculators.swift`** — the 6 verified calculators above.
- **`Features/Calculators/`** (8 files) — SwiftUI screens: `MoreMetricsView` hub +
  `TDEEView`/`BodyFatView`/`WaistHeightView`/`IdealWeightView`/`LeanMassView`/`FrameSizeView`,
  with HealthKit prefill, unit handling, and per-screen disclaimers. (Not compile-verified — SwiftUI.)
- **`Features/Share/`** (4 files) — the #1 organic-growth mechanic: an opt-in, progress-framed
  shareable card (`ShareCardView` → `ShareCardRenderer` via `ImageRenderer` → 1080×1920 PNG →
  `ShareProgressButton`/`ShareLink`). Default card shows streak + trend shape, **never** an absolute
  BMI unless the user toggles it on.
- **`Features/Streak/`** (2 files) — a shame-free `StreakService` (`@Observable`, App-Group persisted)
  + `StreakBadge`/`MilestoneCelebrationView`.
- **`GROWTH.md`** — the $0-budget organic-growth playbook (ranked mechanics, do-not-build list,
  share-card spec, stigma/compliance guardrails, 90-day rollout, + §8 external acquisition channels
  & the January featuring window).
- **`MONETIZATION.md`** — pricing ($4.99), ranked upsell placements, Pro bundle, StoreKit 2 checklist,
  revenue model. **`StoreService.swift` upgraded** with a local `isPro` cache (soft fallback for the
  iOS 26.x entitlement regression; refund still clears it).
- **Open product decision (flagged, not decided):** keep the 6 extra calculators FREE (growth lever —
  recommended) vs gate them behind Pro (revenue lever). See `MONETIZATION.md` §3.

---

## 🔬 Bug & performance audit (2026-06-18)

A read-only adversarial audit (5 finders + per-finding skeptic verify) surfaced **28 candidates → 11
confirmed**. **Fixed (9):**
- **Stale streak on the share card** — `consecutiveDayStreak` reported a lapsed streak; now anchored to today/yesterday (returns 0 otherwise).
- **Share card perf** — `ShareProgressSheet` re-rasterized the 1080×1920 image on *every* body pass; now cached in `@State`, regenerated only via `.task(id: payload)`.
- **Result-card perf** — `.id(result)` tore down + re-animated the whole `ResultCard`/gauge on a standard toggle; now keyed on a `resultGeneration` counter bumped only per real calc.
- **Swift-6 concurrency ×2** — `NotificationDelegate` now uses `MainActor.assumeIsolated` (no non-Sendable `self` capture); `AdsManager`'s `FullScreenContentDelegate` methods are `nonisolated` + `assumeIsolated`.
- **Review/interstitial modal collision** — `maybePrompt()` now returns `Bool`; the interstitial fires only when no review was shown.
- **Refund left ads off (revenue)** — `AdsManager.setPro(false)` now boots the SDK if the app launched Pro then reverted.
- **Streak milestones** — keyed on **distinct logged days** (`loggedDayCount`), so same-day calc spam can't fast-track "One week"/"One month". **Verified: 4/4 unit tests pass via `swift test`.**
- **Chart range off-by-one** — `ChartRange.startDate` anchored to start-of-day so "7D" = exactly 7 calendar days.

**Documented, still open (2 confirmed + low-sev):**
- [ ] **Milestone celebration not surfaced** — `MilestoneCelebrationView` exists but nothing presents it; wire it in `RootView` (observe `StreakService.earnedMilestones`, present on change; inject `StreakService` into the RootView preview).
- [ ] **Spotlight provider race** — `BMIResultStore.configure(with:)` installs the provider asynchronously; an early `EntityQuery` can see an empty store. Make `configure` deterministic (await provider install) before relying on Shortcuts "recent results". (Spotlight is already an unwired TODO below.)
- [ ] Low-sev: Siri `CalculateBMIIntent` ignores the chosen `HealthStandard`; `BMIResultEntity.deterministicID` can collide within one second at the same rounded BMI; `LeanMassView` can show a misleading implied-body-fat for impossible inputs.

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

> **✅ Wired this session** (symbol-verified, not yet Xcode-compiled): the **review-prompt counter**
> (`recordSuccessfulCalc()` now called on every calc via the `ReviewRequesting` protocol + adapter — the
> ratings strategy is no longer dark); the **streak + weigh-in-reminder reschedule** (new `LogRecording`
> protocol → `LogRecorderAdapter` over `StreakService` + `NotificationService`, called in
> `CalculatorViewModel.calculate()`); the **Metrics tab** (4th `RootTab` hosting `MoreMetricsView`); the
> **share card** (`ShareProgressButton` in `HistoryView`, payload built from records); and **notifications**
> (`registerCategories()` at launch + a `NotificationDelegate` routing taps/"Log now" → `bmicalculator://new-entry`).
> Still open below: widget writer, Spotlight activation, ad-unit ids, the **Settings cadence picker** (the
> `NotificationService` cadence API exists; Settings still calls the weekly convenience), the interstitial-vs-review
> collision gate, and the dedupe/preview checks.

- [ ] **Widget data writer** — the app must, after each calc, map recent `BMIRecord`s →
      `[BMIWidgetEntryData]`, JSON-encode to `UserDefaults(suiteName:"group.com.jdr.BMI")` key
      `widget.recentEntries.v1`, then `WidgetCenter.shared.reloadAllTimelines()`. (Widget reads it; writer was out of widget scope.)
- [ ] **Spotlight activation** — make a SwiftData type conform to `BMIResultProviding` and call
      `BMIResultStore.configure(with:)` at launch, else Shortcuts/Spotlight "recent results" return empty.
- [ ] **Review-prompt counter** — `ReviewPrompter.recordSuccessfulCalc()` is never called, so the
      ratings gate never advances. Call it on each successful calc (this is the ASO ratings strategy — important).
- [ ] **Interstitial vs. review collision** — gate so a single successful calc fires at most one
      (prefer review when eligible, else interstitial).
- [ ] **Replace placeholder ad unit ids** `…/0000000000` and `…/1111111111` with real units.
- [ ] Dedupe check: confirm a single `PersistenceController`/`ModelContainer`, single `AppStorageKey`,
      single `ChartRange` (flagged as possible duplicates).
- [ ] `SettingsView` `#Preview` needs all four env objects injected or it crashes at preview time (not a build error).
- [ ] **Surface the new calculators** — `MoreMetricsView` isn't reachable yet. Add a 4th `RootTab`
      (`.metrics`) wrapped in a `NavigationStack`, or push it from a `SettingsView`/`CalculatorView` row.
- [ ] **Wire the streak** — create one `StreakService` at the app root (inject via environment); call
      `streak.recordEntry()` in the successful-calc flow alongside `ReviewPrompter.recordSuccessfulCalc()`;
      show `StreakBadge` on Calculator/History and present `MilestoneCelebrationView` when
      `milestoneJustEarned()` returns non-nil. (Shares the `group.com.jdr.BMI` App Group with the widget.)
- [ ] **Wire the share card** — drop `ShareProgressButton(payload:)` into History; build the `SharePayload`
      from recent `BMIRecord`s (streakDays from `StreakService`, `recentTrend` = last N BMIs). Tag the card
      footer's App Store link with an App Store Connect campaign token (see `GROWTH.md` §6–7).
- [ ] **Verify `Features/Calculators` assumptions** — those screens reference `HealthKitService.latestPrefill()`
      and a few `Features/Calculator` internal views (`LabeledInputRow`, `UnitSystemToggle`, `WeightField`,
      `AdaptiveHeightField`, `ImperialHeight`). Confirm those symbols exist as named on first build.
- [ ] **Wire notifications** (`NotificationService` rewritten with research-backed cadence + number-free copy):
      call `registerCategories()` at launch; set a `UNUserNotificationCenterDelegate` to route the tap /
      "Log now" action to `bmicalculator://new-entry` (and `rescheduleAfterLog()` on snooze); call
      `rescheduleAfterLog()` after each saved entry; add the **cadence picker** (off / weekly / 3×-week /
      daily — weekly default) to Settings; gate the auth request behind the onboarding **soft-ask**, never cold.

### C. Strategy/content (from `ASO.md`)
- [ ] `ASO.md` markets **body-fat & calorie features that aren't built yet**. Either build them
      (research recommended US Navy body-fat + ideal-weight as the next feature — see research dimension
      "competitive"/"feature expansion") **or** soften the subtitle/keywords to avoid metadata rejection.

---

## Definition of done
App + Widget + Tests build under Swift 6 / iOS 18 (iOS 26 paths behind `#available`); capabilities +
App Group + Info.plist set; `.storekit` wired; privacy manifest + live policy URL; §B code TODOs done;
health→ad firewall verified; screening-tool disclaimer surfaced in Calculator/History/Settings/Onboarding.

See `INTEGRATION.md` for step-by-step Xcode wiring and `ASO.md` for the App Store metadata/screenshot/ratings plan.
