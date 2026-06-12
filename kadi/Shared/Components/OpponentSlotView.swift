//
//  OpponentSlotView.swift
//  kadi
//

import SwiftUI

/// Shows an opponent's avatar, name, a small fan of face-down cards, and a card-count
/// badge. In Solo mode card counts are always shown (the `showOpponentCardCounts` rule
/// flag is about human-vs-human fairness, not relevant against CPUs).
struct OpponentSlotView: View {
    let name: String
    let cardCount: Int
    var isCurrentTurn: Bool = false
    var avatarIndex: Int = 0
    var isCPUControlled: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                AvatarView(avatarIndex: avatarIndex, size: 28, isHighlighted: isCurrentTurn)
            }

            Text(name)
                .font(KadiTheme.Typography.callout)
                .foregroundStyle(KadiTheme.Colors.textPrimary)
                .lineLimit(1)

            ZStack {
                ForEach(0..<min(cardCount, 4), id: \.self) { index in
                    PlayingCardView(
                        card: nil,
                        isFaceUp: false,
                        width: KadiTheme.Layout.cardWidthSmall,
                        height: KadiTheme.Layout.cardHeightSmall
                    )
                    .offset(x: CGFloat(index) * 6)
                }
            }
            .frame(width: KadiTheme.Layout.cardWidthSmall + 18, height: KadiTheme.Layout.cardHeightSmall)

            PillBadge(text: "\(cardCount) cards", systemImage: "rectangle.stack.fill")

            if isCPUControlled {
                PillBadge(text: "CPU", tint: KadiTheme.Colors.warning, systemImage: "cpu")
            }
        }
        .padding(KadiTheme.Layout.spacingS)
        .background(
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                .fill(KadiTheme.Colors.surface.opacity(isCurrentTurn ? 0.9 : 0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                .stroke(isCurrentTurn ? KadiTheme.Colors.accent : .clear, lineWidth: 2)
        )
    }
}

#Preview {
    HStack {
        OpponentSlotView(name: "CPU 1", cardCount: 4, isCurrentTurn: true)
        OpponentSlotView(name: "CPU 2", cardCount: 7)
    }
    .padding()
    .background(KadiTheme.Colors.tableFelt)
}
