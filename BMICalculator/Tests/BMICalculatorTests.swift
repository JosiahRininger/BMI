//
//  BMICalculatorTests.swift
//  BMICalculatorTests
//
//  Boundary-focused tests for the Core engine using the Swift Testing
//  framework. Category boundaries are half-open: a value exactly on a
//  boundary belongs to the HIGHER category.
//

import Testing
import Foundation
import SwiftData
@testable import BMICalculator

// MARK: - Standard category boundaries

@Suite("Standard category boundaries")
struct StandardCategoryBoundaryTests {

    @Test("Just below 18.5 is underweight")
    func underweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 18.49) == .underweight)
    }

    @Test("Exactly 18.5 is healthy")
    func healthyLowerEdge() {
        #expect(BMICalculator.category(forBMI: 18.5) == .healthy)
    }

    @Test("Just below 25 is healthy")
    func healthyUpperEdge() {
        #expect(BMICalculator.category(forBMI: 24.99) == .healthy)
    }

    @Test("Exactly 25.0 is overweight")
    func overweightLowerEdge() {
        #expect(BMICalculator.category(forBMI: 25.0) == .overweight)
    }

    @Test("Just below 30 is overweight")
    func overweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 29.99) == .overweight)
    }

    @Test("Exactly 30.0 is obesity class 1")
    func obesityILowerEdge() {
        #expect(BMICalculator.category(forBMI: 30.0) == .obesityI)
    }

    @Test("Just below 35 is obesity class 1")
    func obesityIUpperEdge() {
        #expect(BMICalculator.category(forBMI: 34.99) == .obesityI)
    }

    @Test("Exactly 35.0 is obesity class 2")
    func obesityIILowerEdge() {
        #expect(BMICalculator.category(forBMI: 35.0) == .obesityII)
    }

    @Test("Just below 40 is obesity class 2")
    func obesityIIUpperEdge() {
        #expect(BMICalculator.category(forBMI: 39.99) == .obesityII)
    }

    @Test("Exactly 40.0 is obesity class 3")
    func obesityIIILowerEdge() {
        #expect(BMICalculator.category(forBMI: 40.0) == .obesityIII)
    }

    @Test("Well above 40 is obesity class 3")
    func obesityIIIDeep() {
        #expect(BMICalculator.category(forBMI: 55.2) == .obesityIII)
    }

    @Test("Zero BMI is underweight")
    func zeroIsUnderweight() {
        #expect(BMICalculator.category(forBMI: 0) == .underweight)
    }
}

// MARK: - Asian (WHO action point) category boundaries

@Suite("Asian category boundaries")
struct AsianCategoryBoundaryTests {

    @Test("Just below 18.5 is underweight")
    func underweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 18.49, standard: .asian) == .underweight)
    }

    @Test("Exactly 18.5 is healthy")
    func healthyLowerEdge() {
        #expect(BMICalculator.category(forBMI: 18.5, standard: .asian) == .healthy)
    }

    @Test("Just below 23 is healthy")
    func healthyUpperEdge() {
        #expect(BMICalculator.category(forBMI: 22.9, standard: .asian) == .healthy)
    }

    @Test("Exactly 23.0 is overweight")
    func overweightLowerEdge() {
        #expect(BMICalculator.category(forBMI: 23.0, standard: .asian) == .overweight)
    }

    @Test("Just below 27.5 is overweight")
    func overweightUpperEdge() {
        #expect(BMICalculator.category(forBMI: 27.4, standard: .asian) == .overweight)
    }

    @Test("Exactly 27.5 is obesity class 1")
    func obesityILowerEdge() {
        #expect(BMICalculator.category(forBMI: 27.5, standard: .asian) == .obesityI)
    }

    @Test("Asian standard never produces class 2 or 3")
    func asianNeverHigherClasses() {
        // Even a very high BMI maps to obesityI under the Asian overlay.
        #expect(BMICalculator.category(forBMI: 45.0, standard: .asian) == .obesityI)
        #expect(BMICalculator.category(forBMI: 60.0, standard: .asian) == .obesityI)
    }
}

// MARK: - Core BMI math

@Suite("BMI computation")
struct BMIComputationTests {

    @Test("Known metric value: 70 kg at 1.75 m ≈ 22.86")
    func knownMetric() {
        let value = BMICalculator.bmi(weightKilograms: 70, heightMeters: 1.75)
        #expect(abs(value - 22.857) < 0.001)
        #expect(BMICalculator.category(forBMI: value) == .healthy)
    }

    @Test("Non-positive height yields zero, not a crash or NaN")
    func zeroHeightGuard() {
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: 0) == 0)
        #expect(BMICalculator.bmi(weightKilograms: 70, heightMeters: -1.5) == 0)
    }
}

// MARK: - Unit conversions

@Suite("Unit conversions")
struct ConversionTests {

    @Test("215 lb at 5 ft 9 in is ≈ 31.7 BMI (obesity class 1)")
    func imperialEndToEnd() {
        let kg = BMICalculator.kilograms(fromPounds: 215)
        let meters = BMICalculator.meters(fromFeet: 5, inches: 9)
        let result = BMICalculator.result(weightKilograms: kg, heightMeters: meters)

        #expect(abs(result.rounded - 31.7) < 0.05)
        #expect(result.category == .obesityI)
        #expect(result.standard == .standard)
    }

