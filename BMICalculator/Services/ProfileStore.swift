//
//  ProfileStore.swift
//  BMICalculator — Services
//
//  Owns the set of tracked people (``BMIProfile``) and which one is active.
//  Multiple profiles are a BMI Pro perk; the free tier keeps a single profile.
//
//  Migration safety (the whole point of doing this carefully): on first launch
//  after profiles ship, `bootstrap()` creates a default profile and adopts every
//  legacy `nil`-profile record into it, so no existing history is orphaned or
//  lost. The operation is idempotent — once records are assigned, later launches
//  find nothing to backfill.
//
//  HEALTH/AD FIREWALL: profiles carry only a name + id; nothing here reaches the
//  ad SDK.
//

import Foundation
import SwiftData

// MARK: - Active-profile preference

/// Single source of truth for the persisted "active profile" id. Kept tiny so
/// the in-app sync helpers (WidgetSync, Spotlight) can read the same value the
/// store writes, without importing the store.
enum ProfilePreferences {

    static let activeKey = "app.activeProfileID"

    static func activeID(defaults: UserDefaults = .standard) -> UUID? {
        defaults.string(forKey: activeKey).flatMap(UUID.init(uuidString:))
    }

    static func setActiveID(_ id: UUID?, defaults: UserDefaults = .standard) {
        if let id {
            defaults.set(id.uuidString, forKey: activeKey)
        } else {
            defaults.removeObject(forKey: activeKey)
        }
    }
}

// MARK: - ProfileStore

@MainActor
@Observable
final class ProfileStore {

    /// Free tier: a single profile. Pro unlocks more.
    static let freeProfileLimit = 1

    /// All profiles, ordered for display (sortIndex, then creation date).
    private(set) var profiles: [BMIProfile] = []

    /// The active profile's id. Persisted; drives history filtering, new-record
    /// tagging, the widget snapshot, and Spotlight.
    private(set) var activeProfileID: UUID?

    private let container: ModelContainer
    private let context: ModelContext

