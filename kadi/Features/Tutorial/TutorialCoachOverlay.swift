//
//  TutorialCoachOverlay.swift
//  kadi
//

import SwiftUI

struct TutorialCoachOverlay: View {
    let step: TutorialStep
    let onNext: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: KadiTheme.Layout.spacingM) {
                VStack(alignment: .leading, spacing: KadiTheme.Layout.spacingS) {
                    Text(step.title)
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.accent)

                    Text(step.body)
                        .font(KadiTheme.Typography.body)
                        .foregroundStyle(KadiTheme.Colors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(KadiTheme.Layout.spacingM)
                .background(KadiTheme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))

                if step.expectedAction == .cpuTurn || step.expectedAction == .finish {
                    if step.expectedAction == .finish {
                        Button("Done!", action: onNext)
                            .buttonStyle(PrimaryButtonStyle())
                    } else {
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(KadiTheme.Colors.accent)
                            Text("CPU is playing\u{2026}")
                                .font(KadiTheme.Typography.callout)
                                .foregroundStyle(KadiTheme.Colors.textSecondary)
                        }
                    }
                } else {
                    Text(actionPrompt)
                        .font(KadiTheme.Typography.callout)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(KadiTheme.Layout.spacingM)
            .padding(.top, KadiTheme.Layout.spacingL)
        }
        .allowsHitTesting(step.expectedAction == .finish || step.expectedAction == .cpuTurn)
    }

    private var actionPrompt: String {
        switch step.expectedAction {
        case .selectAndPlayCard: return "Tap a green-bordered card, then tap Play"
        case .drawCard:         return "Tap 'Draw Card'"
        case .drawStack:        return "Drawing penalty cards\u{2026}"
        case .declareKadi:      return "Tap the glowing KADI button"
        case .chooseSuit:       return "Tap a suit to choose"
        case .cpuTurn:          return "Waiting for CPU\u{2026}"
        case .finish:           return ""
        }
    }
}
