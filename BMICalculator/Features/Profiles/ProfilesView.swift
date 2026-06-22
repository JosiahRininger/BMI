//
//  ProfilesView.swift
//  BMICalculator — Features/Profiles
//
//  Manage the people whose BMI is tracked: switch the active profile, add a new
//  one (a BMI Pro perk beyond the first), rename, or delete. Deleting never
//  loses data — a deleted profile's measurements move to another profile.
//
//  Presented from Settings ("Profiles") and from the History profile switcher.
//

import SwiftUI

struct ProfilesView: View {

    @Environment(ProfileStore.self) private var profiles
    @Environment(StoreState.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showAddAlert = false
    @State private var newName = ""
    @State private var renaming: BMIProfile?
    @State private var renameText = ""
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(profiles.profiles) { profile in
                        row(for: profile)
                    }
                } footer: {
                    Text(footerText)
                }
            }
            .navigationTitle("Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        addTapped()
                    } label: {
                        Label(
                            "Add Profile",
                            systemImage: profiles.canAddProfile(isPro: store.isPro) ? "plus" : "lock.fill"
                        )
                    }
                    .accessibilityLabel(profiles.canAddProfile(isPro: store.isPro) ? "Add profile" : "Add profile, a Pro feature")
                }
            }
            .alert("New profile", isPresented: $showAddAlert) {
                TextField("Name", text: $newName)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Add") {
                    profiles.addProfile(name: newName, isPro: store.isPro)
                    newName = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Track another person's BMI separately.")
            }
            .alert("Rename profile", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Name", text: $renameText)
                    .textInputAutocapitalization(.words)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let profile = renaming { profiles.rename(profile, to: renameText) }
                    renaming = nil
                }
                .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
        }
    }

    private var footerText: String {
        if store.isPro {
            return "Deleting a profile keeps its measurements by moving them to another profile."
        }
        return "BMI Pro lets you track more than one person. Deleting a profile keeps its measurements by moving them to another profile."
    }

    private func addTapped() {
        if profiles.canAddProfile(isPro: store.isPro) {
            newName = ""
            showAddAlert = true
        } else {
            showPaywall = true
        }
    }

    @ViewBuilder
    private func row(for profile: BMIProfile) -> some View {
        let isActive = profiles.activeProfileID == profile.id

        Button {
            // Switching between profiles is a Pro feature; free users (who keep
            // their data) get the paywall when tapping a non-active profile.
            if store.isPro || isActive {
                profiles.setActive(profile.id)
            } else {
                showPaywall = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isActive ? Theme.brand : .secondary)
                    .accessibilityHidden(true)
                Text(profile.name)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            // Only offer delete when there's another profile to fall back to.
            if profiles.profiles.count > 1 {
                Button(role: .destructive) {
                    profiles.delete(profile)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            Button {
                renameText = profile.name
                renaming = profile
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.gray)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(profile.name)
        .accessibilityValue(isActive ? "Active" : "")
        .accessibilityHint("Switches to this profile. Swipe for rename and delete.")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview("Profiles") {
    let container = PersistenceController.inMemory()
    return ProfilesView()
        .environment(ProfileStore(container: container))
        .environment(StoreState())
        .modelContainer(container)
}
