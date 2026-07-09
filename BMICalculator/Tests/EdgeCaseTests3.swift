//
//  EdgeCaseTests3.swift
//  BMICalculatorTests
//
//  Third batch: a few more routing / hex-parsing boundaries.
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import BMICalculator

private func close(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) < tol }

// MARK: - Routing & hex extras

@Suite("Routing and hex extras")
struct RoutingHexExtraTests {

    @Test("Triple-slash and host forms both route")
    func tripleSlash() {
        #expect(AppRoute(url: URL(string: "bmicalculator:///history")!) == .history)
        #expect(AppRoute(url: URL(string: "bmicalculator://history")!) == .history)
    }

    @Test("A 3-digit hex is unsupported and falls back to black")
    func threeDigitHex() {
        var r: CGFloat = 1, g: CGFloat = 1, b: CGFloat = 1, a: CGFloat = 0
        UIColor(Color(hex: "#FFF")).getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(close(Double(r), 0) && close(Double(g), 0) && close(Double(b), 0))
        #expect(close(Double(a), 1))
    }

    @Test("Hex parsing ignores surrounding whitespace")
    func whitespaceHex() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(Color(hex: "  #FF0000  ")).getRed(&r, green: &g, blue: &b, alpha: &a)
        #expect(close(Double(r), 1) && close(Double(g), 0) && close(Double(b), 0))
    }
}
