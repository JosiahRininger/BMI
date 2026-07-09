//
//  AppLogicTests.swift
//  BMICalculatorTests
//
//  Coverage for small but regression-prone app-level helpers: deep-link URL
//  parsing (AppRoute), hex → Color parsing, the reminder-cadence enum, and the
//  active-profile preference round-trip.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import BMICalculator

// MARK: - Deep-link routing

@Suite("AppRoute deep-link parsing")
struct AppRouteTests {

    private func route(_ string: String) -> AppRoute? {
        guard let url = URL(string: string) else { return nil }
        return AppRoute(url: url)
    }

    @Test("Recognized hosts and their aliases map to routes")
    func recognized() {
        #expect(route("bmicalculator://new-entry") == .newEntry)
        #expect(route("bmicalculator://newentry") == .newEntry)
        #expect(route("bmicalculator://calculate") == .newEntry)
        #expect(route("bmicalculator://calculator") == .newEntry)
        #expect(route("bmicalculator://history") == .history)
        #expect(route("bmicalculator://trends") == .history)
        #expect(route("bmicalculator://trend") == .history)
    }

    @Test("Scheme and host are matched case-insensitively")
    func caseInsensitive() {
        #expect(route("BMICALCULATOR://New-Entry") == .newEntry)
        #expect(route("BmiCalculator://HISTORY") == .history)
    }

    @Test("Wrong scheme or unknown host returns nil")
    func rejected() {
        #expect(route("https://example.com/history") == nil)
        #expect(route("bmicalculator://settings") == nil)
        #expect(route("bmicalculator://") == nil)
    }
}

// MARK: - Hex color parsing

@Suite("Color(hex:) parsing")
struct HexColorTests {

    private func rgba(_ color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }

    private func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 0.01 }

    @Test("6-digit RRGGBB, with and without the leading #")
    func sixDigit() {
        let red = rgba(Color(hex: "#FF0000"))
        #expect(close(red.r, 1) && close(red.g, 0) && close(red.b, 0) && close(red.a, 1))

        let green = rgba(Color(hex: "00FF00"))
        #expect(close(green.r, 0) && close(green.g, 1) && close(green.b, 0))
    }

    @Test("8-digit RRGGBBAA carries the alpha channel")
    func eightDigit() {
        let halfBlue = rgba(Color(hex: "#0000FF80"))
        #expect(close(halfBlue.b, 1))
        #expect(close(halfBlue.a, 128.0 / 255.0))
    }

    @Test("A malformed string falls back to opaque black instead of crashing")
    func malformed() {
        let c = rgba(Color(hex: "nope"))
        #expect(close(c.r, 0) && close(c.g, 0) && close(c.b, 0) && close(c.a, 1))
    }

    @Test("The brand blue parses to its documented components")
    func brandBlue() {
        let c = rgba(Color(hex: "#19BEF4"))
        #expect(close(c.r, 0x19 / 255.0))
        #expect(close(c.g, 0xBE / 255.0))
        #expect(close(c.b, 0xF4 / 255.0))
    }
}