    /// - Parameter container: the shared SwiftData container. A dedicated
    ///   `ModelContext` is used so this store doesn't depend on a view's context.
    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        bootstrap()
    }

    // MARK: Derived

    /// The active profile object, or the first profile as a fallback.
    var activeProfile: BMIProfile? {
        if let id = activeProfileID, let match = profiles.first(where: { $0.id == id }) {
            return match
        }
        return profiles.first
    }

    /// Whether another profile may be added under the given entitlement.
    func canAddProfile(isPro: Bool) -> Bool {
        isPro || profiles.count < Self.freeProfileLimit
    }

    // MARK: Bootstrap + migration

    /// Ensures at least one profile exists, resolves the active profile, and
    /// adopts any legacy (`nil`-profile) records into the default profile.
    private func bootstrap() {
        reloadProfiles()

        // 1. Guarantee a default profile.
        if profiles.isEmpty {
            let me = BMIProfile(name: "Me", sortIndex: 0)
            context.insert(me)
            try? context.save()
            reloadProfiles()
        }

        // 2. Resolve the active profile from the persisted id, falling back to
        //    the first profile when it's missing/stale.
        let persisted = ProfilePreferences.activeID()
        if let persisted, profiles.contains(where: { $0.id == persisted }) {
            activeProfileID = persisted
        } else {
            activeProfileID = profiles.first?.id
            ProfilePreferences.setActiveID(activeProfileID)
        }

        // 3. Adopt legacy/orphaned records into the default profile.
        backfillOrphanedRecords(into: profiles.first)

        // 4. Reconcile the free tier using the CACHED Pro flag before publishing,
        //    so a downgraded user's secondary profile isn't surfaced to the
        //    widget/Spotlight during the launch window (before StoreKit resolves
        //    and AppServices.start() calls enforceFreeTier).
        let cachedIsPro = UserDefaults(suiteName: "group.com.jdr.BMI")?.bool(forKey: "store.isPro.cache") ?? false
        enforceFreeTier(isPro: cachedIsPro)

        // Rebuild the widget snapshot so it reflects the active profile from
        // launch — the pre-migration snapshot was built from ALL records.
        refreshWidget()
    }

    /// Adopts records with no profile, OR a dangling profile id (pointing at a
    /// deleted/unknown profile), into the default profile, so no history is ever
    /// stranded outside every profile's query. Idempotent.
    private func backfillOrphanedRecords(into defaultProfile: BMIProfile?) {
        guard let defaultID = defaultProfile?.id else { return }
        let validIDs = Set(profiles.map(\.id))
        guard let all = try? context.fetch(FetchDescriptor<BMIRecord>()) else { return }
        var changed = false
        for record in all {
            if let pid = record.profileID {
                if !validIDs.contains(pid) { record.profileID = defaultID; changed = true }
            } else {
                record.profileID = defaultID; changed = true
            }
        }
        if changed { try? context.save() }
    }

    private func reloadProfiles() {
        let descriptor = FetchDescriptor<BMIProfile>(
            sortBy: [SortDescriptor(\.sortIndex, order: .forward),
                     SortDescriptor(\.createdAt, order: .forward)]
        )
        profiles = (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Mutations

    /// Switches the active profile (no-op if the id isn't known).
    func setActive(_ id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        ProfilePreferences.setActiveID(id)
        refreshWidget()
    }

    /// Collapses to the single default profile when Pro is lost, so the free
    /// tier is genuinely one profile regardless of which UI path was used.
    /// Existing profiles and their records are PRESERVED (only the active
    /// pointer resets) so re-purchasing restores full access immediately.
    func enforceFreeTier(isPro: Bool) {
        guard !isPro,
              let defaultID = profiles.first?.id,
              activeProfileID != defaultID
        else { return }
        setActive(defaultID)
    }

    /// Adds a new profile and makes it active. Returns the created profile, or
    /// `nil` if entitlement forbids it or the trimmed name is empty. The
    /// entitlement check here is authoritative — the UI gate is only cosmetic.
    @discardableResult
    func addProfile(name: String, isPro: Bool) -> BMIProfile? {
        guard canAddProfile(isPro: isPro) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Reject a case-insensitive duplicate so the switcher stays unambiguous.
        guard !profiles.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return nil }
        let nextIndex = (profiles.map(\.sortIndex).max() ?? -1) + 1
        let profile = BMIProfile(name: trimmed, sortIndex: nextIndex)
        context.insert(profile)
        try? context.save()
        reloadProfiles()
        setActive(profile.id)
        return profile
    }

    /// Renames a profile (ignores an empty trimmed name).
    func rename(_ profile: BMIProfile, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Reject a case-insensitive duplicate of a DIFFERENT profile.
        guard !profiles.contains(where: {
            $0.id != profile.id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }) else { return }
        profile.name = trimmed
        try? context.save()
        reloadProfiles()
    }

    /// Deletes a profile, reassigning its records to another profile so no
    /// history is lost. Refuses to delete the last remaining profile.
    func delete(_ profile: BMIProfile) {
        guard profiles.count > 1 else { return }
        let fallback = profiles.first(where: { $0.id != profile.id })
        let deletedID = profile.id

        // Reassign this profile's records to the fallback BEFORE deleting it.
        // If the fetch fails, bail rather than delete and orphan the records.
        if let fallbackID = fallback?.id {
            let descriptor = FetchDescriptor<BMIRecord>(
                predicate: #Predicate { $0.profileID == deletedID }
            )
            guard let records = try? context.fetch(descriptor) else { return }
            for record in records { record.profileID = fallbackID }
        }

        context.delete(profile)
        try? context.save()
        reloadProfiles()

        // Move the active pointer off the deleted profile if needed.
        if activeProfileID == deletedID {
            activeProfileID = fallback?.id ?? profiles.first?.id
            ProfilePreferences.setActiveID(activeProfileID)
        }
        refreshWidget()
    }

    // MARK: Widget sync

    /// Re-publishes the active profile's snapshot to the widget + Spotlight read
    /// path. Called whenever the active profile or its record set changes so the
    /// home-screen widget never lingers on the previous person's data.
    private func refreshWidget() {
        WidgetSync.update(from: container)
    }
}
