//
//  AppearanceStore.swift
//  BMICalculator — Services
//
//  Owns the chosen accent theme (a Pro feature) and persists it. `Theme.brand`
//  reads `AppearanceStore.shared.theme`, and because this store is
//  `@Observable`, every view that draws with `Theme.brand` re-renders the
//  moment the theme changes. No view needs a parameter or an environment value.
//
//  Entitlement: only `.classic` is free. If Pro goes away (a refund), the
//  theme reverts to the default through `enforceEntitlement(hasPro:)`, and
//  the person's choice is remembered so it comes back if Pro does.
//

import SwiftUI

@MainActor
@Observable
final class AppearanceStore {

    /// The single app-wide instance `Theme.brand` reads.
    static let shared = AppearanceStore()

    static let defaultsKey = "app.theme"

    /// The theme currently drawn.
    private(set) var theme: AppTheme

    /// The theme the person chose, even if it's not drawn right now (Pro not
    /// yet known, or lost to a refund).
    private(set) var chosen: AppTheme

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.string(forKey: Self.defaultsKey).flatMap(AppTheme.init(rawValue:)) ?? .standard
        chosen = saved
        // Draw the saved choice right away; `enforceEntitlement` corrects it once
        // the purchase state is known, which avoids a color flash for Pro owners.
        theme = saved
    }

    /// Chooses a theme. Callers gate Pro themes in the UI; this also refuses a
    /// Pro theme without Pro so a stray call can't unlock one.
    func choose(_ newTheme: AppTheme, hasPro: Bool) {
        guard !newTheme.requiresPro || hasPro else { return }
        chosen = newTheme
        theme = newTheme
        defaults.set(newTheme.rawValue, forKey: Self.defaultsKey)
    }

    /// Draws the chosen theme if it's allowed, otherwise the default. Call when
    /// entitlements become known and whenever they change.
    func enforceEntitlement(hasPro: Bool) {
        let allowed = !chosen.requiresPro || hasPro
        theme = allowed ? chosen : .standard
    }
}
