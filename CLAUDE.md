# BMI Calculator: working rules

The live app is `BMICalculator/` (SwiftUI, XcodeGen). `BMI-iOS/` is the retired 1.x UIKit app; leave it alone.

## Build and test
- Run `xcodegen generate` in `BMICalculator/` after adding or removing files; the `.xcodeproj` is generated.
- Ship builds use Xcode 27.1 (iOS 27.1 SDK, needed for native iPhone Duo). Xcode 26.2 still builds the project.
- Swift 5 language mode with `@MainActor`/`@Observable` throughout. Swift 6 mode hit a compiler crash; revisit after an Xcode update.
- Simulator builds need `CODE_SIGNING_ALLOWED=NO`.
- Tests are Swift Testing (`BMICalculatorTests`). `StoreServiceTests` use `SKTestSession` with `Products.storekit`, which is bundled into the test target.
- When the app hosts tests (`AppConfig.isHostingTests`), it skips its launch-time StoreKit work so it can't race the test sessions.

## Product rules
- Local-first: no accounts, no backend, no new third-party SDKs without asking.
- Monetization: one-time IAPs only. `com.bmi.removeads` ($1.99, ads only) and `com.bmi.pro` ($4.99, no ads plus the Pro features). No subscriptions, launch paywalls, countdowns, or "sale" pricing.
- Never delete, rename, or reuse `com.bmi.removeads`. Existing Remove Ads purchases must always stay ad-free.
- Remove Ads bought before `ProLaunch.cutoff` includes Pro (early supporters). The rules live in `Services/Entitlements.swift` and are unit-tested; change them only with tests.
- Never paywall anything that is free today. History, the trend chart (including All), CSV export, Apple Health, widgets, and Siri stay free.
- Ask before changing signing, bundle IDs, capabilities or entitlements, product IDs, or AdMob/ATT settings (they change the App Privacy label).

## Health and privacy
- HealthKit firewall: no weight, height, or BMI value ever reaches the ad SDK, analytics, or crash reporting. Nothing health-related is stored in iCloud.
- Health copy: BMI is a screening measure, WHO/CDC adult categories, a "check with a doctor" reminder, adults only, non-shaming tone. Say "Apple Health", never "HealthKit", in UI and listing copy.
- No em dashes in user-facing copy.

## After every change
Build, run the tests, check UI changes on a simulator (iPhone, iPad, and iPhone Duo where layout matters), and summarize what changed.
