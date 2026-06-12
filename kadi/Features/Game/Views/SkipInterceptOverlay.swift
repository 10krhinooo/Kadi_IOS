//
//  SkipInterceptOverlay.swift
//  kadi
//

import SwiftUI
import KadiEngine

/// Shown when `phase == .skipIntercept` (blocking chain) and the human is the current
/// player in the intercept queue — may redirect the pending skip by playing Jack(s),
/// or decline.
struct SkipInterceptOverlay: View {
    let jacksInHand: [PlayingCard]
    let onIntercept: ([PlayingCard]) -> Void
    let onDecline: () -> Void

    @State private var selected: Set<PlayingCard> = []

    var body: some View {
        OverlayCard(title: "Intercept the Skip?") {
            Text("Play Jack(s) from your hand to redirect the skip, or decline.")
                .font(KadiTheme.Typography.callout)
                .foregroundStyle(KadiTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: KadiTheme.Layout.spacingS) {
                ForEach(jacksInHand, id: \.self) { jack in
                    PlayingCardView(card: jack, isSelected: selected.contains(jack))
                        .onTapGesture {
                            if selected.contains(jack) {
                                selected.remove(jack)
                            } else {
                                selected.insert(jack)
                            }
                        }
                }
            }

            Button("Intercept") {
                onIntercept(Array(selected))
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected.isEmpty)

            Button("Decline", action: onDecline)
                .buttonStyle(SecondaryButtonStyle())
        }
    }
}
