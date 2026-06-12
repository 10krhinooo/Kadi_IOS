//
//  PlayerHandView.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Horizontal scroll of the human player's hand. Index-based (not `Set<PlayingCard>`)
/// because `PlayingCard` equality/hashing is on (rank, suit), and duplicate cards
/// (jokers, multi-deck rule sets) would collide in a Set.
struct PlayerHandView: View {
    let cards: [PlayingCard]
    var playableIndices: Set<Int> = []
    var selectedIndices: Set<Int> = []
    var onTap: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -16) {
                ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                    PlayingCardView(
                        card: card,
                        isSelected: selectedIndices.contains(index),
                        isHighlighted: playableIndices.contains(index)
                    )
                    .onTapGesture { onTap(index) }
                    .zIndex(selectedIndices.contains(index) ? 1 : 0)
                }
            }
            .padding(.horizontal, KadiTheme.Layout.spacingL)
            .padding(.vertical, KadiTheme.Layout.spacingM)
        }
    }
}
