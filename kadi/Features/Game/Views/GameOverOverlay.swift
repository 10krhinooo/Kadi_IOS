//
//  GameOverOverlay.swift
//  kadi
//

import SwiftUI

/// Shown when `phase == .finished` — announces the winner and offers to play again or
/// return home.
struct GameOverOverlay: View {
    let winnerName: String?
    let onPlayAgain: () -> Void
    let onBackToHome: () -> Void

    var body: some View {
        OverlayCard(title: "Game Over") {
            if let winnerName {
                Text("\(winnerName) wins!")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.accent)
            }

            Button("Play Again", action: onPlayAgain)
                .buttonStyle(PrimaryButtonStyle())

            Button("Back to Home", action: onBackToHome)
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}
