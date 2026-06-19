//
//  BMIResultEntity.swift
//  BMICalculator
//
//  An AppEntity describing a saved BMI result so that recent calculations are
//  queryable from Siri / the Shortcuts app and can be donated to Spotlight via
//  Core Spotlight. The entity is intentionally lightweight and value-typed so it
//  can be created from a `BMIResult` (Core) or from a persisted `BMIRecord`
//  (SwiftData) without coupling the Intents module to SwiftData.
//
//  Depends on Core: BMIResult, BMICategory.
//

import Foundation
import AppIntents
import CoreSpotlight
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

// MARK: - BMIResultEntity

/// A single, queryable BMI measurement surfaced to the system (Shortcuts, Siri,
/// Spotlight). Identified by a stable string id so Spotlight donations and
/// `EntityQuery` lookups stay consistent across launches.
struct BMIResultEntity: AppEntity, Identifiable {

    // MARK: Type metadata

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: "BMI Result",
            numericFormat: "\(placeholder: .int) BMI results"
        )
    }

    /// The query used by the system to resolve entities by id and to list
    /// suggested (recent) entities.
    static var defaultQuery = BMIResultEntityQuery()

    // MARK: Stored properties

    /// Stable identifier. For persisted records this is the record's UUID string;
    /// for ad-hoc results it is a deterministic hash of value + date.
    var id: String

    /// The BMI value rounded to one decimal place, ready for display.
    @Property(title: "BMI")
    var bmi: Double

    /// The category title, person-first (e.g. "Healthy weight").
    @Property(title: "Category")
    var categoryTitle: String

    /// The category's display range string (e.g. "18.5 – < 25").
    @Property(title: "Range")
    var categoryRange: String

    /// When the measurement was taken / saved.
    @Property(title: "Date")
    var date: Date

    /// The raw category case value, kept for filtering / reconstruction.
    var categoryRaw: String

    // MARK: Display

    var displayRepresentation: DisplayRepresentation {
        let dateText = Self.dateFormatter.string(from: date)
        return DisplayRepresentation(
            title: "BMI \(bmiText) · \(categoryTitle)",
            subtitle: "\(dateText) · \(categoryRange)"
        )
    }

    // MARK: Init

    init(
        id: String,
        bmi: Double,
        categoryTitle: String,
        categoryRange: String,
        categoryRaw: String,
        date: Date
    ) {
        self.id = id
        self.bmi = bmi
        self.categoryTitle = categoryTitle
        self.categoryRange = categoryRange
        self.categoryRaw = categoryRaw
        self.date = date
    }

    // MARK: Convenience init from Core

    /// Builds an entity from a Core `BMIResult`. The optional `id`/`date` let the
    /// caller pass a persisted identifier and timestamp; otherwise stable
    /// defaults are derived.
    init(result: BMIResult, id: String? = nil, date: Date = Date()) {
        let resolvedID = id ?? Self.deterministicID(bmi: result.rounded, date: date)
        self.init(
            id: resolvedID,
            bmi: result.rounded,
            categoryTitle: result.category.title,
            categoryRange: result.category.displayRange,
            categoryRaw: result.category.rawValue,
            date: date
        )
    }

    // MARK: Helpers

    var bmiText: String {
        String(format: "%.1f", bmi)
    }

    /// Reconstructs the Core category if the raw value still maps to a known case.
    var category: BMICategory? {
        BMICategory(rawValue: categoryRaw)
    }

    static func deterministicID(bmi: Double, date: Date) -> String {
        "bmi-\(Int(date.timeIntervalSince1970))-\(Int((bmi * 10).rounded()))"
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - IndexedEntity (Spotlight semantic indexing)

extension BMIResultEntity: IndexedEntity {

    /// Provides the Core Spotlight attribute set so the system can index this
    /// entity for semantic / on-device search. iOS automatically reconciles
    /// `IndexedEntity` instances returned from queries; we also offer an explicit
    /// donation helper below for record-driven indexing.
    var attributeSet: CSSearchableItemAttributeSet {
        BMIResultEntity.makeAttributeSet(
            bmiText: bmiText,
            categoryTitle: categoryTitle,
            categoryRange: categoryRange,
            date: date
        )
    }
}

// MARK: - Spotlight donation

extension BMIResultEntity {

    /// The Core Spotlight domain identifier used for all donated BMI results,
    /// so they can be removed as a group on user request (privacy / health data).
    static let spotlightDomainIdentifier = "com.bmicalculator.results"

    /// Builds a non-judgmental, person-first searchable attribute set.
    static func makeAttributeSet(
        bmiText: String,
        categoryTitle: String,
        categoryRange: String,
        date: Date
    ) -> CSSearchableItemAttributeSet {
        let contentType: String
        #if canImport(UniformTypeIdentifiers)
        contentType = UTType.text.identifier
        #else
        contentType = "public.text"
        #endif

        let attributes = CSSearchableItemAttributeSet(contentType: contentType)
        attributes.title = "BMI \(bmiText) — \(categoryTitle)"
        attributes.contentDescription = "Recorded \(dateFormatter.string(from: date)). Range \(categoryRange). BMI is a screening tool, not a diagnosis."
        attributes.contentCreationDate = date
        attributes.keywords = ["BMI", "Body Mass Index", "health", categoryTitle]
        return attributes
    }

    /// Donates a batch of persisted records to Spotlight so recent results appear
    /// in system search. Pass plain value tuples to avoid importing SwiftData here.
    ///
    /// HEALTH/AD FIREWALL: this writes only to the on-device Spotlight index. No
    /// height/weight/BMI value is ever forwarded to the ad SDK or ad-targeting.
    /// Spotlight content stays local to the device and is not iCloud-synced here.
    ///
    /// - Parameters:
    ///   - records: tuples of (id, bmi, categoryTitle, categoryRange, date).
    ///   - completion: optional callback with any indexing error.
    static func donate(
        records: [(id: String, bmi: Double, categoryTitle: String, categoryRange: String, date: Date)],
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        guard !records.isEmpty else {
            completion?(nil)
            return
        }

        let items: [CSSearchableItem] = records.map { record in
            let attributes = makeAttributeSet(
                bmiText: String(format: "%.1f", record.bmi),
                categoryTitle: record.categoryTitle,
                categoryRange: record.categoryRange,
                date: record.date
            )
            let item = CSSearchableItem(
                uniqueIdentifier: record.id,
                domainIdentifier: spotlightDomainIdentifier,
                attributeSet: attributes
            )
            // Keep the index lean: results older than 90 days expire automatically.
            item.expirationDate = record.date.addingTimeInterval(60 * 60 * 24 * 90)
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            completion?(error)
        }
    }

    /// Convenience overload that accepts `BMIResultEntity` values directly.
    static func donate(
        entities: [BMIResultEntity],
        completion: (@Sendable (Error?) -> Void)? = nil
    ) {
        donate(
            records: entities.map {
                (id: $0.id, bmi: $0.bmi, categoryTitle: $0.categoryTitle, categoryRange: $0.categoryRange, date: $0.date)
            },
            completion: completion
        )
    }

    /// Removes all donated BMI results from Spotlight. Call this when the person
    /// clears their history or disables Spotlight indexing in Settings — health
    /// data should be easy to revoke.
    static func deleteAllDonations(completion: (@Sendable (Error?) -> Void)? = nil) {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [spotlightDomainIdentifier]
        ) { error in
            completion?(error)
        }
    }
}

