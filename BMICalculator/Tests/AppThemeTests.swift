//
//  AppThemeTests.swift
//  BMICalculatorTests
//
//  Themes are a Pro perk that must never be mistaken for a BMI category color,
//  must default to the classic look for everyone, and must fall back cleanly
//  when Pro goes away.
//

import Testing
import Foundation
import UIKit
@testable import BMICalculator

/// Hue in degrees (0...360) and saturation of a hex color.
private func hueSaturation(_ hex: String) -> (hue: Double, saturation: Double) {
    var value: UInt64 = 0
    Scanner(string: hex.replacingOccurrences(of: "#", with: "")).scanHexInt64(&value)
    let color = UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                        green: CGFloat((value >> 8) & 0xFF) / 255,
                        blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return (Double(h) * 360, Double(s))
}

private func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
}

@Suite("App themes")
struct AppThemeTests {

    /// The category colors that carry meaning (light-mode stops from Theme.swift):
    /// healthy green, overweight amber, obesity orange, deep orange, red.
    private let categoryHexes = ["#2FAF5A", "#F2A53A", "#EE8A2E", "#E8602B", "#E23B3B"]

    @Test("Classic Blue is the default and the only free theme")
    func defaults() {
        #expect(AppTheme.standard == .classic)
        #expect(AppTheme.classic.requiresPro == false)
        for theme in AppTheme.allCases where theme != .classic {
            #expect(theme.requiresPro)
        }
    }

    @Test("Classic Blue is exactly the original brand color")
    func classicIsBrand() {
        #expect(AppTheme.classic.accentHex == "#19BEF4")
        #expect(AppTheme.classic.accentDeepHex == "#0E9BCB")
    }

    @Test("No theme accent can be mistaken for a category color (green, amber, orange, red)")
    func farFromCategoryHues() {
        for theme in AppTheme.allCases {
            for hex in [theme.accentHex, theme.accentDeepHex] {
                let accent = hueSaturation(hex)
                guard accent.saturation > 0.3 else { continue }   // neutral grays can't be confused
                for category in categoryHexes {
                    let distance = hueDistance(accent.hue, hueSaturation(category).hue)
                    #expect(distance >= 25, "\(theme) \(hex) is \(Int(distance))° from category \(category)")
                }
            }
        }
    }

    @Test("Every theme has a unique accent and a name")
    func uniqueness() {
        let accents = AppTheme.allCases.map(\.accentHex)
        #expect(Set(accents).count == accents.count)
        for theme in AppTheme.allCases {
            #expect(!theme.displayName.isEmpty)
            #expect(AppTheme(rawValue: theme.rawValue) == theme)
        }
    }
}

@Suite("Appearance store")
@MainActor
struct AppearanceStoreTests {

    private func defaults() -> UserDefaults {
        let name = "test.appearance.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Starts on Classic Blue")
    func startsClassic() {
        let store = AppearanceStore(defaults: defaults())
        #expect(store.theme == .classic)
        #expect(store.chosen == .classic)
    }

    @Test("A Pro theme can't be chosen without Pro")
    func refusesWithoutPro() {
        let store = AppearanceStore(defaults: defaults())
        store.choose(.violet, hasPro: false)
        #expect(store.theme == .classic)
        store.choose(.classic, hasPro: false)   // the free theme is always fine
        #expect(store.theme == .classic)
    }

    @Test("With Pro, the choice applies and persists across launches")
    func persistsWithPro() {
        let suite = defaults()
        let store = AppearanceStore(defaults: suite)
        store.choose(.indigo, hasPro: true)
        #expect(store.theme == .indigo)
        let relaunched = AppearanceStore(defaults: suite)
        #expect(relaunched.chosen == .indigo)
        relaunched.enforceEntitlement(hasPro: true)
        #expect(relaunched.theme == .indigo)
    }

    @Test("Losing Pro (a refund) draws Classic but remembers the choice for later")
    func revertsAndRemembers() {
        let store = AppearanceStore(defaults: defaults())
        store.choose(.orchid, hasPro: true)
        store.enforceEntitlement(hasPro: false)
        #expect(store.theme == .classic)
        #expect(store.chosen == .orchid)
        store.enforceEntitlement(hasPro: true)
        #expect(store.theme == .orchid)
    }

    @Test("Theme.brand follows the shared store")
    func brandFollowsShared() {
        let shared = AppearanceStore.shared
        let original = shared.chosen
        shared.choose(.teal, hasPro: true)
        #expect(Theme.brand == AppTheme.teal.accent)
        #expect(BMIBandPalette.brandBlue == AppTheme.teal.accent)
        shared.choose(.classic, hasPro: true)
        #expect(Theme.brand == AppTheme.classic.accent)
        shared.choose(original, hasPro: true)
    }
}
