//
//  AppearanceStore.swift
//  BMICalculator — Services
//
//  Owns the person's chosen accent theme (a BMI Pro perk). It persists the
//  selection and, crucially, mirrors it into `Theme.currentAccent` so the
//  app-wide `Theme.brand` tokens resolve to the chosen palette. Views that want
//  to recolor *immediately* on change observe this `@Observable` store and read
//  `theme.accent` (e.g. the root `.tint`); everything else picks up the new
//  accent on its next render.
//
//  Entitlement: only `.classic` is free. If Pro is lost (refund/expired family
//  share), `enforceEntitlement(isPro:)` reverts to the free default so a
//  non-Pro person never keeps a paid palette.
//

import SwiftUI

@MainActor
@Observable
final class AppearanceStore {

    /// The active accent palette. Writing it persists the choice and updates the
    /// global `Theme.currentAccent` so `Theme.brand` follows immediately.
    var theme: AppTheme {
        didSet {
            guard theme != oldValue else { return }
            Theme.currentAccent = theme
            UserDefaults.standard.set(theme.rawValue, forKey: AppStorageKey.appTheme)
        }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: AppStorageKey.appTheme)
        let initial = raw.flatMap(AppTheme.init(rawValue:)) ?? .free
        self.theme = initial
        // Mirror into the global up front so the very first render is themed.
        Theme.currentAccent = initial
    }

    /// Reverts to the free palette if a Pro theme is selected but Pro isn't
    /// owned. Call when entitlement is known and whenever it changes.
    func enforceEntitlement(isPro: Bool) {
        if !isPro, theme.isPro {
            theme = .free
        }
    }
}
