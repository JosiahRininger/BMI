//
//  EdgeCaseTests2.swift
//  BMICalculatorTests
//
//  Second batch of edge-case coverage: the unified Spotlight id, saved-preference
//  accessors that the widget/Spotlight/intent now share, extended streak and
//  profile boundaries, and exporter content.
//

import Testing
import Foundation
import SwiftData
@testable import BMICalculator

private func near(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool { abs(a - b) < tol }

// MARK: - Deterministic Spotlight id

@Suite("Deterministic Spotlight id")
struct DeterministicIDTests {

    private let date = Date(timeIntervalSince1970: 1000)

    @Test("Id uses the integer bmi*10 suffix (matches intent donations)")
    func format() {
        #expect(BMIResultEntity.deterministicID(bmi: 24.1, date: date) == "bmi-1000-241")
        #expect(BMIResultEntity.deterministicID(bmi: 24.0, date: date) == "bmi-1000-240")
        #expect(BMIResultEntity.deterministicID(bmi: 18.5, date: date) == "bmi-1000-185")
        #expect(BMIResultEntity.deterministicID(bmi: 100.0, date: date) == "bmi-1000-1000")
    }

    @Test("Same inputs produce the same id; different BMIs differ")
    func stableAndDistinct() {
        #expect(BMIResultEntity.deterministicID(bmi: 24.1, date: date) == BMIResultEntity.deterministicID(bmi: 24.1, date: date))
        #expect(BMIResultEntity.deterministicID(bmi: 24.1, date: date) != BMIResultEntity.deterministicID(bmi: 24.2, date: date))
    }
}

// MARK: - Saved-preference accessors

@Suite("Saved preference accessors")
struct SavedPreferenceTests {

    @Test("savedStandard decodes the persisted value and falls back to standard")
    func savedStandard() {
        UserDefaults.standard.set("asian", forKey: "app.healthStandard")
        #expect(CalculatorViewModel.savedStandard == .asian)
        UserDefaults.standard.set("standard", forKey: "app.healthStandard")
        #expect(CalculatorViewModel.savedStandard == .standard)
        UserDefaults.standard.removeObject(forKey: "app.healthStandard")
        #expect(CalculatorViewModel.savedStandard == .standard)   // fallback
    }

    @Test("savedUnitSystem decodes the persisted value and falls back to metric")
    func savedUnit() {
        UserDefaults.standard.set("imperial", forKey: "app.unitSystem")
        #expect(CalculatorViewModel.savedUnitSystem == .imperial)
        UserDefaults.standard.set("stone", forKey: "app.unitSystem")
        #expect(CalculatorViewModel.savedUnitSystem == .stone)
        UserDefaults.standard.removeObject(forKey: "app.unitSystem")
        #expect(CalculatorViewModel.savedUnitSystem == .metric)
    }

    @Test("A record categorizes differently under the Asian standard at BMI 24")
    func standardAffectsCategory() {
        let record = BMIRecord(date: .now, bmi: 24, weightKilograms: 74, heightMeters: 1.75, unitSystemRaw: "metric")
        #expect(record.category(standard: .standard) == .healthy)
        #expect(record.category(standard: .asian) == .overweight)
    }
}

// MARK: - Streak extended

@Suite("Streak extended")
@MainActor
struct StreakExtendedTests {

    private let base = Date(timeIntervalSince1970: 1_700_000_000)
    private func day(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: base)! }
    private func fresh(_ suite: String) -> StreakService {
        UserDefaults().removePersistentDomain(forName: suite)
        return StreakService(appGroupID: suite)
    }

    @Test("Longest streak survives later gaps")
    func longestPreserved() {
        let s = fresh("test.streak.longest2")
        s.recordEntry(date: day(0)); s.recordEntry(date: day(1)); s.recordEntry(date: day(2)) // streak 3
        s.recordEntry(date: day(10))   // gap → current 1
        s.recordEntry(date: day(11))   // current 2
        #expect(s.currentStreak == 2)
        #expect(s.longestStreak == 3)
    }

    @Test("entriesToNextMilestone advances past the One Week badge")
    func nextAfterWeek() {
        let s = fresh("test.streak.afterweek")
        for n in 0..<7 { s.recordEntry(date: day(n)) }
        #expect(s.loggedDayCount == 7)
        #expect(s.nextMilestone?.threshold == 30)
        #expect(s.entriesToNextMilestone == 23)   // 30 - 7
    }

    @Test("Entry count counts every entry; logged days count distinct days")
    func entryVsDayCount() {
        let s = fresh("test.streak.counts")
        s.recordEntry(date: day(0)); s.recordEntry(date: day(0)); s.recordEntry(date: day(1))
        #expect(s.entryCount == 3)
        #expect(s.loggedDayCount == 2)
    }
}

