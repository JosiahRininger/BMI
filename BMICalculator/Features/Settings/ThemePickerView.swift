//
//  ThemePickerView.swift
//  BMICalculator — Features/Settings
//
//  Pick the app's accent color (a Pro feature). Classic Blue is always
//  available. Without Pro the other palettes are shown as a preview with a lock;
//  tapping one opens the Pro sheet instead of a dead end.
//

import SwiftUI

struct ThemePickerView: View {

    @Environment(StoreState.self) private var store
    @State private var appearance = AppearanceStore.shared
    @State private var showsPro = false

    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        select(theme)
                    } label: {
                        row(for: theme)
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text(footerText)
            }
        }
        .navigationTitle("Theme")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showsPro) {
            ProSheet()
        }
    }

    private var footerText: String {
        store.hasPro
            ? "Your theme colors buttons, highlights, and the trend line. Category colors stay the same so they keep their meaning."
            : "Themes are part of \(ProCopy.name). Category colors stay the same so they keep their meaning."
    }

    private func row(for theme: AppTheme) -> some View {
        let isLocked = theme.requiresPro && !store.hasPro
        let isSelected = appearance.theme == theme
        return HStack(spacing: 14) {
            Circle()
                .fill(LinearGradient(colors: [theme.accent, theme.accentDeep],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .accessibilityHidden(true)
            Text(theme.displayName)
                .foregroundStyle(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.brand)
                    .accessibilityHidden(true)
            } else if isLocked {
                Image(systemName: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.displayName)
        .accessibilityValue(isSelected ? "Selected" : (isLocked ? "Requires Pro" : ""))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func select(_ theme: AppTheme) {
        if theme.requiresPro && !store.hasPro {
            showsPro = true
            return
        }
        appearance.choose(theme, hasPro: store.hasPro)
    }
}
