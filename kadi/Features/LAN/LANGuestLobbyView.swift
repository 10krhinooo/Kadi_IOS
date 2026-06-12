//
//  LANGuestLobbyView.swift
//  kadi
//

import SwiftUI
import KadiEngine
import KadiNetworking

/// Lobby shown to a joined guest while waiting for the host to start the game.
struct LANGuestLobbyView: View {
    @StateObject private var viewModel: LANGuestLobbyViewModel
    @Environment(\.dismiss) private var dismiss
    private let client: LANGameClient

    init(client: LANGameClient, identity: PlayerIdentityStore) {
        self.client = client
        _viewModel = StateObject(wrappedValue: LANGuestLobbyViewModel(client: client))
    }

    private var gameName: String {
        "\(viewModel.players.first?.name ?? "")'s Game"
    }

    var body: some View {
        ZStack {
            KadiTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: KadiTheme.Layout.spacingL) {
                Text("Lobby")
                    .font(KadiTheme.Typography.title)
                    .foregroundStyle(KadiTheme.Colors.textPrimary)
                    .padding(.top, KadiTheme.Layout.spacingL)

                VStack(spacing: 0) {
                    ForEach(Array(viewModel.players.enumerated()), id: \.offset) { index, player in
                        LobbyPlayerRowView(
                            name: player.name,
                            avatarIndex: player.avatarIndex,
                            isHost: index == 0,
                            isYou: index == viewModel.localPlayerIndex
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
        .onAppear { viewModel.start() }
        .onDisappear {
            if !viewModel.didStartGame {
                viewModel.stop()
            }
        }
        .navigationDestination(isPresented: $viewModel.didStartGame) {
            if let initialState = viewModel.initialState {
                LANGameView(
                    role: .guest(client),
                    localPlayerIndex: viewModel.localPlayerIndex,
                    initialState: initialState,
                    rules: initialState.rules,
                    gameName: gameName
                )
            }
        }
        .alert("Host Disconnected", isPresented: $viewModel.hostLost) {
            Button("OK") { dismiss() }
        } message: {
            Text("The host left before the game started.")
        }
    }
}
