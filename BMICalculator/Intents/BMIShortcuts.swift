//
//  BMIShortcuts.swift
//  BMICalculator
//
//  Declares App Shortcuts so people can run "Calculate my BMI" from Siri and the
//  Shortcuts app without manual setup. Provided phrases must reference
//  \(.applicationName) per AppIntents requirements.
//
//  Depends on: CalculateBMIIntent.
//

import Foundation
import AppIntents

// MARK: - BMIShortcuts

/// Surfaces the app's intents as zero-config App Shortcuts. iOS reads this
/// provider at install time and registers the natural-language phrases below.
struct BMIShortcuts: AppShortcutsProvider {

    /// Tint shown behind shortcut tiles in the Shortcuts app. Brand blue #19BEF4
    /// maps closest to the system teal/cyan tile color.
    static var shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CalculateBMIIntent(),
            phrases: [
                "Calculate my BMI in \(.applicationName)",
                "Calculate BMI in \(.applicationName)",
                "Check my BMI in \(.applicationName)",
                "What's my BMI in \(.applicationName)",
                "Work out my BMI with \(.applicationName)",
                "Body mass index in \(.applicationName)"
            ],
            shortTitle: "Calculate BMI",
            systemImageName: "figure.arms.open"
        )
    }
}
