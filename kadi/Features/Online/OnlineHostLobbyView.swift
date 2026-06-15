//
//  OnlineHostLobbyView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Lobby shown to the host of a freshly-created online room: displays the room code for
/// sharing, the live roster, and a "Start Game" button once at least one guest has joined.
struct OnlineHostLobbyView: View {
    @StateObject private var viewModel: OnlineHostLobbyViewModel

    init(roomId: String, authUser: AuthUser) {
        _viewModel = StateObject(wrappedValue: OnlineHostLobbyViewModel(roomId: roomId, authUser: authUser))
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                VStack(spacing: KadiTheme.Layout.spacingS) {
                    Text("Room Code")
                        .font(KadiTheme.Typography.headline)
                        .foregroundStyle(KadiTheme.Colors.textSecondary)
                    Text(viewModel.roomId)
                        .font(KadiTheme.Typography.largeTitle)
                        .foregroundStyle(KadiTheme.Colors.accent)
                        .tracking(4)
                }
                .padding(.top, KadiTheme.Layout.spacingL)

                VStack(spacing: 0) {
                    ForEach(viewModel.room?.players ?? [], id: \.uid) { player in
                        LobbyPlayerRowView(
                            name: player.name,
                            avatarIndex: 0,
                            isHost: player.playerIndex == 0,
                            isYou: player.playerIndex == 0
                        )
                    }
                }
                .padding(KadiTheme.Layout.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                        .fill(KadiTheme.Colors.surface.opacity(0.5))
                )

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(KadiTheme.Typography.callout)
                        .foregroundStyle(KadiTheme.Colors.warning)
                }

                Spacer()

                Text(viewModel.canStartGame ? "Ready to start" : "Waiting for at least one more player…")
                    .font(KadiTheme.Typography.callout)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)

                Button("Start Game") {
                    viewModel.startGame()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canStartGame)
            }
            .padding(KadiTheme.Layout.spacingL)
        }
        .navigationTitle("Lobby")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.didStartGame)
        .onAppear { viewModel.start() }
        .onDisappear {
            if !viewModel.didStartGame {
                viewModel.stop()
            }
        }
        .navigationDestination(isPresented: $viewModel.didStartGame) {
            if let initialState = viewModel.initialState, let roomHost = viewModel.roomHost {
                OnlineGameView(
                    role: .host(roomHost),
                    localPlayerIndex: 0,
                    initialState: initialState,
                    roomId: viewModel.roomId
                )
            }
        }
    }
}
