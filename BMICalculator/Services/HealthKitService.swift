//
//  HealthKitService.swift
//  BMICalculator
//
//  Reads height & body mass to PREFILL the calculator, and (optionally)
//  WRITES body mass + body mass index back to HealthKit after a calc.
//
//  ⚠️ HEALTH/AD FIREWALL (App Store Guideline 5.1.3):
//  Nothing in this file — no height, weight, BMI, or any HealthKit-derived
//  value — may ever be passed to the ad SDK or used for ad targeting.
//  HealthKit data stays inside the calculator and SwiftData history only.
//  Ads are configured non-personalized (NPA) in `AdsManager`.
//

import Foundation
import HealthKit

// MARK: - Prefill payload

/// A lightweight, Core-only snapshot of the most recent HealthKit samples,
/// already normalized to metric so it can feed `BMICalculator` directly.
///
/// Deliberately contains *no* SwiftUI / HealthKit types so it can cross
/// actor / target boundaries (e.g. to a widget) without dragging HealthKit in.
public struct HealthPrefill: Hashable, Sendable {
    /// Most recent body mass in kilograms, if available.
    public let weightKilograms: Double?
    /// Most recent height in meters, if available.
    public let heightMeters: Double?
    /// When the underlying samples were recorded (newest of the two), if any.
    public let sampleDate: Date?

    public init(weightKilograms: Double?, heightMeters: Double?, sampleDate: Date?) {
        self.weightKilograms = weightKilograms
        self.heightMeters = heightMeters
        self.sampleDate = sampleDate
    }

    /// `true` when at least one usable sample was found.
    public var hasAnyValue: Bool { weightKilograms != nil || heightMeters != nil }

    public static let empty = HealthPrefill(weightKilograms: nil, heightMeters: nil, sampleDate: nil)
}

// MARK: - Errors

public enum HealthKitError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case typeUnavailable

    public var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data isn't available on this device."
        case .authorizationDenied:
            return "Access to Health data was not granted. You can enable it in Settings › Health › Data Access & Devices."
        case .typeUnavailable:
            return "A required Health data type is unavailable."
        }
    }
}

// MARK: - HealthKitService

/// Async/await wrapper around `HKHealthStore`.
///
/// All methods degrade gracefully: when Health is unavailable or the user has
/// not granted access, reads return `.empty` and writes throw a descriptive
/// error rather than crashing. Authorization is requested *contextually* by the
/// caller (e.g. when the person taps "Use Health data"), never on launch.
@MainActor
@Observable
public final class HealthKitService {

    /// Whether HealthKit is present on this hardware (false on iPad without Health, etc.).
    public let isHealthDataAvailable: Bool

    /// Mirrors the user's last-known intent so UI can show the right affordance.
    /// This is *not* a reliable read-authorization signal — HealthKit deliberately
    /// hides read status for privacy — it only reflects that we asked.
    public private(set) var hasRequestedAuthorization = false

    private let store: HKHealthStore?

    // Quantity types we touch. Force-unwrap is safe: these identifiers always exist.
    private let bodyMassType = HKQuantityType(.bodyMass)
    private let heightType = HKQuantityType(.height)
    private let bmiType = HKQuantityType(.bodyMassIndex)

    public init() {
        let available = HKHealthStore.isHealthDataAvailable()
        self.isHealthDataAvailable = available
        self.store = available ? HKHealthStore() : nil
    }

    // MARK: Authorization

    /// The set of types we want to read (to prefill the calculator).
    private var readTypes: Set<HKObjectType> { [bodyMassType, heightType] }

    /// The set of types we want to write (optional body mass + BMI write-back).
    private var shareTypes: Set<HKSampleType> { [bodyMassType, bmiType] }

    /// Requests read access to height & body mass and write access to body mass & BMI.
    ///
    /// Call this *contextually*, after the person opts in. Safe to call repeatedly;
    /// iOS only shows the sheet the first time per type.
    /// - Throws: `HealthKitError.notAvailable` if Health isn't on this device.
    public func requestAuthorization() async throws {
        guard let store else { throw HealthKitError.notAvailable }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        hasRequestedAuthorization = true
    }

    /// Reports our *write* authorization for body mass (read status is intentionally opaque).
    public func canWriteBodyMass() -> Bool {
        guard let store else { return false }
        return store.authorizationStatus(for: bodyMassType) == .sharingAuthorized
    }

    // MARK: Reads (prefill)

    /// Fetches the most recent body mass and height samples and returns them
    /// normalized to metric, ready to seed the calculator.
    ///
    /// Never throws on "no data" or "denied" — returns `.empty` so the UI can
    /// simply fall back to manual entry.
    public func latestPrefill() async -> HealthPrefill {
        guard store != nil else { return .empty }

        // Run both reads concurrently.
        async let weight = mostRecentQuantity(of: bodyMassType, unit: .gramUnit(with: .kilo))
        async let height = mostRecentQuantity(of: heightType, unit: .meter())

        let (weightSample, heightSample) = await (weight, height)

        let dates = [weightSample?.date, heightSample?.date].compactMap { $0 }
        let newest = dates.max()

        return HealthPrefill(
            weightKilograms: weightSample?.value,
            heightMeters: heightSample?.value,
            sampleDate: newest
        )
    }

    /// A single sample's numeric value (in the requested unit) plus its end date.
    private struct SampleValue { let value: Double; let date: Date }

    /// Queries the single most recent sample of `type`, expressed in `unit`.
    /// Returns `nil` on any error or when no samples / access exist.
    private func mostRecentQuantity(
        of type: HKQuantityType,
        unit: HKUnit
    ) async -> SampleValue? {
        guard let store else { return nil }

        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: SampleValue(value: value, date: sample.endDate))
            }
            store.execute(query)
        }
    }

    // MARK: Writes (optional write-back)

    /// Optionally writes a body mass sample and the matching BMI back to HealthKit
    /// after a completed calculation. No-op-throws when Health is unavailable.
    ///
    /// - Parameters:
    ///   - weightKilograms: body mass in kg to record.
    ///   - bmi: the computed BMI value to record alongside it.
    ///   - date: sample timestamp (defaults to now).
    /// - Throws: `HealthKitError` on unavailability; HealthKit errors on save failure.
    public func write(weightKilograms: Double, bmi: Double, date: Date = .now) async throws {
        guard let store else { throw HealthKitError.notAvailable }

        var samples: [HKSample] = []

        let massQuantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightKilograms)
        samples.append(HKQuantitySample(type: bodyMassType, quantity: massQuantity, start: date, end: date))

        // BMI is unit-less ("count") in HealthKit.
        let bmiQuantity = HKQuantity(unit: .count(), doubleValue: bmi)
        samples.append(HKQuantitySample(type: bmiType, quantity: bmiQuantity, start: date, end: date))

        try await store.save(samples)
    }
}
