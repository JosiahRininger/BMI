//
//  ScreenshotHarness.swift
//  BMICalculator
//
//  DEBUG-only launch arguments that put the app into a fixed state for
//  localization QA and App Store screenshots. Compiled out of Release builds,
//  so nothing here can reach a customer.
//
//    -SeedScreenshots 1          Replace history with a fixed year of entries,
//                                treat Pro as owned, and skip launch-time
//                                StoreKit and ad work. Required by the others.
//    -screenshotTab history      Open on calculator | history | settings.
//    -screenshotCalculate 1      Show a result for the saved body on launch
//                                (not saved to history).
//    -screenshotScroll bottom    Scroll the calculator to the end of the result.
//    -screenshotRange 30D        History chart range: 7D, 30D, 90D, 1Y or All.
//    -screenshotSheet pro        Present pro | disclaimer.
//    -screenshotOnboardingPage result
//                                Open onboarding on result | connect (with
//                                -app.hasOnboarded NO).
//    -screenshotTier free        free | removeads | pro (the default). The
//                                first two show the Pro offers and upsells.
//                                No ads load either way.
//
//  Once the requested state is on screen the app posts the Darwin notification
//  `com.jdr.BMI.screenshot.ready`, so a script can wait for it with
//  `simctl spawn <udid> notifyutil -1 com.jdr.BMI.screenshot.ready`.
//
//  The body itself comes from the regular preference keys, passed the same way:
//  -app.hasOnboarded YES -app.unitSystem metric
//  -app.lastWeightKilograms "<real>70</real>" -app.lastHeightMeters "<real>1.75</real>"
//  (the body keys need the plist form: a bare number arrives as a string).
//

#if DEBUG
import Foundation
import SwiftData

enum ScreenshotHarness {

    /// Posts the "state is on screen" notification after a short settle, then
    /// once a second for a minute, so a waiter that registers late (simctl
    /// spawn is slow on a busy Mac) still hears it.
    @MainActor
    static func markReady(after delay: Duration = .milliseconds(1200)) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            for _ in 0..<60 {
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName("com.jdr.BMI.screenshot.ready" as CFString), nil, nil, true)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private static var defaults: UserDefaults { .standard }

    /// The harness is on only when `-SeedScreenshots` is passed.
    static var isActive: Bool { defaults.bool(forKey: "SeedScreenshots") }

    static var tab: RootTab? {
        guard isActive else { return nil }
        switch defaults.string(forKey: "screenshotTab")?.lowercased() {
        case "calculator": return .calculator
        case "history": return .history
        case "settings": return .settings
        default: return nil
        }
    }

    static var calculates: Bool { isActive && defaults.bool(forKey: "screenshotCalculate") }

    static var scrollsToResultBottom: Bool {
        isActive && defaults.string(forKey: "screenshotScroll")?.lowercased() == "bottom"
    }

    static var range: ChartRange? {
        guard isActive else { return nil }
        switch defaults.string(forKey: "screenshotRange")?.uppercased() {
        case "7D": return .week
        case "30D": return .month
        case "90D": return .quarter
        case "1Y": return .year
        case "ALL": return .all
        default: return nil
        }
    }

    /// `-screenshotOnboardingPage result|connect`: the onboarding page to open
    /// on (as the page's raw value). Pair with `-app.hasOnboarded NO`.
    static var onboardingPage: Int? {
        guard isActive else { return nil }
        switch defaults.string(forKey: "screenshotOnboardingPage")?.lowercased() {
        case "result": return 1
        case "connect": return 2
        default: return nil
        }
    }

    static var sheet: String? {
        isActive ? defaults.string(forKey: "screenshotSheet")?.lowercased() : nil
    }

    static var entitlements: Entitlements {
        switch defaults.string(forKey: "screenshotTier")?.lowercased() {
        case "free": return .none
        case "removeads": return Entitlements(adsRemoved: true)
        default: return Entitlements(adsRemoved: true, pro: true)
        }
    }

    /// Replaces all history with a fixed, gently improving year of entries:
    /// weekly for the last two months, then every few weeks back to a year ago,
    /// all for the saved height (or 1.75 m).
    @MainActor
    static func seedHistory(into container: ModelContext) {
        try? container.delete(model: BMIRecord.self)
        let height = defaults.double(forKey: AppStorageKey.lastHeightMeters)
        let meters = height > 0 ? height : 1.75
        let unit = defaults.string(forKey: AppStorageKey.unitSystem) ?? UnitSystem.metric.rawValue
        // (days ago, BMI). Ends at 23.0 today; the last 30 days read 23.9 to 23.0.
        let series: [(Int, Double)] = [
            (364, 27.4), (330, 27.1), (300, 26.8), (270, 26.2), (240, 25.9),
            (210, 25.6), (180, 25.2), (150, 25.4), (120, 24.9), (90, 24.6),
            (70, 24.4), (56, 24.8), (42, 24.3), (35, 24.1), (28, 23.9),
            (21, 24.8), (14, 23.4), (7, 23.9), (0, 23.0),
        ]
        let now = Date()
        for (daysAgo, bmi) in series {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            container.insert(BMIRecord(
                date: date.addingTimeInterval(-60 * 5),
                bmi: bmi,
                weightKilograms: bmi * meters * meters,
                heightMeters: meters,
                unitSystemRaw: unit
            ))
        }
        try? container.save()
    }
}
#endif

#if DEBUG
import SwiftUI

extension View {
    /// Scrolls the calculator to the end of the result card once it appears
    /// when `-screenshotScroll bottom` is passed; otherwise does nothing.
    /// `resultID` is the card's `.id` (the view model's result generation).
    @ViewBuilder
    func screenshotScrollToResultBottom(resultID: Int) -> some View {
        if ScreenshotHarness.scrollsToResultBottom {
            ScrollViewReader { proxy in
                task(id: resultID) {
                    guard resultID > 0 else { return }
                    try? await Task.sleep(for: .milliseconds(1200))
                    proxy.scrollTo(resultID, anchor: .bottom)
                    ScreenshotHarness.markReady()
                }
            }
        } else {
            self
        }
    }
}
#endif