    @Test("Pounds to kilograms uses the exact factor")
    func poundsToKilograms() {
        #expect(abs(BMICalculator.kilograms(fromPounds: 100) - 45.359237) < 0.000001)
    }

    @Test("Kilograms to pounds round-trips")
    func kilogramsToPounds() {
        let kg = BMICalculator.kilograms(fromPounds: 154)
        #expect(abs(BMICalculator.pounds(fromKilograms: kg) - 154) < 0.000001)
    }

    @Test("Feet and inches to meters: 6 ft 0 in ≈ 1.8288 m")
    func feetInchesToMeters() {
        #expect(abs(BMICalculator.meters(fromFeet: 6, inches: 0) - 1.8288) < 0.0001)
    }

    @Test("Feet and inches to meters: 5 ft 9 in ≈ 1.7526 m")
    func feetInchesToMetersFractional() {
        #expect(abs(BMICalculator.meters(fromFeet: 5, inches: 9) - 1.7526) < 0.0001)
    }
}

// MARK: - Result rounding & display

@Suite("Result rounding and display")
struct ResultRoundingTests {

    @Test("Rounded value is one decimal place")
    func roundsToOneDecimal() {
        let result = BMICalculator.result(weightKilograms: 70, heightMeters: 1.75)
        #expect(result.rounded == 22.9)
    }

    @Test("Display string always shows one decimal")
    func displayStringFormatting() {
        let result = BMIResult(value: 22.0, category: .healthy, standard: .standard)
        #expect(result.displayString == "22.0")
    }

    @Test("roundedToOneDecimal helper rounds half away from zero")
    func roundingHelper() {
        #expect(BMIResult.roundedToOneDecimal(31.65) == 31.7)
        #expect(BMIResult.roundedToOneDecimal(22.857) == 22.9)
    }
}

// MARK: - Codable round-trip

@Suite("Codable round-trips")
struct CodableTests {

    @Test("BMIResult survives JSON encode/decode")
    func resultRoundTrips() throws {
        let original = BMICalculator.result(weightKilograms: 80, heightMeters: 1.8, standard: .asian)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BMIResult.self, from: data)
        #expect(decoded == original)
    }

    @Test("Enums encode to their raw values")
    func enumRawValues() {
        #expect(UnitSystem.metric.rawValue == "metric")
        #expect(HealthStandard.asian.rawValue == "asian")
        #expect(BMICategory.obesityIII.rawValue == "obesityIII")
    }
}

// MARK: - Accent theme (BMI Pro)

@Suite("Accent theme")
struct AccentThemeTests {

    @Test("Only Classic Blue is free; every other palette is Pro")
    func entitlementFlags() {
        #expect(AppTheme.free == .classic)
        #expect(AppTheme.classic.isPro == false)
        for theme in AppTheme.allCases where theme != .classic {
            #expect(theme.isPro, "\(theme.displayName) should require Pro")
        }
    }

    @Test("Raw values round-trip so the persisted choice survives relaunch")
    func rawValueRoundTrip() {
        for theme in AppTheme.allCases {
            #expect(AppTheme(rawValue: theme.rawValue) == theme)
        }
    }

    @Test("Every palette exposes a distinct display name")
    func distinctNames() {
        let names = Set(AppTheme.allCases.map(\.displayName))
        #expect(names.count == AppTheme.allCases.count)
    }
}

@Suite("Appearance store")
@MainActor
struct AppearanceStoreTests {

    /// Builds a store against a clean persisted value so the default is deterministic.
    private func makeCleanStore() -> AppearanceStore {
        UserDefaults.standard.removeObject(forKey: AppStorageKey.appTheme)
        return AppearanceStore()
    }

    @Test("Defaults to the free Classic Blue and mirrors it into Theme.brand")
    func defaultsToClassic() {
        let store = makeCleanStore()
        #expect(store.theme == .classic)
        #expect(Theme.currentAccent == .classic)
    }

    @Test("Selecting a theme updates the global accent the app reads")
    func selectionUpdatesGlobal() {
        let store = makeCleanStore()
        store.theme = .violet
        #expect(Theme.currentAccent == .violet)
    }

    @Test("Losing Pro reverts a Pro palette but keeps Classic Blue")
    func enforceEntitlement() {
        let store = makeCleanStore()

        store.theme = .ocean
        store.enforceEntitlement(isPro: true)      // owns Pro → keep it
        #expect(store.theme == .ocean)

        store.enforceEntitlement(isPro: false)     // lost Pro → revert
        #expect(store.theme == .classic)
        #expect(Theme.currentAccent == .classic)

        store.enforceEntitlement(isPro: false)     // already free → no-op
        #expect(store.theme == .classic)
    }
}

// MARK: - Profiles (BMI Pro multi-person tracking)

@Suite("Profile store")
@MainActor
struct ProfileStoreTests {

