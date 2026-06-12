//
//  CardDemandOverlay.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Shown when `phase == .cardDemand` and it's the human's turn — must play the
/// demanded card, counter with an Ace from hand, or draw.
struct CardDemandOverlay: View {
    let demandedCard: PlayingCard?
    let hasDemandedCard: Bool
    let acesInHand: [PlayingCard]
    let onPlayDemanded: () -> Void
    let onPlayAce: (PlayingCard) -> Void
    let onDrawInstead: () -> Void

    var body: some View {
        OverlayCard(title: "Card Demanded") {
            if let demandedCard {
                PlayingCardView(card: demandedCard)
            }

            Text("Play the demanded card, counter with an Ace from your hand, or draw.")
                .font(KadiTheme.Typography.callout)
                .foregroundStyle(KadiTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            if hasDemandedCard {
                Button("Play It") {
                    onPlayDemanded()
                }
                .buttonStyle(PrimaryButtonStyle())
            }

            if !acesInHand.isEmpty {
                HStack(spacing: KadiTheme.Layout.spacingS) {
                    ForEach(acesInHand, id: \.self) { ace in
                        PlayingCardView(card: ace)
                            .onTapGesture { onPlayAce(ace) }
                    }
                }
            }

            Button("Draw Instead") {
                onDrawInstead()
            }
            .buttonStyle(SecondaryButtonStyle())
        }
    }
}
