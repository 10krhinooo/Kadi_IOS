//
//  OnlineGameView.swift
//  kadi
//

import SwiftUI
import KadiEngine
import KadiOnline

/// Online multiplayer game screen. Mirrors `LANGameView`'s structure, driven by
/// `OnlineGameViewModel` instead of `LANGameViewModel`. No host-migration UI: `RoomHost`
/// has no CPU-takeover/reconnect equivalent to `LANGameHost` yet.
struct OnlineGameView: View {
    @StateObject private var viewModel: OnlineGameViewModel
    @Environment(\.dismiss) private var dismiss

    init(role: OnlineGameViewModel.Role, localPlayerIndex: Int, initialState: GameState, roomId: String) {
        _viewModel = StateObject(wrappedValue: OnlineGameViewModel(
            role: role,
            localPlayerIndex: localPlayerIndex,
            initialState: initialState,
            roomId: roomId
        ))
    }

    private var opponents: [(offset: Int, player: Player)] {
        viewModel.state.players.enumerated()
            .filter { $0.offset != viewModel.localPlayerIndex }
            .map { (offset: $0.offset, player: $0.element) }
    }

    var body: some View {
        ZStack {
            KadiTheme.tableFeltGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: KadiTheme.Layout.spacingM) {
                    ForEach(opponents, id: \.offset) { offset, player in
                        OpponentSlotView(
                            name: player.name,
                            cardCount: player.cardCount,
                            isCurrentTurn: viewModel.state.currentPlayerIndex == offset,
                            avatarIndex: player.avatarIndex,
                            isCPUControlled: false
                        )
                    }
                }
                .padding(.top, KadiTheme.Layout.spacingM)
                .padding(.horizontal, KadiTheme.Layout.spacingM)

                if let kadiState = viewModel.state.kadiState {
                    KadiBanner(
                        playerName: viewModel.state.players[kadiState.declaringPlayerIndex].name,
                        isLocalPlayer: kadiState.declaringPlayerIndex == viewModel.localPlayerIndex
                    )
                    .padding(.top, KadiTheme.Layout.spacingS)
                }

                if viewModel.isLocalPlayerTurn {
                    PillBadge(text: "Your Turn")
                        .padding(.top, KadiTheme.Layout.spacingS)
                } else {
                    PillBadge(text: "\(viewModel.state.currentPlayer.name)'s Turn")
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
                    if viewModel.isLocalPlayerTurn && viewModel.state.phase == .questionAnswer {
                        QuestionAnswerBanner(forcedSuit: viewModel.state.forcedSuit)
                    }

                    PlayerHandView(
                        cards: viewModel.localPlayer.hand,
                        playableIndices: viewModel.playableIndices,
                        selectedIndices: viewModel.selectedCardIndices,
                        onTap: { viewModel.toggleSelection(at: $0) }
                    )

                    if viewModel.isLocalPlayerTurn && (viewModel.state.phase == .playing || viewModel.state.phase == .questionAnswer) {
                        OnlineActionBar(viewModel: viewModel)
                    }
                }
                .padding(.bottom, KadiTheme.Layout.spacingM)
            }

            overlay
        }
        .navigationBarBackButtonHidden(viewModel.state.phase != .finished)
        .exitGameButton { dismiss() }
        .gameHelpButton()
        .onDisappear {
            viewModel.stop()
        }
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
                isLocalWinner: viewModel.winner?.id == viewModel.localPlayer.id,
                onPlayAgain: { dismiss() },
                onBackToHome: { dismiss() }
            )
        } else if viewModel.isLocalPlayerTurn {
            switch viewModel.state.phase {
            case .suitChoice:
                SuitChoiceOverlay { suit in viewModel.chooseSuit(suit) }
            case .demandEntry:
                DemandEntryOverlay { rank, suit in viewModel.makeDemand(rank: rank, suit: suit) }
            case .cardDemand:
                CardDemandOverlay(
                    demandedCard: viewModel.state.demandedCard,
                    hasDemandedCard: viewModel.state.demandedCard.map { viewModel.localPlayer.hand.contains($0) } ?? false,
                    acesInHand: viewModel.localPlayer.hand.filter { $0.isAce },
                    onPlayDemanded: { viewModel.respondToDemand(card: viewModel.state.demandedCard) },
                    onPlayAce: { viewModel.respondToDemand(card: $0) },
                    onDrawInstead: { viewModel.respondToDemand(card: nil) }
                )
            case .skipIntercept:
                SkipInterceptOverlay(
                    jacksInHand: viewModel.localPlayer.hand.filter { $0.isSkipCard },
                    onIntercept: { jacks in viewModel.interceptSkip(jacks: jacks) },
                    onDecline: { viewModel.declineIntercept() }
                )
            default:
                EmptyView()
            }
        }
    }
}