    /// A clean in-memory container with a reset active-profile preference, so
    /// each test bootstraps deterministically.
    private func freshContainer() -> ModelContainer {
        ProfilePreferences.setActiveID(nil)
        return PersistenceController.inMemory()
    }

    @Test("Bootstrap creates a default profile and makes it active")
    func bootstrapCreatesDefault() {
        let store = ProfileStore(container: freshContainer())
        #expect(store.profiles.count == 1)
        #expect(store.profiles.first?.name == "Me")
        #expect(store.activeProfileID == store.profiles.first?.id)
    }

    @Test("Legacy records with no profile are adopted into the default profile")
    func backfillsLegacyRecords() {
        let container = freshContainer()
        let seed = ModelContext(container)
        seed.insert(BMIRecord(date: .now, bmi: 22, weightKilograms: 70,
                              heightMeters: 1.78, unitSystemRaw: "metric"))
        try? seed.save()

        let store = ProfileStore(container: container)
        let defaultID = store.profiles.first?.id

        let fetched = (try? ModelContext(container).fetch(FetchDescriptor<BMIRecord>())) ?? []
        #expect(fetched.count == 1)
        #expect(fetched.first?.profileID == defaultID)
    }

    @Test("Free tier is capped at one profile; Pro is unlimited")
    func entitlementCap() {
        let store = ProfileStore(container: freshContainer())
        #expect(store.canAddProfile(isPro: false) == false)   // already has the 1 free
        #expect(store.canAddProfile(isPro: true) == true)
    }

    @Test("Adding a profile trims the name, creates it, and makes it active")
    func addProfile() {
        let store = ProfileStore(container: freshContainer())
        let added = store.addProfile(name: "  Alex  ", isPro: true)
        #expect(added != nil)
        #expect(store.profiles.count == 2)
        #expect(store.profiles.contains { $0.name == "Alex" })
        #expect(store.activeProfileID == added?.id)
    }

    @Test("Empty names are rejected")
    func rejectsEmptyName() {
        let store = ProfileStore(container: freshContainer())
        #expect(store.addProfile(name: "   ", isPro: true) == nil)
        #expect(store.profiles.count == 1)
    }

    @Test("The store itself blocks a second profile for free users (no UI bypass)")
    func storeSideAddGuard() {
        let store = ProfileStore(container: freshContainer())
        #expect(store.addProfile(name: "Alex", isPro: false) == nil)
        #expect(store.profiles.count == 1)
        #expect(store.addProfile(name: "Alex", isPro: true) != nil)
        #expect(store.profiles.count == 2)
    }

    @Test("Losing Pro collapses the active profile to the default but keeps the data")
    func enforceFreeTierCollapses() {
        let store = ProfileStore(container: freshContainer())
        let me = store.profiles[0]
        let alex = store.addProfile(name: "Alex", isPro: true)!
        #expect(store.activeProfileID == alex.id)

        store.enforceFreeTier(isPro: true)     // still Pro → unchanged
        #expect(store.activeProfileID == alex.id)

        store.enforceFreeTier(isPro: false)    // lost Pro → back to default
        #expect(store.activeProfileID == me.id)
        #expect(store.profiles.count == 2)     // profiles preserved, not deleted
    }

    @Test("Records pointing at an unknown profile are re-homed to the default")
    func rehomesDanglingRecords() {
        let container = freshContainer()
        let seed = ModelContext(container)
        seed.insert(BMIRecord(date: .now, bmi: 24, weightKilograms: 75,
                              heightMeters: 1.8, unitSystemRaw: "metric", profileID: UUID()))
        try? seed.save()

        let store = ProfileStore(container: container)
        let defaultID = store.profiles.first?.id

        let fetched = (try? ModelContext(container).fetch(FetchDescriptor<BMIRecord>())) ?? []
        #expect(fetched.first?.profileID == defaultID)
    }

    @Test("Renaming updates the stored name")
    func rename() {
        let store = ProfileStore(container: freshContainer())
        store.rename(store.profiles[0], to: "Jordan")
        #expect(store.profiles.first?.name == "Jordan")
    }

    @Test("Deleting a profile reassigns its records and moves the active pointer")
    func deleteReassignsRecords() {
        let container = freshContainer()
        let store = ProfileStore(container: container)
        let me = store.profiles[0]
        let alex = store.addProfile(name: "Alex", isPro: true)!   // active becomes Alex

        let seed = ModelContext(container)
        seed.insert(BMIRecord(date: .now, bmi: 25, weightKilograms: 80,
                              heightMeters: 1.78, unitSystemRaw: "metric", profileID: alex.id))
        try? seed.save()

        store.delete(alex)
        #expect(store.profiles.count == 1)
        #expect(store.activeProfileID == me.id)        // moved off the deleted profile

        let fetched = (try? ModelContext(container).fetch(FetchDescriptor<BMIRecord>())) ?? []
        #expect(fetched.count == 1)
        #expect(fetched.allSatisfy { $0.profileID == me.id })   // record preserved, reassigned
    }

    @Test("The last remaining profile cannot be deleted")
    func cannotDeleteLast() {
        let store = ProfileStore(container: freshContainer())
        store.delete(store.profiles[0])
        #expect(store.profiles.count == 1)
    }
}