// MARK: - Profile management extended

@Suite("Profile management extended")
@MainActor
struct ProfileExtendedTests {

    private func freshStore() -> ProfileStore {
        ProfilePreferences.setActiveID(nil)
        return ProfileStore(container: PersistenceController.inMemory())
    }

    @Test("Deleting a non-active profile leaves the active pointer untouched")
    func deleteNonActiveKeepsActive() {
        let store = freshStore()
        let alex = store.addProfile(name: "Alex", isPro: true)!
        let bob = store.addProfile(name: "Bob", isPro: true)!
        store.setActive(alex.id)
        store.delete(bob)
        #expect(store.activeProfileID == alex.id)
        #expect(store.profiles.count == 2)
    }

    @Test("Free tier blocks a second profile; Pro allows it")
    func freeTierCap() {
        let store = freshStore()
        #expect(store.addProfile(name: "Two", isPro: false) == nil)
        #expect(store.profiles.count == 1)
        #expect(store.addProfile(name: "Two", isPro: true) != nil)
        #expect(store.profiles.count == 2)
    }

    @Test("A very long name is accepted and trimmed")
    func longName() {
        let store = freshStore()
        let long = String(repeating: "a", count: 200)
        let p = store.addProfile(name: "  \(long)  ", isPro: true)
        #expect(p != nil)
        #expect(p?.name.count == 200)
    }

    @Test("Whitespace-only names are rejected")
    func whitespaceRejected() {
        let store = freshStore()
        #expect(store.addProfile(name: "   \n\t ", isPro: true) == nil)
        #expect(store.profiles.count == 1)
    }
}

// MARK: - Exporter content

@Suite("Exporter content")
@MainActor
struct ExporterContentTests {

    @Test("CSV uses ISO dates and one decimal BMI, oldest first")
    func csvOrderingAndFormat() throws {
        let older = BMIRecord(date: Date(timeIntervalSince1970: 1_000), bmi: 22.04, weightKilograms: 67, heightMeters: 1.75, unitSystemRaw: "metric")
        let newer = BMIRecord(date: Date(timeIntervalSince1970: 2_000), bmi: 26.5, weightKilograms: 81, heightMeters: 1.75, unitSystemRaw: "metric")
        // Pass newest-first; exporter must sort oldest-first.
        let url = try #require(HistoryExporter.csvFileURL(records: [newer, older], standard: .standard))
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        // Row 1 is the older record; BMI rounded to 1 decimal (22.04 → 22.0).
        #expect(lines[1].contains("22.0"))
        #expect(lines[2].contains("26.5"))
    }

    @Test("A single record yields a header plus one row")
    func singleRecord() throws {
        let r = BMIRecord(date: .now, bmi: 19.0, weightKilograms: 58, heightMeters: 1.75, unitSystemRaw: "metric")
        let url = try #require(HistoryExporter.csvFileURL(records: [r], standard: .standard))
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.split(separator: "\n").count == 2)
        #expect(text.contains("\"Healthy weight\""))
    }
}
