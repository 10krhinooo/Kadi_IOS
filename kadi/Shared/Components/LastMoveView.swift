//
//  LastMoveView.swift
//  kadi
//

import SwiftUI
import KadiEngine

struct LastMoveView: View {
    let playerName: String
    let cards: [PlayingCard]

    var body: some View {
        HStack(spacing: 6) {
            Text("\(playerName) played")
                .font(KadiTheme.Typography.caption)
                .foregroundStyle(KadiTheme.Colors.textSecondary)
            ForEach(Array(cards.prefix(4).enumerated()), id: \.offset) { _, card in
                Text("\(card.rankLabel)\(card.suitSymbol)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(card.isRed ? KadiTheme.Colors.suitRed : KadiTheme.Colors.textPrimary)
            }
            if cards.count > 4 {
                Text("+\(cards.count - 4)")
                    .font(KadiTheme.Typography.caption)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
            }
        }
        .padding(.horizontal, KadiTheme.Layout.spacingM)
        .padding(.vertical, 6)
        .background(KadiTheme.Colors.surfaceElevated.opacity(0.9))
        .clipShape(Capsule())
    }
}
