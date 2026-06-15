//
//  OnlineGuestLobbyView.swift
//  kadi
//

import SwiftUI
import KadiOnline

/// Lobby shown to a guest who joined an online room by code, waiting for the host to
/// start the game.
struct OnlineGuestLobbyView: View {
    @StateObject private var viewModel: OnlineGuestLobbyViewModel
    @Environment(\.dismiss) private var dismiss

    init(roomId: String, localPlayerIndex: Int, authUser: AuthUser) {
        _viewModel = StateObject(wrappedValue: OnlineGuestLobbyViewModel(
            roomId: roomId,
            localPlayerIndex: localPlayerIndex,
            authUser: authUser
        ))
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
                            isYou: player.playerIndex == viewModel.localPlayerIndex
                        )
                    }
                }
                .padding(KadiTheme.Layout.spacingM)
                .background(
                    RoundedRectangle(cornerRadius: KadiTheme.Layout.cornerRadius)
                        .fill(KadiTheme.Colors.surface.opacity(0.5))
                )

                Spacer()

                ProgressView("Waiting for host to start the game…")
                    .tint(KadiTheme.Colors.accent)
                    .foregroundStyle(KadiTheme.Colors.textSecondary)

                Spacer()
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
            if let initialState = viewModel.initialState {
                OnlineGameView(
                    role: .guest(RoomClient(roomId: viewModel.roomId, uid: viewModel.authUser.uid)),
                    localPlayerIndex: viewModel.localPlayerIndex,
                    initialState: initialState,
                    roomId: viewModel.roomId
                )
            }
        }
        .alert("Room Closed", isPresented: $viewModel.roomGone) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.errorMessage ?? "The host left before the game started.")
        }
    }
}
