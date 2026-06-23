//
//  BMICalculator.swift
//  BMICalculator
//
//  Core engine — Foundation only. Pure, stateless functions.
//

import Foundation

// MARK: - BMICalculator

/// A pure, stateless BMI engine.
///
/// All classification uses **half-open** ranges (`..<`); a value that lands
/// exactly on a boundary belongs to the **higher** category. For example,
/// under `.standard`, exactly `25.0` is `.overweight` and exactly `30.0` is
/// `.obesityI`.
public enum BMICalculator {

    // MARK: Conversion constants

    /// Exact pounds-to-kilograms factor (1 lb = 0.45359237 kg).
    public static let kilogramsPerPound: Double = 0.45359237

    /// Exact inches-to-meters factor (1 in = 0.0254 m).
    public static let metersPerInch: Double = 0.0254

    /// Inches in one foot.
    public static let inchesPerFoot: Int = 12

    /// Pounds in one stone (UK/Ireland body-weight unit). 1 st = 14 lb ≈ 6.35029 kg.
    public static let poundsPerStone: Double = 14

    // MARK: Core calculation

    /// Computes BMI as `weight / height²`.
    /// - Parameters:
    ///   - weightKilograms: Mass in kilograms.
    ///   - heightMeters: Height in meters.
    /// - Returns: BMI in kg/m². Returns `0` if `heightMeters <= 0` to avoid a
    ///   division by zero or a non-finite result.
    public static func bmi(weightKilograms: Double, heightMeters: Double) -> Double {
        // Guard non-physical / non-finite input, and clamp a non-finite quotient
        // (a tiny height can underflow height² to 0, or a huge weight overflow),
        // so a bad value never propagates as NaN/inf into category() or display.
        guard heightMeters > 0, weightKilograms.isFinite, heightMeters.isFinite else { return 0 }
        let value = weightKilograms / (heightMeters * heightMeters)
        return value.isFinite ? value : 0
    }

    /// Classifies a BMI value under the given standard using half-open ranges.
    ///
    /// Boundaries always belong to the higher category:
    /// - `.standard`: `< 18.5` underweight, `18.5..<25` healthy,
    ///   `25..<30` overweight, `30..<35` obesityI, `35..<40` obesityII,
    ///   `>= 40` obesityIII.
    /// - `.asian`: `< 18.5` underweight, `18.5..<23` healthy,
    ///   `23..<27.5` overweight, `>= 27.5` obesityI. (Asian action points do
    ///   not define classes II / III.)
    /// - Parameters:
    ///   - bmi: A BMI value in kg/m².
    ///   - standard: The cutoff set to apply. Defaults to `.standard`.
    /// - Returns: The matching `BMICategory`.
    public static func category(
        forBMI bmi: Double,
        standard: HealthStandard = .standard
    ) -> BMICategory {
        // A corrupted/non-finite value must never read as severe obesity (the
        // `default:` branch). Return a neutral category instead of defaming a row.
        guard bmi.isFinite else { return .healthy }
        switch standard {
        case .standard:
            switch bmi {
            case ..<18.5:      return .underweight
            case 18.5..<25:    return .healthy
            case 25..<30:      return .overweight
            case 30..<35:      return .obesityI
            case 35..<40:      return .obesityII
            default:           return .obesityIII   // >= 40
            }
        case .asian:
            switch bmi {
            case ..<18.5:      return .underweight
            case 18.5..<23:    return .healthy
            case 23..<27.5:    return .overweight
            default:           return .obesityI      // >= 27.5
            }
        }
    }

    /// Computes a complete `BMIResult` from metric inputs.
    /// - Parameters:
    ///   - weightKilograms: Mass in kilograms.
    ///   - heightMeters: Height in meters.
    ///   - standard: The cutoff set to apply. Defaults to `.standard`.
    /// - Returns: A `BMIResult` carrying the full-precision value, its
    ///   category, the standard used, and a 1-decimal display value.
    public static func result(
        weightKilograms: Double,
        heightMeters: Double,
        standard: HealthStandard = .standard
    ) -> BMIResult {
        let value = bmi(weightKilograms: weightKilograms, heightMeters: heightMeters)
        let category = category(forBMI: value, standard: standard)
        return BMIResult(value: value, category: category, standard: standard)
    }

    // MARK: Unit conversions

    /// Converts pounds to kilograms (1 lb = 0.45359237 kg).
    public static func kilograms(fromPounds pounds: Double) -> Double {
        pounds * kilogramsPerPound
    }

    /// Converts a feet/inches height to meters.
    /// - Parameters:
    ///   - feet: Whole feet.
    ///   - inches: Additional inches (may be fractional).
    /// - Returns: Height in meters: `(feet * 12 + inches) * 0.0254`.
    public static func meters(fromFeet feet: Int, inches: Double) -> Double {
        let totalInches = Double(feet * inchesPerFoot) + inches
        return totalInches * metersPerInch
    }

    /// Converts kilograms to pounds.
    public static func pounds(fromKilograms kg: Double) -> Double {
        kg / kilogramsPerPound
    }

    /// Converts a stone + pounds body weight to kilograms (UK/Ireland unit).
    /// - Parameters:
    ///   - stone: Whole stone.
    ///   - pounds: Additional pounds (0..<14, may be fractional).
    public static func kilograms(fromStone stone: Double, pounds: Double = 0) -> Double {
        kilograms(fromPounds: stone * poundsPerStone + pounds)
    }

    /// Converts kilograms to stone + remainder pounds (e.g. 95.3 kg → 15 st 0.1 lb).
    /// - Returns: Whole `stone` and the remaining `pounds` in `0..<14`.
    public static func stoneAndPounds(fromKilograms kg: Double) -> (stone: Int, pounds: Double) {
        let totalPounds = pounds(fromKilograms: kg)
        // Guard finiteness and Int range before the Double→Int cast, which TRAPS
        // on NaN/inf or a value beyond Int's range.
        guard totalPounds.isFinite else { return (0, 0) }
        let stoneDouble = (totalPounds / poundsPerStone).rounded(.down)
        // Strict `<`: Double(Int.max) rounds UP to 2^63 (= Int.max + 1), which
        // would still trap the Int(...) cast, so reject the boundary.
        guard stoneDouble >= Double(Int.min), stoneDouble < Double(Int.max) else { return (0, 0) }
        let stone = Int(stoneDouble)
        let remainderPounds = totalPounds - Double(stone) * poundsPerStone
        return (stone, remainderPounds)
    }
}
