//
//  HealthCalculators.swift
//  BMICalculator — Core
//
//  Adjacent body-metric calculators that expand the app beyond BMI, chosen from
//  the "feature expansion" research (build order: TDEE → waist-to-height →
//  US Navy body fat → ideal weight → lean mass → frame size). All are pure
//  arithmetic (Foundation only), so they are unit-testable and shareable with
//  the widget, exactly like `BMICalculator`.
//
//  Canonical input units: kilograms + centimetres. Formulas that are defined in
//  inches (US Navy, ideal weight, frame size) convert internally. Every result
//  is an ESTIMATE / screening figure, never a diagnosis — surface a disclaimer
//  in the UI (see Disclaimer.full).
//

import Foundation

// MARK: - Shared inputs

/// Biological sex, required by the sex-specific equations below. (BMI itself is
/// sex-agnostic, so this is intentionally separate from the BMI path.)
public enum Sex: String, CaseIterable, Codable, Identifiable, Sendable {
    case male, female
    public var id: String { rawValue }
    public var title: String { self == .male ? "Male" : "Female" }
}

/// Activity multiplier applied to BMR to estimate TDEE (total daily energy
/// expenditure). Multipliers are the standard Mifflin-St Jeor activity factors.
public enum ActivityLevel: String, CaseIterable, Codable, Identifiable, Sendable {
    case sedentary, light, moderate, active, veryActive
    public var id: String { rawValue }

    public var multiplier: Double {
        switch self {
        case .sedentary:  return 1.2
        case .light:      return 1.375
        case .moderate:   return 1.55
        case .active:     return 1.725
        case .veryActive: return 1.9
        }
    }

    public var title: String {
        switch self {
        case .sedentary:  return "Sedentary"
        case .light:      return "Lightly active"
        case .moderate:   return "Moderately active"
        case .active:     return "Very active"
        case .veryActive: return "Extremely active"
        }
    }

    public var subtitle: String {
        switch self {
        case .sedentary:  return "Little or no exercise"
        case .light:      return "1–3 days/week"
        case .moderate:   return "3–5 days/week"
        case .active:     return "6–7 days/week"
        case .veryActive: return "Hard exercise / physical job"
        }
    }
}

private extension Double {
    /// Centimetres → inches.
    var asInches: Double { self / 2.54 }
}

// MARK: - Energy: BMR & TDEE

/// Basal metabolic rate (kcal/day) and total daily energy expenditure.
/// Default to Mifflin-St Jeor (best-validated; Frankenfield 2005 systematic
/// review). Harris-Benedict (revised 1984) is offered as a comparison line.
public enum EnergyCalculator {

    /// Mifflin-St Jeor (Am J Clin Nutr 1990;51:241–247).
    public static func mifflinStJeorBMR(weightKilograms w: Double,
                                        heightCentimeters h: Double,
                                        ageYears age: Int,
                                        sex: Sex) -> Double {
        let base = 10 * w + 6.25 * h - 5 * Double(age)
        return sex == .male ? base + 5 : base - 161
    }

    /// Harris-Benedict, revised (Roza & Shizgal 1984).
    public static func harrisBenedictBMR(weightKilograms w: Double,
                                         heightCentimeters h: Double,
                                         ageYears age: Int,
                                         sex: Sex) -> Double {
        switch sex {
        case .male:   return 88.362 + 13.397 * w + 4.799 * h - 5.677 * Double(age)
        case .female: return 447.593 + 9.247 * w + 3.098 * h - 4.330 * Double(age)
        }
    }

    /// TDEE = BMR × activity factor.
    public static func tdee(bmr: Double, activity: ActivityLevel) -> Double {
        bmr * activity.multiplier
    }

    /// Convenience: Mifflin-St Jeor BMR + TDEE for every activity level.
    public static func energy(weightKilograms w: Double,
                              heightCentimeters h: Double,
                              ageYears age: Int,
                              sex: Sex,
                              activity: ActivityLevel) -> (bmr: Double, tdee: Double) {
        let bmr = mifflinStJeorBMR(weightKilograms: w, heightCentimeters: h, ageYears: age, sex: sex)
        return (bmr, tdee(bmr: bmr, activity: activity))
    }
}

// MARK: - Waist-to-height ratio (central adiposity)

/// Central-adiposity band per NICE guideline NG246 (2022).
public enum CentralAdiposityCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case possibleUnderweight, healthy, increasedRisk, highRisk
    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .possibleUnderweight: return "Possible underweight"
        case .healthy:             return "Healthy"
        case .increasedRisk:       return "Increased central adiposity"
        case .highRisk:            return "High central adiposity"
        }
    }

    public var displayRange: String {
        switch self {
        case .possibleUnderweight: return "< 0.4"
        case .healthy:             return "0.4 – < 0.5"
        case .increasedRisk:       return "0.5 – < 0.6"
        case .highRisk:            return "≥ 0.6"
        }
    }
}

public enum RatioCalculator {

    /// Waist-to-height ratio (unitless). Keep waist < half your height (< 0.5).
    public static func waistToHeightRatio(waistCentimeters waist: Double,
                                          heightCentimeters height: Double) -> Double {
        guard height > 0 else { return 0 }
        return waist / height
    }