// MARK: - EntityQuery

/// Resolves `BMIResultEntity` values by id and supplies recent results as
/// suggestions. The query reads from a `BMIResultProviding` source that the app
/// configures at launch (so this module stays decoupled from SwiftData).
struct BMIResultEntityQuery: EntityQuery {

    func entities(for identifiers: [BMIResultEntity.ID]) async throws -> [BMIResultEntity] {
        let all = await BMIResultStore.shared.recentEntities(limit: .max)
        let lookup = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return identifiers.compactMap { lookup[$0] }
    }

    func suggestedEntities() async throws -> [BMIResultEntity] {
        await BMIResultStore.shared.recentEntities(limit: 10)
    }
}

// MARK: - BMIResultProviding

/// Abstraction over the app's persistence layer. The App target conforms a
/// SwiftData-backed type to this and installs it via `BMIResultStore.configure`.
/// Keeping it a protocol means the Intents module never imports SwiftData.
protocol BMIResultProviding: Sendable {
    /// Returns the most recent results, newest first, capped at `limit`.
    func recentResults(limit: Int) async -> [BMIResultEntity]
}

// MARK: - BMIResultStore

/// Process-wide access point the system queries from app-extension contexts.
/// The App target should call `BMIResultStore.configure(with:)` early in launch.
actor BMIResultStore {

    static let shared = BMIResultStore()

    private var provider: BMIResultProviding?

    private init() {}

    /// Installs the persistence-backed provider. Safe to call multiple times;
    /// the latest provider wins.
    static func configure(with provider: BMIResultProviding) {
        Task { await shared.setProvider(provider) }
    }

    private func setProvider(_ provider: BMIResultProviding) {
        self.provider = provider
    }

    /// Returns recent entities, or an empty list if no provider is configured
    /// (e.g. when running in a minimal extension context).
    func recentEntities(limit: Int) async -> [BMIResultEntity] {
        guard let provider else { return [] }
        return await provider.recentResults(limit: limit)
    }
}
