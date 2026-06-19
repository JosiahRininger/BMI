//
//  StreakBadge.swift
//  BMICalculator — Features/Streak
//
//  Glanceable streak UI + a one-time milestone celebration. Copy is encouraging
//  and never punitive ("welcome back", not "you broke your streak").
//

import SwiftUI

public struct StreakBadge: View {
    public let currentStreak: Int
    public let nextMilestone: StreakMilestone?
    public let entriesToNext: Int?

    public init(currentStreak: Int, nextMilestone: StreakMilestone?, entriesToNext: Int?) {
        self.currentStreak = currentStreak
        self.nextMilestone = nextMilestone
        self.entriesToNext = entriesToNext
    }

    public var body: some View {
        HStack(spacing: 14) {
            Image(systemName: currentStreak >= 1 ? "flame.fill" : "sparkles")
                .font(.title2)
                .foregroundStyle(Theme.brand)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let next = nextMilestone, let remaining = entriesToNext {
                    Text("\(remaining) more to “\(next.title)”")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .glassCard(cornerRadius: 18, padding: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var headline: String {
        switch currentStreak {
        case 0:  return "Start your streak"
        case 1:  return "1-day streak — nice start"
        default: return "\(currentStreak)-day streak"
        }
    }

    /// A single spoken summary combining the streak headline and the progress
    /// toward the next milestone, so VoiceOver doesn't drop the "X more" detail.
    private var accessibilitySummary: String {
        guard let next = nextMilestone, let remaining = entriesToNext else {
            return headline
        }
        return "\(headline). \(remaining) more to \(next.title)."
    }
}

/// A one-time celebration shown when a milestone is crossed. Present as an overlay
/// or sheet when `StreakService.milestoneJustEarned()` returns non-nil.
public struct MilestoneCelebrationView: View {
    public let milestone: StreakMilestone
    public var onDismiss: () -> Void

    public init(milestone: StreakMilestone, onDismiss: @escaping () -> Void) {
        self.milestone = milestone
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 20) {
                Image(systemName: milestone.systemImage)
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.brandGradient)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                Text("“\(milestone.title)” unlocked")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(milestone.threshold) check-ins logged. Thanks for showing up for yourself.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(milestone.title) unlocked. \(milestone.threshold) check-ins logged. Thanks for showing up for yourself.")

            Button {
                onDismiss()
            } label: {
                Text("Keep going")
            }
            .buttonStyle(.primaryGlass)
            .accessibilityLabel("Keep going")
            .accessibilityHint("Dismisses this celebration")
        }
        .padding(28)
        .frame(maxWidth: 360)
        .glassCard(cornerRadius: 28, padding: 8)
    }
}

#Preview {
    VStack(spacing: 24) {
        StreakBadge(currentStreak: 12,
                    nextMilestone: StreakMilestone.all[1],
                    entriesToNext: 18)
        MilestoneCelebrationView(milestone: StreakMilestone.all[0]) {}
    }
    .padding()
    .background(Theme.background)
}