    /// NICE NG246 bands. Half-open so 0.5 reads "increased", 0.6 reads "high".
    public static func category(forWHtR r: Double) -> CentralAdiposityCategory {
        switch r {
        case ..<0.4:     return .possibleUnderweight
        case 0.4..<0.5:  return .healthy
        case 0.5..<0.6:  return .increasedRisk
        default:         return .highRisk
        }
    }
}

// MARK: - US Navy body-fat %

public enum BodyFatCalculator {

    /// US Navy circumference method (Hodgdon & Beckett 1984), log10 imperial
    /// form. Measurements in centimetres (converted internally). Hip is required
    /// for females only. Returns nil if inputs are out of domain (e.g. waist ≤ neck).
    /// Validated to roughly ±3–4 percentage points vs DEXA.
    public static func usNavyBodyFatPercent(sex: Sex,
                                            heightCentimeters: Double,
                                            neckCentimeters: Double,
                                            waistCentimeters: Double,
                                            hipCentimeters: Double? = nil) -> Double? {
        let h = heightCentimeters.asInches
        let neck = neckCentimeters.asInches
        let waist = waistCentimeters.asInches
        guard h > 0 else { return nil }

        switch sex {
        case .male:
            let d = waist - neck
            guard d > 0 else { return nil }
            return 86.010 * log10(d) - 70.041 * log10(h) + 36.76
        case .female:
            guard let hipCm = hipCentimeters else { return nil }
            let hip = hipCm.asInches
            let d = waist + hip - neck
            guard d > 0 else { return nil }
            return 163.205 * log10(d) - 97.684 * log10(h) - 78.387
        }
    }
}

// MARK: - Ideal body weight

/// Ideal-weight estimates (kilograms) from the four classic clinical formulas,
/// presented as a range with a healthy-BMI cross-check in the UI. These are
/// pharmacologic/actuarial conventions, NOT validated "healthy weight" targets,
/// and are only defined for heights ≥ 60 inches.
public struct IdealBodyWeight: Hashable, Codable, Sendable {
    public let devine: Double
    public let robinson: Double
    public let hamwi: Double
    public let miller: Double

    public var all: [Double] { [devine, robinson, hamwi, miller] }
    public var lowestKilograms: Double { all.min() ?? devine }
    public var highestKilograms: Double { all.max() ?? devine }
    /// Mean of the four estimates — a single headline number.
    public var averageKilograms: Double { all.reduce(0, +) / Double(all.count) }
}

public enum IdealWeightCalculator {

    public static func idealWeights(heightCentimeters h: Double, sex: Sex) -> IdealBodyWeight {
        let inches = h.asInches
        let over = max(0, inches - 60)   // formulas add per inch above 5 ft
        switch sex {
        case .male:
            return IdealBodyWeight(devine:   50.0 + 2.3 * over,
                                   robinson: 52.0 + 1.9 * over,
                                   hamwi:    48.0 + 2.7 * over,
                                   miller:   56.2 + 1.41 * over)
        case .female:
            return IdealBodyWeight(devine:   45.5 + 2.3 * over,
                                   robinson: 49.0 + 1.7 * over,
                                   hamwi:    45.5 + 2.2 * over,
                                   miller:   53.1 + 1.36 * over)
        }
    }
}

// MARK: - Lean body mass

/// Lean body mass estimates (kilograms). Boer is the default (most widely used);
/// James & Hume offered as comparison. Inputs: kg + cm.
public enum LeanMassCalculator {

    public static func boer(weightKilograms w: Double, heightCentimeters h: Double, sex: Sex) -> Double {
        sex == .male ? 0.407 * w + 0.267 * h - 19.2
                     : 0.252 * w + 0.473 * h - 48.3
    }

    public static func james(weightKilograms w: Double, heightCentimeters h: Double, sex: Sex) -> Double {
        let ratio = w / h
        return sex == .male ? 1.1 * w - 128 * (ratio * ratio)
                            : 1.07 * w - 148 * (ratio * ratio)
    }

    public static func hume(weightKilograms w: Double, heightCentimeters h: Double, sex: Sex) -> Double {
        sex == .male ? 0.32810 * w + 0.33929 * h - 29.5336
                     : 0.29569 * w + 0.41813 * h - 43.2933
    }
}

// MARK: - Body frame size

/// Body frame from the wrist r-value (height ÷ wrist circumference, same units).
/// Actuarial heuristic (Metropolitan Life) — the least rigorous metric here;
/// present descriptively and use only for the optional ±10% ideal-weight adjust.
public enum BodyFrame: String, CaseIterable, Codable, Identifiable, Sendable {
    case small, medium, large
    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum FrameSizeCalculator {

    public static func frame(heightCentimeters h: Double, wristCentimeters wrist: Double, sex: Sex) -> BodyFrame {
        guard wrist > 0 else { return .medium }
        let r = h / wrist
        switch sex {
        case .male:   return r > 10.4 ? .small : (r >= 9.6 ? .medium : .large)
        case .female: return r > 11.0 ? .small : (r >= 10.1 ? .medium : .large)
        }
    }
}
