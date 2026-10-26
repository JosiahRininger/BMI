//
//  HistoryAndWidgetTests.swift
//  BMICalculatorTests
//
//  The free "All" range and change-since-first readout, the Pro trend widget's
//  snapshot and state, and the deep link the locked widget uses.
//

import Testing
import Foundation
@testable import BMICalculator

private let now = Date(timeIntervalSince1970: 1_800_000_000)

// MARK: - Chart range

@Suite("Chart ranges")
struct ChartRangeTests {

    @Test("All is the last option, labeled All, with no lower bound")
    func allRange() {
        #expect(ChartRange.allCases.last == .all)
        #expect(ChartRange.allCases.map(\.label) == ["7D", "30D", "90D", "1Y", "All"])
        #expect(ChartRange.all.startDate(relativeTo: now) == .distantPast)
        #expect(ChartRange.all.accessibilityLabel == "All entries")
    }

    @Test("Fixed ranges keep their calendar-day windows")
    func fixedRanges() {
        let calendar = Calendar.current
        let start = ChartRange.week.startDate(relativeTo: now)
        #expect(start == calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)))
    }

    @Test("Axis strides: fixed for fixed ranges, about five ticks for All")
    func strides() {
        #expect(ChartRange.week.axisStrideDays(spanDays: 999) == 1)
        #expect(ChartRange.year.axisStrideDays(spanDays: 999) == 60)
        #expect(ChartRange.all.axisStrideDays(spanDays: 3) == 1)
        #expect(ChartRange.all.axisStrideDays(spanDays: 40) == 14)
        #expect(ChartRange.all.axisStrideDays(spanDays: 700) == 180)
        #expect(ChartRange.all.axisStrideDays(spanDays: 5000) == 365)
    }
}

// MARK: - Change since first entry

@Suite("Change since first entry")
struct HistoryChangeTests {

    private func record(_ days: Double, _ bmi: Double) -> BMIRecord {
        BMIRecord(date: now.addingTimeInterval(days * 86_400), bmi: bmi,
                  weightKilograms: 70, heightMeters: 1.75, unitSystemRaw: "metric")
    }

    @Test("Needs two entries at different times")
    func needsTwo() {
        #expect(HistoryChange.make(from: []) == nil)
        #expect(HistoryChange.make(from: [record(0, 24)]) == nil)
        #expect(HistoryChange.make(from: [record(0, 24), record(0, 25)]) == nil)
    }

    @Test("First and latest come from dates, not input order")
    func ordering() throws {
        let change = try #require(HistoryChange.make(from: [record(30, 23.4), record(0, 24.1), record(10, 23.9)]))
        #expect(change.firstBMI == 24.1)
        #expect(change.latestBMI == 23.4)
        #expect(change.change == -0.7)
        #expect(change.formattedChange == "-0.7")
    }

    @Test("Formatting is signed, and zero has no sign")
    func formatting() throws {
        #expect(try #require(HistoryChange.make(from: [record(0, 23.0), record(5, 23.4)])).formattedChange == "+0.4")
        #expect(try #require(HistoryChange.make(from: [record(0, 23.0), record(5, 23.02)])).formattedChange == "0.0")
    }

    @Test("Non-finite entries are ignored")
    func nonFinite() throws {
        let change = try #require(HistoryChange.make(from: [record(0, .nan), record(1, 24), record(2, 23)]))
        #expect(change.firstBMI == 24)
    }
}

// MARK: - Trend widget

@Suite("Trend widget snapshot")
struct TrendWidgetTests {

    private func data(_ days: Double, _ bmi: Double) -> BMIWidgetEntryData {
        BMIWidgetEntryData(date: now.addingTimeInterval(-days * 86_400), bmi: bmi)
    }

    @Test("Keeps only the last 90 days, finite values, oldest first")
    func window() {
        let snapshot = BMISharedStore.trendSnapshot(
            from: [data(1, 24), data(100, 25), data(50, .nan), data(89, 24.5)],
            now: now
        )
        #expect(snapshot.map(\.bmi) == [24.5, 24])
    }

    @Test("Caps at the newest 120 entries")
    func cap() {
        let many = (0..<300).map { data(Double($0) * 0.25, 20 + Double($0) * 0.01) }
        let snapshot = BMISharedStore.trendSnapshot(from: many, now: now)
        #expect(snapshot.count == BMISharedStore.trendMaxEntries)
        #expect(snapshot.last?.date == now)            // the newest is kept
        #expect(snapshot == snapshot.sorted { $0.date < $1.date })
    }

    @Test("Snapshot and Pro flag round-trip through the App Group store")
    func roundTrip() {
        let name = "test.widget.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let entries = [data(3, 24.2), data(1, 24.0)]
        BMISharedStore.saveTrendEntries(entries, to: defaults)
        #expect(BMISharedStore.loadTrendEntries(from: defaults) == entries.sorted { $0.date < $1.date })
        #expect(BMISharedStore.isProUnlocked(in: defaults) == false)
        EntitlementCache(defaults: defaults).save([], entitlements: Entitlements(adsRemoved: true, pro: true))
        #expect(BMISharedStore.isProUnlocked(in: defaults))
    }

    @Test("Locked without Pro (neutral message), empty with no data, otherwise the trend")
    func states() {
        #expect(BMITrendWidgetState.make(isPro: false, pointCount: 10) == .locked)
        #expect(BMITrendWidgetState.make(isPro: false, pointCount: 0) == .locked)
        #expect(BMITrendWidgetState.make(isPro: true, pointCount: 0) == .empty)
        #expect(BMITrendWidgetState.make(isPro: true, pointCount: 1) == .trend)
    }

    @Test("The widget kind the app reloads matches the widget's own kind string")
    func kind() {
        #expect(BMISharedStore.trendWidgetKind == "BMITrendWidget")
    }
}

// MARK: - Deep links

@Suite("Pro deep link")
struct ProDeepLinkTests {

    @Test("bmicalculator://pro opens the Pro sheet; other routes still work")
    func routes() {
        #expect(AppRoute(url: URL(string: "bmicalculator://pro")!) == .pro)
        #expect(AppRoute(url: URL(string: "bmicalculator://upgrade")!) == .pro)
        #expect(AppRoute(url: URL(string: "bmicalculator://history")!) == .history)
        #expect(AppRoute(url: URL(string: "bmicalculator://new-entry")!) == .newEntry)
        #expect(AppRoute(url: URL(string: "https://pro")!) == nil)
    }

    @Test("The router opens the Pro sheet for the pro route")
    @MainActor
    func routerSheet() {
        let router = DeepLinkRouter()
        #expect(router.handle(url: URL(string: "bmicalculator://pro")!))
        #expect(router.pendingRoute == .pro)
    }
}
