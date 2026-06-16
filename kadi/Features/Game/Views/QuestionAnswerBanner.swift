//
//  QuestionAnswerBanner.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Shown when `phase == .questionAnswer` and it's the human's turn — after playing an
/// 8/Q, must immediately play a card of `forcedSuit` (highlighted in the hand) or pass.
struct QuestionAnswerBanner: View {
    let forcedSuit: Suit?
    let onPass: () -> Void

    var body: some View {
        HStack {
            if let forcedSuit {
                Text("Play a \(forcedSuit.symbol) card, or draw")
                    .font(KadiTheme.Typography.callout)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
            } else {
                Text("Play any card, or draw")
                    .font(KadiTheme.Typography.callout)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
            }

            Spacer()

            Button("Draw Card", action: onPass)
                .buttonStyle(SecondaryButtonStyle())
                .fixedSize()
        }
        .padding(.horizontal, KadiTheme.Layout.spacingM)
        .padding(.vertical, KadiTheme.Layout.spacingS)
        .background(KadiTheme.Colors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                .strokeBorder(KadiTheme.Colors.accent, lineWidth: 2)
        )
        .padding(.horizontal, KadiTheme.Layout.spacingM)
    }
}
