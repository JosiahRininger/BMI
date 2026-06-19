//
//  SharePayload.swift
//  BMICalculator — Features/Share
//
//  A plain value snapshot describing what the shareable progress card should
//  render. Deliberately free of SwiftData / HealthKit imports so the renderer
//  stays a pure function of its input (and is easy to preview/test).
//
//  Privacy/stigma rule: the card is PROGRESS-framed. The absolute BMI number is
//  only included when the user explicitly opts in (`includeNumber`), which
//  defaults OFF everywhere it is constructed.
//

import Foundation

public struct SharePayload: Hashable, Sendable {
    /// Consecutive-day logging streak.
    public var streakDays: Int
    /// Total recorded entries (drives milestone copy).
    public var entryCount: Int
    /// Recent BMI values, oldest → newest, for the sparkline. Never labeled with
    /// absolute numbers unless `includeNumber` is true.
    public var recentTrend: [Double]
    /// Human label for the trend window, e.g. "Last 30 days".
    public var dateRangeText: String

    /// Opt-in: include the actual BMI number + category on the card. Default OFF.
    public var includeNumber: Bool
    public var latestRoundedBMI: Double?
    public var latestCategoryTitle: String?

    public init(streakDays: Int,
                entryCount: Int,
                recentTrend: [Double],
                dateRangeText: String,
                includeNumber: Bool = false,
                latestRoundedBMI: Double? = nil,
                latestCategoryTitle: String? = nil) {
        self.streakDays = streakDays
        self.entryCount = entryCount
        self.recentTrend = recentTrend
        self.dateRangeText = dateRangeText
        self.includeNumber = includeNumber
        self.latestRoundedBMI = latestRoundedBMI
        self.latestCategoryTitle = latestCategoryTitle
    }

    /// A short, non-judgmental progress headline derived from the trend shape.
    /// Speaks to consistency/effort, never to weight as good/bad.
    public var progressHeadline: String {
        if streakDays >= 2 { return "\(streakDays)-day check-in streak" }
        if entryCount >= 2 { return "\(entryCount) check-ins logged" }
        return "Tracking my health"
    }

    public static var preview: SharePayload {
        SharePayload(streakDays: 12,
                     entryCount: 34,
                     recentTrend: [27.1, 26.8, 26.9, 26.4, 26.1, 25.8, 25.6, 25.3],
                     dateRangeText: "Last 30 days")
    }
}
