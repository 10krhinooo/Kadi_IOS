//
//  SoloGameView.swift
//  kadi
//

import SwiftUI
import KadiEngine

struct SoloGameView: View {
    @StateObject private var viewModel: SoloGameViewModel
    @Environment(\.dismiss) private var dismiss

    init(opponentCount: Int, difficulty: CpuDifficulty) {
        _viewModel = StateObject(wrappedValue: SoloGameViewModel(opponentCount: opponentCount, difficulty: difficulty))
    }

    private var opponents: [Player] {
        Array(viewModel.state.players.dropFirst())
    }

    var body: some View {
        ZStack {
            KadiTheme.tableFeltGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: KadiTheme.Layout.spacingM) {
                    ForEach(Array(opponents.enumerated()), id: \.offset) { offset, player in
                        OpponentSlotView(
                            name: player.name,
                            cardCount: player.cardCount,
                            isCurrentTurn: viewModel.state.currentPlayerIndex == offset + 1
                        )
                    }
                }
                .padding(.top, KadiTheme.Layout.spacingM)
                .padding(.horizontal, KadiTheme.Layout.spacingM)

                if viewModel.isCpuThinking {
                    PillBadge(text: "CPU thinking…", tint: KadiTheme.Colors.surfaceElevated)
                        .padding(.top, KadiTheme.Layout.spacingS)
                } else if viewModel.isHumanTurn {
                    PillBadge(text: "Your Turn")
                        .padding(.top, KadiTheme.Layout.spacingS)
                }

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
                    if viewModel.isHumanTurn && viewModel.state.phase == .questionAnswer {
                        QuestionAnswerBanner(forcedSuit: viewModel.state.forcedSuit) {
                            viewModel.pass()
                        }
                    }

                    PlayerHandView(
                        cards: viewModel.humanPlayer.hand,
                        playableIndices: viewModel.playableIndices,
                        selectedIndices: viewModel.selectedCardIndices,
                        onTap: { viewModel.toggleSelection(at: $0) }
                    )

                    if viewModel.isHumanTurn && viewModel.state.phase == .playing {
                        ActionBar(viewModel: viewModel)
                    }
                }
                .padding(.bottom, KadiTheme.Layout.spacingM)
            }

            overlay
        }
        .navigationBarBackButtonHidden(viewModel.state.phase != .finished)
        .exitGameButton { dismiss() }
        .alert("Invalid Move", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var overlay: some View {
        if viewModel.state.phase == .finished {
            GameOverOverlay(
                winnerName: viewModel.winner?.name,
                onPlayAgain: { viewModel.reset() },
                onBackToHome: { dismiss() }
            )
        } else if viewModel.isHumanTurn {
            switch viewModel.state.phase {
            case .suitChoice:
                SuitChoiceOverlay { suit in viewModel.chooseSuit(suit) }
            case .demandEntry:
                DemandEntryOverlay { rank, suit in viewModel.makeDemand(rank: rank, suit: suit) }
            case .cardDemand:
                CardDemandOverlay(
                    demandedCard: viewModel.state.demandedCard,
                    hasDemandedCard: viewModel.state.demandedCard.map { viewModel.humanPlayer.hand.contains($0) } ?? false,
                    acesInHand: viewModel.humanPlayer.hand.filter { $0.isAce },
                    onPlayDemanded: { viewModel.respondToDemand(card: viewModel.state.demandedCard) },
                    onPlayAce: { viewModel.respondToDemand(card: $0) },
                    onDrawInstead: { viewModel.respondToDemand(card: nil) }
                )
            case .skipIntercept:
                SkipInterceptOverlay(
                    jacksInHand: viewModel.humanPlayer.hand.filter { $0.isSkipCard },
                    onIntercept: { jacks in viewModel.interceptSkip(jacks: jacks) },
                    onDecline: { viewModel.declineIntercept() }
                )
            default:
                EmptyView()
            }
        }
    }
}
