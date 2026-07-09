//
//  CalculatorViewModelTests.swift
//  BMICalculatorTests
//
//  Coverage for CalculatorViewModel: unit-switch conversion (the represented
//  body must not change), input ranges, Pro/upsell derivation, and the
//  calculate() side effects — persistence + profile tagging + the
//  review-prompt-vs-interstitial gating — exercised through injected fakes.
//

import Testing
import Foundation
import SwiftData
@testable import BMICalculator

// MARK: - Fakes

@MainActor
private final class FakeProState: ProState {
    var isPro: Bool
    init(_ isPro: Bool) { self.isPro = isPro }
}

@MainActor
private final class FakeInterstitial: InterstitialPresenting {
    private(set) var shownCount = 0
    func maybeShowInterstitial() { shownCount += 1 }
}

@MainActor
private final class FakeReview: ReviewRequesting {
    private(set) var recordedCount = 0
    private(set) var promptCalls = 0
    var promptResult = false
    func recordSuccessfulCalc() { recordedCount += 1 }
    @discardableResult func maybePrompt() -> Bool { promptCalls += 1; return promptResult }
}

@MainActor
private final class FakeLog: LogRecording {
    private(set) var entryCount = 0
    func recordEntry() { entryCount += 1 }
}

// MARK: - Conversion

@Suite("CalculatorViewModel conversion")
@MainActor
struct CalculatorViewModelConversionTests {

    @Test("Defaults: metric 70 kg / 170 cm")
    func defaults() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        #expect(vm.weight == 70)
        #expect(abs(vm.weightKilograms - 70) < 0.0001)
        #expect(abs(vm.heightMeters - 1.70) < 0.0001)
    }

    @Test("Switching metric → imperial preserves the represented body (kg/m within rounding)")
    func metricToImperial() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        vm.unitSystem = .imperial
        #expect(abs(vm.weightKilograms - 70) < 0.5)   // weight rounds to whole lb
        #expect(abs(vm.heightMeters - 1.70) < 0.02)
    }

    @Test("Switching metric → stone preserves the represented body")
    func metricToStone() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        vm.unitSystem = .stone
        #expect(abs(vm.weightKilograms - 70) < 0.6)   // weight rounds to 0.1 st
        #expect(abs(vm.heightMeters - 1.70) < 0.02)
    }

    @Test("A full unit round-trip returns to the original kilograms")
    func roundTrip() {
        let vm = CalculatorViewModel(unitSystem: .metric)
        let kg0 = vm.weightKilograms
        vm.unitSystem = .imperial
        vm.unitSystem = .stone
        vm.unitSystem = .metric
        #expect(abs(vm.weightKilograms - kg0) < 0.6)
    }

    @Test("Weight ranges differ per unit system")
    func weightRanges() {
        let metric = CalculatorViewModel(unitSystem: .metric)
        let imperial = CalculatorViewModel(unitSystem: .imperial)
        let stone = CalculatorViewModel(unitSystem: .stone)
        #expect(metric.weightRange == 2...400)
        #expect(imperial.weightRange == 4...880)
        #expect(stone.weightRange == 0.5...63)
    }
}

// MARK: - Pro / upsell

@Suite("CalculatorViewModel Pro state")
@MainActor
struct CalculatorViewModelProTests {

    @Test("isPro mirrors the injected store; upsell only shows to non-Pro after a result")
    func upsell() {
        let proVM = CalculatorViewModel(store: FakeProState(true))
        #expect(proVM.isPro)
        #expect(proVM.showsUpsell == false)   // no result yet

        let freeVM = CalculatorViewModel(store: FakeProState(false))
        #expect(freeVM.isPro == false)
        #expect(freeVM.showsUpsell == false)  // still no result
        freeVM.calculate(persistingInto: nil)
        #expect(freeVM.showsUpsell)           // non-Pro + result → upsell
    }
}

// MARK: - calculate() side effects

@Suite("CalculatorViewModel calculate")
@MainActor
struct CalculatorViewModelCalculateTests {

    @Test("Produces a result, sets hasCalculated, and bumps the generation counter")
    func producesResult() {
        let vm = CalculatorViewModel()
        #expect(vm.result == nil)
        vm.calculate(persistingInto: nil)
        #expect(vm.result != nil)
        #expect(vm.hasCalculated)
        #expect(vm.resultGeneration == 1)
        vm.calculate(persistingInto: nil)
        #expect(vm.resultGeneration == 2)
    }

    @Test("Records the calc for review + log on every calculation")
    func recordsRetention() {
        let review = FakeReview()
        let log = FakeLog()
        let vm = CalculatorViewModel(reviewPrompter: review, logRecorder: log)
        vm.calculate(persistingInto: nil)
        #expect(review.recordedCount == 1)
        #expect(log.entryCount == 1)
    }

    @Test("Shows an interstitial only when no review prompt was presented")
    func reviewSuppressesInterstitial() {
        // Review prompt fired → no interstitial.
        let review = FakeReview(); review.promptResult = true
        let ads = FakeInterstitial()
        let vm = CalculatorViewModel(ads: ads, reviewPrompter: review)
        vm.calculate(persistingInto: nil)
        #expect(review.promptCalls == 1)
        #expect(ads.shownCount == 0)

        // No review prompt → interstitial allowed.
        let review2 = FakeReview(); review2.promptResult = false
        let ads2 = FakeInterstitial()
        let vm2 = CalculatorViewModel(ads: ads2, reviewPrompter: review2)
        vm2.calculate(persistingInto: nil)
        #expect(ads2.shownCount == 1)
    }

    @Test("Persists a BMIRecord to the model context")
    func persistsRecord() throws {
        let container = PersistenceController.inMemory()
        let context = container.mainContext

        let vm = CalculatorViewModel(unitSystem: .metric)
        vm.weight = 80
        vm.heightCentimeters = 180
        vm.calculate(persistingInto: context)

        let records = try context.fetch(FetchDescriptor<BMIRecord>())
        #expect(records.count == 1)
        // 80 kg / 1.8² ≈ 24.69
        #expect(abs((records.first?.bmi ?? 0) - 24.69) < 0.05)
    }

    @Test("A nil context skips persistence without affecting the in-memory result")
    func nilContextSkipsPersistence() {
        let vm = CalculatorViewModel()
        vm.calculate(persistingInto: nil)
        #expect(vm.result != nil)   // result still computed, just not saved
    }
}
