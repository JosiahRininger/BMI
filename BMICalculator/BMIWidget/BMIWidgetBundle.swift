//
//  BMIWidgetBundle.swift
//  BMICalculator — BMIWidget extension
//
//  The extension's `@main` entry point. Bundles the home/lock-screen widget
//  and the Control Center control, and defines the widget's AppIntent-based
//  configuration.
//
//  The widget has no user-facing options: it always mirrors the BMI-cutoff
//  standard chosen in the app's Settings (baked into each entry by WidgetSync),
//  so History and the widget can never disagree. The configuration intent is
//  widget-UI only and is intentionally separate from the Intents module's
//  `CalculateBMIIntent`, which performs the actual calculation. The Control
//  widget consumes that calculation intent directly.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget Bundle

/// Registers every widget and control the extension provides.
@main
struct BMIWidgetBundle: WidgetBundle {
    var body: some Widget {
        BMIWidget()
        BMIControl()
    }
}

// MARK: - Widget Configuration Intent

/// The widget's AppIntent configuration. It intentionally exposes no options:
/// the widget always reflects the BMI-cutoff standard chosen in the app's
/// Settings (baked into each entry by `WidgetSync`), so a per-widget override
/// can't drift out of sync with History. Kept as an `AppIntentConfiguration`
/// intent (rather than a static one) so the provider stays an
/// `AppIntentTimelineProvider`.
struct BMIWidgetConfigurationIntent: WidgetConfigurationIntent {

    static var title: LocalizedStringResource { "BMI Widget" }
    static var description: IntentDescription {
        IntentDescription("Shows your latest BMI, its category, and your recent trend.")
    }

    init() {}
}
