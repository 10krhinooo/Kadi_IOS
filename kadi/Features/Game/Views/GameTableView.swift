//
//  GameTableView.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Prominent suit badge shown when a forced suit is active (after Ace / 8 / Q play).
private struct ForcedSuitBadge: View {
    let suit: Suit
    @State private var pulse = false

    private var isRed: Bool { suit == .hearts || suit == .diamonds }

    var body: some View {
        HStack(spacing: 4) {
            Text(suit.symbol)
                .font(.system(size: 16, weight: .bold))
            Text("required")
                .font(.system(.caption, design: .rounded).weight(.semibold))
        }
        .foregroundStyle(isRed ? KadiTheme.Colors.suitRed : KadiTheme.Colors.textPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(KadiTheme.Colors.surfaceElevated)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(isRed ? KadiTheme.Colors.suitRed : KadiTheme.Colors.textPrimary,
                              lineWidth: pulse ? 2 : 1)
                .opacity(pulse ? 1 : 0.6)
        )
        .shadow(color: (isRed ? KadiTheme.Colors.suitRed : Color.white).opacity(pulse ? 0.6 : 0.2),
                radius: pulse ? 8 : 3)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

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
                    ForcedSuitBadge(suit: forcedSuit)
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
