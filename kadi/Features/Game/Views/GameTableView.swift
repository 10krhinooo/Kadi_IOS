//
//  GameTableView.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Center-of-table area: discard pile (top card), draw pile with count, direction
/// indicator, and badges for an active draw stack / forced suit.
struct GameTableView: View {
    let topCard: PlayingCard?
    let drawCount: Int
    let direction: Direction
    let pendingDrawCount: Int
    let forcedSuit: Suit?

    var body: some View {
        VStack(spacing: KadiTheme.Layout.spacingM) {
            HStack(spacing: KadiTheme.Layout.spacingS) {
                Image(systemName: direction == .clockwise ? "arrow.clockwise" : "arrow.counterclockwise")
                    .foregroundStyle(KadiTheme.Colors.textSecondary)

                if pendingDrawCount > 0 {
                    PillBadge(text: "Draw +\(pendingDrawCount)", tint: KadiTheme.Colors.warning)
                }

                if let forcedSuit {
                    PillBadge(text: "Suit: \(forcedSuit.symbol)", tint: KadiTheme.Colors.surfaceElevated)
                }
            }

            HStack(spacing: KadiTheme.Layout.spacingL) {
                VStack(spacing: 4) {
                    PlayingCardView(card: nil, isFaceUp: false)
                    PillBadge(text: "\(drawCount)", systemImage: "rectangle.stack.fill")
                }

                VStack(spacing: 4) {
                    PlayingCardView(card: topCard, isFaceUp: true,
                                     width: KadiTheme.Layout.cardWidth + 12,
                                     height: KadiTheme.Layout.cardHeight + 12)
                    Text("Discard")
                        .font(KadiTheme.Typography.caption)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)
                }
            }
        }
    }
}
