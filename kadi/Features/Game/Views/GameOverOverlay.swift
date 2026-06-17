//
//  GameOverOverlay.swift
//  kadi

import SwiftUI

/// Shown when `phase == .finished` — announces the winner and offers to play again or
/// return home.
struct GameOverOverlay: View {
    let winnerName: String?
    let isLocalWinner: Bool
    let onPlayAgain: () -> Void
    let onBackToHome: () -> Void

    @State private var titleScale: CGFloat = 0.5
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            if isLocalWinner {
                ConfettiView()
            }

            OverlayCard(title: isLocalWinner ? "You Win!" : "Game Over") {
                if let winnerName, !isLocalWinner {
                    Text("\(winnerName) wins!")
                        .font(KadiTheme.Typography.title)
                        .foregroundStyle(KadiTheme.Colors.accent)
                }

                Button("Play Again", action: onPlayAgain)
                    .buttonStyle(PrimaryButtonStyle())

                Button("Back to Home", action: onBackToHome)
                    .buttonStyle(SecondaryButtonStyle())
            }
            .scaleEffect(titleScale)
            .opacity(titleOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                    titleScale = 1
                    titleOpacity = 1
                }
            }
        }
        .onAppear { if isLocalWinner { Haptics.win() } }
    }
}
