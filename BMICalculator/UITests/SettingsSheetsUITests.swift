//
//  SettingsSheetsUITests.swift
//  BMICalculatorUITests
//
//  Regression tests for 2.1's "See Pro closes itself the first time" bug. A
//  `.sheet` attached to a Section inside a Form is copied onto every row, so
//  the first tap starts several presenters racing and SwiftUI dismisses the
//  sheet about a second later. Each test cold-launches (the bug only shows on
//  the first presentation per launch), taps once, and checks the sheet is
//  still up a few seconds later.
//

import XCTest

final class SettingsSheetsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-app.hasOnboarded", "YES"]
        app.launch()
    }

    func testSeeProStaysUpOnFirstTap() throws {
        openSettings()
        let seePro = scrollTo(app.buttons["See Pro"])
        seePro.tap()

        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 5), "The Pro sheet didn't appear, or closed by itself")
        assertStillUp(notNow, "The Pro sheet closed by itself")

        notNow.tap()
        XCTAssertTrue(notNow.waitForNonExistence(timeout: 5), "Not now didn't close the Pro sheet")
    }

    func testMedicalDisclaimerStaysUpOnFirstTap() throws {
        openSettings()
        scrollTo(app.buttons["Medical disclaimer"]).tap()

        let title = app.staticTexts["About BMI"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The disclaimer sheet didn't appear, or closed by itself")
        assertStillUp(title, "The disclaimer sheet closed by itself")
    }

    func testPrivacyPolicyStaysUpOnFirstTap() throws {
        openSettings()
        let row = scrollTo(app.buttons["Privacy Policy"])
        row.tap()

        // The in-app Safari view covers Settings, so the row stops being hittable.
        let covered = NSPredicate(format: "hittable == false")
        let appeared = XCTNSPredicateExpectation(predicate: covered, object: row)
        XCTAssertEqual(XCTWaiter.wait(for: [appeared], timeout: 5), .completed,
                       "The privacy policy sheet didn't appear, or closed by itself")
        Thread.sleep(forTimeInterval: 3)
        XCTAssertFalse(row.isHittable, "The privacy policy sheet closed by itself")
    }

    // MARK: Helpers

    private func openSettings() {
        // A tab bar button on iPhone; a tab rail button on iPad and iPhone Duo.
        let inTabBar = app.tabBars.buttons["Settings"]
        let tab = inTabBar.waitForExistence(timeout: 30)
            ? inTabBar
            : app.buttons.matching(identifier: "Settings").firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "No Settings tab")
        // A loaded simulator can drop a tap, so retry the tab switch. (Never
        // retry the tap under test: the second tap always worked in the bug.)
        let title = app.navigationBars["Settings"]
        for _ in 0..<3 where !title.exists {
            tab.tap()
            _ = title.waitForExistence(timeout: 10)
        }
        XCTAssertTrue(title.exists, "Couldn't open Settings")
    }

    /// Scrolls Settings until the element can be tapped (a Form doesn't create
    /// offscreen rows), then lets the scroll settle so the tap isn't swallowed
    /// by deceleration.
    @discardableResult
    private func scrollTo(_ element: XCUIElement) -> XCUIElement {
        _ = app.navigationBars["Settings"].waitForExistence(timeout: 10)
        var swipes = 0
        while !(element.exists && element.isHittable) && swipes < 10 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "\(element) not found")
        Thread.sleep(forTimeInterval: 1.5)
        return element
    }

    /// The broken build dismissed the sheet 1.5 to 4 seconds after it appeared.
    private func assertStillUp(_ element: XCUIElement, _ message: String) {
        for _ in 0..<3 {
            Thread.sleep(forTimeInterval: 1.5)
            XCTAssertTrue(element.exists, message)
        }
    }
}
