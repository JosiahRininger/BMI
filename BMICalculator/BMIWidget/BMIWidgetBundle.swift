//
//  BMIWidgetBundle.swift
//  BMICalculator — BMIWidget extension
//
//  The extension's `@main` entry point. Bundles the home/lock-screen widget
//  and the Control Center control, and defines the widget's AppIntent-based
//  configuration (the per-widget health-standard picker).
//
//  This configuration intent is widget-UI only and is intentionally separate
//  from the Intents module's `CalculateBMIIntent`, which performs the actual
//  calculation. The Control widget consumes that calculation intent directly.
//

import WidgetKit
import SwiftUI
import AppIntents
import Core

// MARK: - Widget Bundle

/// Registers every widget and control the extension provides.
@main
struct BMIWidgetBundle: WidgetBundle {
    var body: some Widget {
        BMIWidget()
        BMIControl()
    }
}

// MARK: - Configurable Health Standard

/// AppIntents-facing mirror of `Core.HealthStandard` so it can appear in the
/// widget's edit sheet. Kept in lockstep with the Core enum's raw values.
enum HealthStandardAppEnum: String, AppEnum {
    case standard
    case asian

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "BMI standard"
    }

    static var caseDisplayRepresentations: [HealthStandardAppEnum: DisplayRepresentation] {
        [
            .standard: DisplayRepresentation(
                title: "Universal (WHO/CDC)",
                subtitle: "18.5 / 25 / 30 cutoffs"
            ),
            .asian: DisplayRepresentation(
                title: "Asian action points (WHO)",
                subtitle: "18.5 / 23 / 27.5 cutoffs"
            )
        ]
    }

    /// Bridge to the Core engine type.
    var core: HealthStandard {
        HealthStandard(rawValue: rawValue) ?? .standard
    }
}

// MARK: - Widget Configuration Intent

/// Per-widget configuration: lets the person choose which BMI cutoffs the
/// widget uses when labelling their category. Does not perform any calculation.
struct BMIWidgetConfigurationIntent: WidgetConfigurationIntent {

    static var title: LocalizedStringResource { "BMI Widget" }
    static var description: IntentDescription {
        IntentDescription("Choose which BMI standard the widget uses to label your category.")
    }

    @Parameter(title: "BMI standard", default: .standard)
    var standard: HealthStandardAppEnum

    init() {}

    init(standard: HealthStandardAppEnum) {
        self.standard = standard
    }

    /// Convenience accessor mapping the configured choice to the Core type.
    var healthStandard: HealthStandard { standard.core }
}
