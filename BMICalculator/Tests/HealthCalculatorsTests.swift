//
//  HealthCalculatorsTests.swift
//  BMICalculatorTests
//
//  Coverage for the six adjacent calculators in Core/HealthCalculators.swift.
//  All are pure arithmetic, so expected values are computed by hand from the
//  documented formulas and asserted with tight tolerances. Boundary and domain
//  guards (out-of-domain → nil, half-open category cutoffs) get explicit cases.
//

import Testing
import Foundation
@testable import BMICalculator

private func approx(_ a: Double, _ b: Double, _ tol: Double = 0.01) -> Bool {
    abs(a - b) < tol
}

// MARK: - Energy (BMR / TDEE)

@Suite("Energy: Mifflin-St Jeor & Harris-Benedict")
struct EnergyCalculatorTests {

    @Test("Mifflin-St Jeor male: 80 kg, 180 cm, 30 yr → 1780 kcal")
    func mifflinMale() {
        let bmr = EnergyCalculator.mifflinStJeorBMR(weightKilograms: 80, heightCentimeters: 180, ageYears: 30, sex: .male)
        // 10*80 + 6.25*180 - 5*30 + 5 = 1780
        #expect(approx(bmr, 1780))
    }

    @Test("Mifflin-St Jeor female: 60 kg, 165 cm, 30 yr → 1320.25 kcal")
    func mifflinFemale() {
        let bmr = EnergyCalculator.mifflinStJeorBMR(weightKilograms: 60, heightCentimeters: 165, ageYears: 30, sex: .female)
        // 10*60 + 6.25*165 - 5*30 - 161 = 1320.25
        #expect(approx(bmr, 1320.25))
    }

    @Test("Female BMR is exactly 166 below the male BMR for identical inputs")
    func sexOffset() {
        let male = EnergyCalculator.mifflinStJeorBMR(weightKilograms: 70, heightCentimeters: 175, ageYears: 40, sex: .male)
        let female = EnergyCalculator.mifflinStJeorBMR(weightKilograms: 70, heightCentimeters: 175, ageYears: 40, sex: .female)
        #expect(approx(male - female, 166))   // (+5) - (-161)
    }

    @Test("Harris-Benedict male: 80 kg, 180 cm, 30 yr → 1853.632 kcal")
    func harrisMale() {
        let bmr = EnergyCalculator.harrisBenedictBMR(weightKilograms: 80, heightCentimeters: 180, ageYears: 30, sex: .male)
        // 88.362 + 13.397*80 + 4.799*180 - 5.677*30 = 1853.632
        #expect(approx(bmr, 1853.632))
    }

    @Test("Harris-Benedict female: 60 kg, 165 cm, 30 yr → 1383.683 kcal")
    func harrisFemale() {
        let bmr = EnergyCalculator.harrisBenedictBMR(weightKilograms: 60, heightCentimeters: 165, ageYears: 30, sex: .female)
        // 447.593 + 9.247*60 + 3.098*165 - 4.330*30 = 1383.683
        #expect(approx(bmr, 1383.683))
    }

    @Test("TDEE multiplies BMR by the activity factor")
    func tdeeMultiplier() {
        #expect(approx(EnergyCalculator.tdee(bmr: 2000, activity: .moderate), 3100))   // 2000 * 1.55
        #expect(approx(EnergyCalculator.tdee(bmr: 2000, activity: .sedentary), 2400))  // 2000 * 1.2
    }

    @Test("energy() returns the Mifflin BMR paired with its activity-scaled TDEE")
    func energyConvenience() {
        let e = EnergyCalculator.energy(weightKilograms: 80, heightCentimeters: 180, ageYears: 30, sex: .male, activity: .sedentary)
        #expect(approx(e.bmr, 1780))
        #expect(approx(e.tdee, 1780 * 1.2))
    }

    @Test("Activity multipliers match the standard Mifflin factors and increase monotonically")
    func activityMultipliers() {
        #expect(ActivityLevel.sedentary.multiplier == 1.2)
        #expect(ActivityLevel.light.multiplier == 1.375)
        #expect(ActivityLevel.moderate.multiplier == 1.55)
        #expect(ActivityLevel.active.multiplier == 1.725)
        #expect(ActivityLevel.veryActive.multiplier == 1.9)
        let ordered = ActivityLevel.allCases.map(\.multiplier)
        #expect(ordered == ordered.sorted())
    }
}

// MARK: - Waist-to-height ratio

@Suite("Waist-to-height ratio (NICE NG246)")
struct RatioCalculatorTests {

