//
//  TrendWidgetRenderTests.swift
//  BMICalculatorTests
//
//  Renders the Pro trend widget's view (compiled into the tests from
//  BMIWidget/BMITrendWidget.swift) in every state and checks it draws real
//  content, so a broken chart or layout can't ship unnoticed.
//

import Testing
import SwiftUI
import UIKit
@testable import BMICalculator

/// The widget file links to the deep links the widget bundle defines; the tests
/// supply the same URLs.
enum BMIWidgetDeepLink {
    static let newEntry = URL(string: "bmicalculator://new-entry")!
    static let history = URL(string: "bmicalculator://history")!
    static let pro = URL(string: "bmicalculator://pro")!
}

@Suite("Trend widget rendering")
@MainActor
struct TrendWidgetRenderTests {

    private let mediumSize = CGSize(width: 338, height: 158)
    private let largeSize = CGSize(width: 338, height: 354)

    /// Renders the view and returns how many distinct gray levels it drew
    /// (a blank or failed render has one or two).
    private func render(_ entry: BMITrendEntry, size: CGSize) throws -> (image: UIImage, levels: Int) {
        let renderer = ImageRenderer(content: BMITrendWidgetView(entry: entry)
            .frame(width: size.width, height: size.height)
            .background(Color.white))
        renderer.scale = 2
        let image = try #require(renderer.uiImage)
        let cg = try #require(image.cgImage)
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (image, Set(pixels.map { $0 / 8 }).count)
    }

    @Test("The trend state draws the chart and numbers at both sizes")
    func trendDraws() throws {
        for size in [mediumSize, largeSize] {
            let result = try render(.sample(), size: size)
            #expect(result.image.size == size)
            #expect(result.levels > 8, "trend at \(size) looks blank (\(result.levels) levels)")
        }
    }

    @Test("Line-only mode (numbers hidden) still draws the line")
    func lineOnlyDraws() throws {
        #expect(try render(.sample(showsNumbers: false), size: mediumSize).levels > 4)
    }

    @Test("Empty and locked states draw their message")
    func messagesDraw() throws {
        let empty = BMITrendEntry(date: .now, points: [], isPro: true, showsNumbers: true)
        let locked = BMITrendEntry(date: .now, points: BMITrendEntry.sample().points, isPro: false, showsNumbers: true)
        #expect(try render(empty, size: mediumSize).levels > 2)
        #expect(try render(locked, size: mediumSize).levels > 2)
    }

    @Test("A single entry renders without a degenerate chart domain")
    func singlePoint() throws {
        let one = BMITrendEntry(date: .now, points: [BMIWidgetEntryData(date: .now, bmi: 23.4)],
                                isPro: true, showsNumbers: true)
        #expect(try render(one, size: mediumSize).levels > 4)
    }

    @Test("The gallery sample is gentle: no net direction and within one range")
    func neutralSample() {
        let values = BMITrendEntry.sample().points.map { $0.bmi }
        let spread = (values.max() ?? 0) - (values.min() ?? 0)
        #expect(spread < 1)
        #expect(abs((values.last ?? 0) - (values.first ?? 0)) < 0.5)
        #expect(Set(values.map { BMICalculator.category(forBMI: $0, standard: .standard) }).count == 1)
    }
}
