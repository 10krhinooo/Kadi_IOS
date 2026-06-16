//
//  PlayingCardView.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Renders a single `PlayingCard`, or a face-down card back when `card == nil` or
/// `isFaceUp == false`.
struct PlayingCardView: View {
    let card: PlayingCard?
    var isFaceUp: Bool = true
    var width: CGFloat = KadiTheme.Layout.cardWidth
    var height: CGFloat = KadiTheme.Layout.cardHeight
    var isSelected: Bool = false
    var isHighlighted: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cardCornerRadius)
                .fill(isFaceUp ? KadiTheme.Colors.cardFace : KadiTheme.Colors.cardBack)
                .overlay(
                    RoundedRectangle(cornerRadius: KadiTheme.Layout.cardCornerRadius)
                        .stroke(borderColor, lineWidth: isSelected ? 3 : 1)
                )

            if isFaceUp, let card {
                cardFace(card)
            } else if !isFaceUp {
                cardBackPattern
            }
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
        .offset(y: isSelected ? -12 : 0)
        .animation(.spring(response: 0.25), value: isSelected)
    }

    private var borderColor: Color {
        if isSelected { return KadiTheme.Colors.accent }
        if isHighlighted { return KadiTheme.Colors.success }
        return KadiTheme.Colors.cardBorder
    }

    @ViewBuilder
    private func cardFace(_ card: PlayingCard) -> some View {
        let color = card.isRed ? KadiTheme.Colors.suitRed : KadiTheme.Colors.suitBlack
        let isSmall = width < 56

        if card.isJoker {
            VStack(spacing: 2) {
                Text(card.rankLabel)
                    .font(isSmall ? KadiTheme.Typography.cardRankSmall : KadiTheme.Typography.cardRank)
                    .foregroundStyle(color)
                Text("🃏")
                    .font(.system(size: isSmall ? 18 : 26))
            }
            .padding(4)
        } else {
            let cornerRankFont  = Font.system(size: isSmall ? 11 : 14, weight: .bold, design: .rounded)
            let cornerSuitFont  = Font.system(size: isSmall ? 10 : 12, weight: .bold)
            let centerSuitFont  = Font.system(size: isSmall ? 22 : 34, weight: .bold)

            ZStack(alignment: .topLeading) {
                // Bottom-right corner (rotated 180°)
                VStack(spacing: 0) {
                    Text(card.rankLabel)
                        .font(cornerRankFont)
                    Text(card.suitSymbol)
                        .font(cornerSuitFont)
                }
                .foregroundStyle(color)
                .rotationEffect(.degrees(180))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(isSmall ? 2 : 4)

                // Top-left corner
                VStack(spacing: 0) {
                    Text(card.rankLabel)
                        .font(cornerRankFont)
                    Text(card.suitSymbol)
                        .font(cornerSuitFont)
                }
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(isSmall ? 2 : 4)

                // Center suit symbol
                Text(card.suitSymbol)
                    .font(centerSuitFont)
                    .foregroundStyle(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    private var cardBackPattern: some View {
        RoundedRectangle(cornerRadius: KadiTheme.Layout.cardCornerRadius - 2)
            .strokeBorder(KadiTheme.Colors.accent.opacity(0.5), lineWidth: 2)
            .padding(6)
            .overlay(
                Text("K")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(KadiTheme.Colors.accent.opacity(0.5))
            )
    }
}

#Preview {
    HStack {
        PlayingCardView(card: PlayingCard(rank: .ace, suit: .spades))
        PlayingCardView(card: PlayingCard(rank: .joker, suit: .hearts), isSelected: true)
        PlayingCardView(card: nil, isFaceUp: false)
    }
    .padding()
    .background(KadiTheme.Colors.tableFelt)
}
