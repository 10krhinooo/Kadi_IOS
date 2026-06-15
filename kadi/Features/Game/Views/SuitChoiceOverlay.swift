//
//  SuitChoiceOverlay.swift
//  kadi
//

import SwiftUI
import KadiEngine

private extension Suit {
    /// SF Symbol name for this suit, used instead of the emoji `symbol` (which can
    /// render as "?" tofu at large sizes on some simulators/devices).
    var sfSymbolName: String {
        switch self {
        case .hearts: return "suit.heart.fill"
        case .diamonds: return "suit.diamond.fill"
        case .clubs: return "suit.club.fill"
        case .spades: return "suit.spade.fill"
        }
    }

    var isRed: Bool { self == .hearts || self == .diamonds }
}

/// Shown when `phase == .suitChoice` and it's the human's turn — pick a suit after
/// playing a non-Ace-of-Spades Ace, or after an 8/Q in a suit-choice path.
struct SuitChoiceOverlay: View {
    let onChoose: (Suit) -> Void

    var body: some View {
        OverlayCard(title: "Choose a Suit") {
            HStack(spacing: KadiTheme.Layout.spacingM) {
                ForEach(Suit.allCases, id: \.self) { suit in
                    Button {
                        onChoose(suit)
                    } label: {
                        Image(systemName: suit.sfSymbolName)
                            .font(.system(size: 28))
                            .foregroundStyle(suit.isRed ? KadiTheme.Colors.suitRed : KadiTheme.Colors.suitBlack)
                            .frame(width: 56, height: 56)
                            .background(KadiTheme.Colors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
                    }
                }
            }
        }
    }
}

/// Shared dim-background + centered card container for game-phase overlays.
struct OverlayCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingM) {
                Text(title)
                    .font(KadiTheme.Typography.headline)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                content()
            }
            .padding(KadiTheme.Layout.spacingL)
            .background(KadiTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
            .padding(KadiTheme.Layout.spacingL)
        }
    }
}