    @Test("Ratio is waist ÷ height")
    func ratio() {
        #expect(approx(RatioCalculator.waistToHeightRatio(waistCentimeters: 80, heightCentimeters: 175), 80.0 / 175.0))
    }

    @Test("Non-positive height yields zero, not a crash")
    func zeroHeight() {
        #expect(RatioCalculator.waistToHeightRatio(waistCentimeters: 80, heightCentimeters: 0) == 0)
    }

    @Test("Half-open NICE bands: boundaries belong to the higher-risk band")
    func bands() {
        #expect(RatioCalculator.category(forWHtR: 0.39) == .possibleUnderweight)
        #expect(RatioCalculator.category(forWHtR: 0.40) == .healthy)
        #expect(RatioCalculator.category(forWHtR: 0.49) == .healthy)
        #expect(RatioCalculator.category(forWHtR: 0.50) == .increasedRisk)
        #expect(RatioCalculator.category(forWHtR: 0.59) == .increasedRisk)
        #expect(RatioCalculator.category(forWHtR: 0.60) == .highRisk)
        #expect(RatioCalculator.category(forWHtR: 0.85) == .highRisk)
    }

    @Test("Category display metadata is populated for every band")
    func displayMetadata() {
        for band in CentralAdiposityCategory.allCases {
            #expect(!band.title.isEmpty)
            #expect(!band.displayRange.isEmpty)
        }
        #expect(CentralAdiposityCategory.healthy.displayRange == "0.4 – < 0.5")
    }
}

// MARK: - US Navy body fat

@Suite("US Navy body-fat %")
struct BodyFatCalculatorTests {

    @Test("Male estimate: 180 cm, neck 38, waist 90 → ≈ 19.9%")
    func male() {
        let bf = BodyFatCalculator.usNavyBodyFatPercent(sex: .male, heightCentimeters: 180, neckCentimeters: 38, waistCentimeters: 90)
        #expect(bf != nil)
        #expect(approx(bf ?? 0, 19.92, 0.5))
    }

    @Test("Female estimate (hip required): 165 cm, neck 32, waist 80, hip 100 → ≈ 32.7%")
    func female() {
        let bf = BodyFatCalculator.usNavyBodyFatPercent(sex: .female, heightCentimeters: 165, neckCentimeters: 32, waistCentimeters: 80, hipCentimeters: 100)
        #expect(bf != nil)
        #expect(approx(bf ?? 0, 32.65, 0.6))
    }

    @Test("Female without a hip measurement returns nil (out of domain)")
    func femaleMissingHip() {
        let bf = BodyFatCalculator.usNavyBodyFatPercent(sex: .female, heightCentimeters: 165, neckCentimeters: 32, waistCentimeters: 80, hipCentimeters: nil)
        #expect(bf == nil)
    }

    @Test("Male with waist ≤ neck returns nil (log domain guard)")
    func maleDegenerate() {
        let bf = BodyFatCalculator.usNavyBodyFatPercent(sex: .male, heightCentimeters: 180, neckCentimeters: 40, waistCentimeters: 38)
        #expect(bf == nil)
    }

    @Test("A larger waist yields a higher body-fat estimate (monotonic)")
    func monotonic() {
        let lean = BodyFatCalculator.usNavyBodyFatPercent(sex: .male, heightCentimeters: 180, neckCentimeters: 38, waistCentimeters: 85) ?? 0
        let heavier = BodyFatCalculator.usNavyBodyFatPercent(sex: .male, heightCentimeters: 180, neckCentimeters: 38, waistCentimeters: 100) ?? 0
        #expect(heavier > lean)
    }
}

// MARK: - Ideal body weight

@Suite("Ideal body weight")
struct IdealWeightCalculatorTests {

    @Test("Male at 180 cm: Devine ≈ 75.0 kg")
    func maleDevine() {
        let iw = IdealWeightCalculator.idealWeights(heightCentimeters: 180, sex: .male)
        // inches over 60 = 70.8661 - 60 = 10.8661; 50 + 2.3*10.8661 = 74.992
        #expect(approx(iw.devine, 74.992, 0.02))
    }

    @Test("At exactly 5 ft (152.4 cm) the per-inch term is zero → base constants")
    func baseAtFiveFeet() {
        let iw = IdealWeightCalculator.idealWeights(heightCentimeters: 152.4, sex: .male)
        #expect(approx(iw.devine, 50))
        #expect(approx(iw.robinson, 52))
        #expect(approx(iw.hamwi, 48))
        #expect(approx(iw.miller, 56.2))
    }

