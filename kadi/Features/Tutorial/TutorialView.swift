//
//  TutorialView.swift
//  kadi
//

import SwiftUI
import KadiEngine

struct TutorialView: View {
    @StateObject private var viewModel = TutorialViewModel()
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)? = nil

    private var opponents: [Player] {
        Array(viewModel.state.players.dropFirst())
    }

    var body: some View {
        ZStack {
            KadiTheme.tableFeltGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                // Opponent area
                HStack(spacing: KadiTheme.Layout.spacingM) {
                    ForEach(Array(opponents.enumerated()), id: \.offset) { offset, player in
                        opponentSlot(player: player, index: offset + 1)
                    }
                }
                .padding(.top, KadiTheme.Layout.spacingM)
                .padding(.horizontal, KadiTheme.Layout.spacingM)

                Spacer()

                GameTableView(
                    topCard: viewModel.state.topCard,
                    drawCount: viewModel.state.drawPile.count,
                    direction: viewModel.state.direction,
                    pendingDrawCount: viewModel.state.pendingDrawCount,
                    forcedSuit: viewModel.state.forcedSuit
                )

                Spacer()

                VStack(spacing: KadiTheme.Layout.spacingS) {
                    PlayerHandView(
                        cards: viewModel.humanPlayer.hand,
                        playableIndices: viewModel.playableIndices,
                        selectedIndices: viewModel.selectedCardIndices,
                        onTap: { viewModel.toggleSelection(at: $0) }
                    )

                    if viewModel.isHumanTurn && !viewModel.isActionLocked {
                        tutorialActionBar
                    }
                }
                .padding(.bottom, KadiTheme.Layout.spacingM)
            }

            // Suit-choice phase overlay
            if viewModel.isHumanTurn && viewModel.state.phase == .suitChoice {
                SuitChoiceOverlay { suit in viewModel.chooseSuit(suit) }
            }

            // Game complete overlay takes precedence over the coach
            if viewModel.isComplete {
                tutorialCompleteOverlay
            } else {
                TutorialCoachOverlay(
                    step: viewModel.currentStep,
                    onNext: { dismiss(); onDismiss?() }
                )
            }
        }
        .navigationTitle("Tutorial")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .alert("Oops", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Action bar

    private var tutorialActionBar: some View {
        HStack(spacing: KadiTheme.Layout.spacingS) {
            if viewModel.canDeclareKadi {
                Button("KADI") {
                    viewModel.declareKadi()
                }
                .buttonStyle(KadiDeclareButtonStyle())
                .disabled(viewModel.selectedCardIndices.isEmpty)
            }

            Button("Play (\(viewModel.selectedCardIndices.count))") {
                viewModel.confirmPlay()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.selectedCardIndices.isEmpty)

            if viewModel.state.isDrawStackActive {
                Button("Draw (+\(viewModel.state.pendingDrawCount))") {
                    viewModel.drawStack()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else {
                Button("Draw Card") {
                    viewModel.drawCard()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, KadiTheme.Layout.spacingM)
    }

    // MARK: - Complete overlay

    private var tutorialCompleteOverlay: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("\u{1F389}")
                    .font(.system(size: 72))

                Text("Tutorial Complete!")
                    .font(KadiTheme.Typography.largeTitle)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)

                Text("You now know the basics of Kadi. Jump into a real game!")
                    .font(KadiTheme.Typography.body)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)
                    .multilineTextAlignment(.center)

                Button("Back to Home") {
                    dismiss()
                    onDismiss?()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(KadiTheme.Layout.spacingL)
            .background(KadiTheme.Colors.surface)
            .clipShape(RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius))
            .padding(KadiTheme.Layout.spacingL)
        }
    }

    // MARK: - Opponent slot

    @ViewBuilder
    private func opponentSlot(player: Player, index: Int) -> some View {
        VStack(spacing: 4) {
            Text(player.name)
                .font(KadiTheme.Typography.callout)
                .foregroundStyle(KadiTheme.Colors.textPrimary)

            ZStack {
                ForEach(0..<min(player.hand.count, 4), id: \.self) { i in
                    PlayingCardView(
                        card: nil,
                        isFaceUp: false,
                        width: KadiTheme.Layout.cardWidthSmall,
                        height: KadiTheme.Layout.cardHeightSmall
                    )
                    .offset(x: CGFloat(i) * 6)
                }
            }
            .frame(width: KadiTheme.Layout.cardWidthSmall + 18,
                   height: KadiTheme.Layout.cardHeightSmall)

            PillBadge(text: "\(player.hand.count) cards", systemImage: "rectangle.stack.fill")
        }
        .padding(KadiTheme.Layout.spacingS)
        .background(
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                .fill(KadiTheme.Colors.surface.opacity(
                    viewModel.state.currentPlayerIndex == index ? 0.9 : 0.5
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                .stroke(
                    viewModel.state.currentPlayerIndex == index
                        ? KadiTheme.Colors.accent
                        : .clear,
                    lineWidth: 2
                )
        )
    }
}
