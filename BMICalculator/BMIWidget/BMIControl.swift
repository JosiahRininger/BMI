//
//  BMIControl.swift
//  BMICalculator — BMIWidget extension
//
//  A Control Center / Lock Screen control (iOS 18+) that gives the person a
//  one-tap "Calculate BMI" button. Tapping it launches the app straight into
//  a fresh calculation via the Intents module's `CalculateBMIIntent`.
//
//  Controls live in the widget extension and are surfaced from the same
//  `WidgetBundle`. This control opens the app rather than running headless,
//  because entering a measurement requires the full UI.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Launch Intent

/// Opens the app on its calculator screen, ready for a new measurement.
///
/// This is a lightweight `OpenIntent` wrapper used by the control button and
/// by App Shortcuts. The actual calculation is performed in-app by the Intents
/// module's `CalculateBMIIntent`; we keep launching and calculating separate so
/// the control reliably foregrounds the UI a person needs to enter height and
/// weight.
///
/// INTEGRATION: the App target must register the `bmicalculator` URL scheme and
/// route `bmicalculator://new-entry` to its calculator screen. If the Intents
/// module exposes `CalculateBMIIntent` as an `OpenIntent`, the control can be
/// repointed at it directly; the deep link keeps this control self-contained in
/// the meantime.
struct OpenBMICalculatorIntent: AppIntent {

    static var title: LocalizedStringResource { "Calculate BMI" }
    static var description: IntentDescription {
        IntentDescription("Opens the BMI calculator to add a new measurement.")
    }

    /// Bring the app to the foreground when this intent runs.
    static var openAppWhenRun: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult & OpensIntent {
        // Route into the calculator. `OpenURLIntent` foregrounds the app and
        // hands the URL to the scene for routing.
        let url = URL(string: "bmicalculator://new-entry")!
        return .result(opensIntent: OpenURLIntent(url))
    }
}

// MARK: - Control Widget

/// The "Calculate BMI" control for Control Center, the Lock Screen, and the
/// Action button. iOS 18+.
struct BMIControl: ControlWidget {
    static let kind = "com.jdr.BMI.control.calculate"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenBMICalculatorIntent()) {
                Label("Calculate BMI", systemImage: "figure.arms.open")
            }
        }
        .displayName("Calculate BMI")
        .description("Quickly open the BMI calculator to add a new measurement.")
    }
}