    @Test("Below 5 ft the over-60 term is clamped to zero (no negative weights)")
    func clampedBelowFiveFeet() {
        let short = IdealWeightCalculator.idealWeights(heightCentimeters: 140, sex: .female)
        let fiveFt = IdealWeightCalculator.idealWeights(heightCentimeters: 152.4, sex: .female)
        #expect(approx(short.devine, fiveFt.devine))
    }

    @Test("Summary stats: average, lowest, highest are consistent with the four estimates")
    func summaryStats() {
        let iw = IdealWeightCalculator.idealWeights(heightCentimeters: 180, sex: .male)
        #expect(approx(iw.averageKilograms, iw.all.reduce(0, +) / 4))
        #expect(iw.lowestKilograms == iw.all.min())
        #expect(iw.highestKilograms == iw.all.max())
    }
}

// MARK: - Lean body mass

@Suite("Lean body mass")
struct LeanMassCalculatorTests {

    @Test("Boer male: 80 kg, 180 cm → 61.42 kg")
    func boerMale() {
        // 0.407*80 + 0.267*180 - 19.2 = 61.42
        #expect(approx(LeanMassCalculator.boer(weightKilograms: 80, heightCentimeters: 180, sex: .male), 61.42))
    }

    @Test("Boer female: 60 kg, 165 cm → 44.865 kg")
    func boerFemale() {
        // 0.252*60 + 0.473*165 - 48.3 = 44.865
        #expect(approx(LeanMassCalculator.boer(weightKilograms: 60, heightCentimeters: 165, sex: .female), 44.865))
    }

    @Test("James male: 80 kg, 180 cm → 62.716 kg")
    func jamesMale() {
        // 1.1*80 - 128*(80/180)^2 = 88 - 25.284 = 62.716
        #expect(approx(LeanMassCalculator.james(weightKilograms: 80, heightCentimeters: 180, sex: .male), 62.716, 0.01))
    }

    @Test("Hume male: 80 kg, 180 cm → 57.787 kg")
    func humeMale() {
        // 0.32810*80 + 0.33929*180 - 29.5336 = 57.7866
        #expect(approx(LeanMassCalculator.hume(weightKilograms: 80, heightCentimeters: 180, sex: .male), 57.7866, 0.01))
    }

    @Test("Lean mass is always below total body weight for realistic inputs")
    func belowBodyWeight() {
        #expect(LeanMassCalculator.boer(weightKilograms: 80, heightCentimeters: 180, sex: .male) < 80)
        #expect(LeanMassCalculator.hume(weightKilograms: 60, heightCentimeters: 165, sex: .female) < 60)
    }
}

// MARK: - Body frame

@Suite("Body frame size")
struct FrameSizeCalculatorTests {

    @Test("Male frame from the height ÷ wrist r-value")
    func maleFrame() {
        // r = 180/wrist: 17 → 10.59 (>10.4 small), 18 → 10.0 (medium), 19 → 9.47 (large)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 180, wristCentimeters: 17, sex: .male) == .small)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 180, wristCentimeters: 18, sex: .male) == .medium)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 180, wristCentimeters: 19, sex: .male) == .large)
    }

    @Test("Female frame uses the higher r-value thresholds")
    func femaleFrame() {
        // r = 165/wrist: 14 → 11.79 (small), 15 → 11.0 (medium boundary), 17 → 9.71 (large)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 165, wristCentimeters: 14, sex: .female) == .small)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 165, wristCentimeters: 15, sex: .female) == .medium)
        #expect(FrameSizeCalculator.frame(heightCentimeters: 165, wristCentimeters: 17, sex: .female) == .large)
    }

    @Test("Non-positive wrist falls back to medium, not a divide-by-zero")
    func zeroWrist() {
        #expect(FrameSizeCalculator.frame(heightCentimeters: 180, wristCentimeters: 0, sex: .male) == .medium)
    }

    @Test("Frame titles are capitalized raw values")
    func titles() {
        #expect(BodyFrame.small.title == "Small")
        #expect(BodyFrame.medium.title == "Medium")
        #expect(BodyFrame.large.title == "Large")
    }
}

// MARK: - Shared input enums

@Suite("Health calculator input enums")
struct HealthInputEnumTests {

    @Test("Sex titles")
    func sexTitles() {
        #expect(Sex.male.title == "Male")
        #expect(Sex.female.title == "Female")
    }

    @Test("Enums are round-trippable via their raw values")
    func rawValues() {
        for sex in Sex.allCases { #expect(Sex(rawValue: sex.rawValue) == sex) }
        for level in ActivityLevel.allCases { #expect(ActivityLevel(rawValue: level.rawValue) == level) }
        for frame in BodyFrame.allCases { #expect(BodyFrame(rawValue: frame.rawValue) == frame) }
    }
}
